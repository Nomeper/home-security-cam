(() => {
  const CHANNEL = "casa_sicura";
  const CAM_UIDS = [10, 20, 30, 40, 50, 60];
  const VIEWER_UID = 101;
  const APP_ID_KEY = "hsc_agora_app_id";
  const NAME_KEY = (uid) => `hsc_cam_name_${uid}`;

  const $ = (id) => document.getElementById(id);
  const encoder = new TextEncoder();
  const decoder = new TextDecoder();

  const state = {
    client: null,
    micTrack: null,
    selected: new Set(),
    online: new Set(),
    batteries: new Map(),
    flashOn: new Map(),
    frontCamera: new Map(),
    listenOn: new Set(),
    talking: false,
    gridKey: "",
    heartbeatTimer: null,
    orientationTimer: null,
    screen: "gate",
    videoReady: new Set(),
  };

  function camName(uid) {
    return localStorage.getItem(NAME_KEY(uid)) || `CAM ${CAM_UIDS.indexOf(uid) + 1}`;
  }

  function watchPayload() {
    const selected = [...state.selected].filter((uid) => CAM_UIDS.includes(uid)).sort((a, b) => a - b);
    return `WATCH:${selected.join(",")}`;
  }

  function startHeartbeat() {
    stopHeartbeat();
    state.heartbeatTimer = window.setInterval(() => {
      sendCommand(watchPayload());
    }, 4000);
  }

  function stopHeartbeat() {
    if (state.heartbeatTimer) {
      window.clearInterval(state.heartbeatTimer);
      state.heartbeatTimer = null;
    }
  }

  function startOrientationWatch() {
    stopOrientationWatch();
    state.orientationTimer = window.setInterval(refreshAllOrientations, 1000);
  }

  function stopOrientationWatch() {
    if (state.orientationTimer) {
      window.clearInterval(state.orientationTimer);
      state.orientationTimer = null;
    }
  }

  function showGateError(message) {
    const status = $("gate-status");
    const el = $("gate-error");
    if (status) {
      status.hidden = true;
      status.textContent = "";
    }
    if (!el) return;
    el.hidden = !message;
    el.textContent = message || "";
  }

  function showGateStatus(message) {
    const el = $("gate-error");
    const status = $("gate-status");
    if (el) {
      el.hidden = true;
      el.textContent = "";
    }
    if (!status) return;
    status.hidden = !message;
    status.textContent = message || "";
  }

  function errorText(error) {
    try {
      if (!error) return "";
      if (typeof error === "string") return error;
      const parts = [error.code, error.name, error.message, error.reason]
        .map((part) => (part == null ? "" : String(part)))
        .filter(Boolean);
      return parts.join(" — ") || String(error);
    } catch (_) {
      return "errore sconosciuto";
    }
  }

  function showScreen(name) {
    state.screen = name;
    $("gate").hidden = name !== "gate";
    $("app").hidden = name !== "live";
  }

  function pingParent(type) {
    try {
      parent.postMessage(type, "*");
    } catch (_) {
      /* ignore */
    }
  }

  function dbg(msg) {
    console.log("[visore]", msg);
    fetch("/debug-log", { method: "POST", body: String(msg) }).catch(() => {});
  }

  function withTimeout(promise, ms, message) {
    let timer;
    const timeout = new Promise((_, reject) => {
      timer = setTimeout(() => reject(new Error(message)), ms);
    });
    return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
  }

  function setStatus(kind, title, sub) {
    $("status-dot").className = `dot ${kind}`;
    $("status-title").textContent = title;
    $("status-sub").textContent = sub;
  }

  function selectionLabel() {
    const selected = CAM_UIDS.filter((uid) => state.selected.has(uid));
    if (selected.length === 0) return "Nessuna camera selezionata";
    if (selected.length === 1) return camName(selected[0]);
    return `${selected.length} camere`;
  }

  function hasLiveVideoFrame(uid) {
    if (!state.selected.has(uid)) return false;
    const user = remoteUser(uid);
    if (!user?.videoTrack) return false;
    const el = $(`player-${uid}`);
    const video = el?.querySelector("video");
    if (video && video.videoWidth > 8 && video.videoHeight > 8 && video.readyState >= 2) {
      return true;
    }
    const size = trackFrameSize(user.videoTrack, el);
    return !!(size && size.w > 8 && size.h > 8);
  }

  function isReceivingVideo() {
    return CAM_UIDS.some((uid) => hasLiveVideoFrame(uid) || (
      state.selected.has(uid) && state.videoReady.has(uid)
    ));
  }

  function setVideoReady(uid, ready) {
    const was = state.videoReady.has(uid);
    if (ready === was) return;
    if (ready) state.videoReady.add(uid);
    else state.videoReady.delete(uid);
    refreshStatus();
  }

  function syncVideoReady() {
    let changed = false;
    for (const uid of CAM_UIDS) {
      const live = hasLiveVideoFrame(uid);
      const was = state.videoReady.has(uid);
      if (live === was) continue;
      if (live) state.videoReady.add(uid);
      else state.videoReady.delete(uid);
      changed = true;
    }
    if (changed) refreshStatus();
  }

  function refreshStatus() {
    const transmitting = isReceivingVideo();
    const title = !state.client
      ? "VISORE DISCONNESSO"
      : state.client.connectionState === "RECONNECTING"
        ? "Riconnessione in corso…"
        : transmitting
          ? "MONITORAGGIO LIVE"
          : "IN ATTESA VIDEO";
    setStatus(transmitting ? "live" : "off", title, selectionLabel());
    const dot = $("status-dot");
    if (dot) {
      dot.title = transmitting
        ? "Trasmissione dati attiva"
        : "Nessuna trasmissione dati";
    }
  }

  async function sendCommand(text) {
    if (!state.client) return;
    const payload = encoder.encode(text);
    try {
      await state.client.sendStreamMessage({ payload, syncWithAudio: false }, true);
    } catch (first) {
      try {
        await state.client.sendStreamMessage(payload, true);
      } catch (second) {
        console.warn("Invio comando fallito", text, first, second);
      }
    }
  }

  function handleMessage(raw) {
    const message = typeof raw === "string" ? raw : decoder.decode(raw);
    const batt = message.match(/^BATT:(\d+):(\d+)$/);
    if (batt) {
      const uid = Number(batt[1]);
      const level = Math.min(100, Math.max(0, Number(batt[2])));
      if (CAM_UIDS.includes(uid)) {
        state.batteries.set(uid, level);
        updateTileOverlays(uid);
        renderChips();
      }
      return;
    }
    const flash = message.match(/^FLASHSTATE:(\d+):(ON|OFF)$/i);
    if (flash) {
      const uid = Number(flash[1]);
      if (CAM_UIDS.includes(uid)) {
        state.flashOn.set(uid, flash[2].toUpperCase() === "ON");
        renderChips();
      }
      return;
    }
    const lens = message.match(/^LENSSTATE:(\d+):(FRONT|REAR)$/i);
    if (lens) {
      const uid = Number(lens[1]);
      if (CAM_UIDS.includes(uid)) {
        state.frontCamera.set(uid, lens[2].toUpperCase() === "FRONT");
        renderChips();
      }
    }
  }

  function waitingText(uid) {
    return state.online.has(uid)
      ? "In attesa del video…"
      : `In attesa di ${camName(uid)}`;
  }

  function tileWaiting(uid) {
    const wait = document.createElement("div");
    wait.className = "wait-copy";
    wait.textContent = waitingText(uid);
    return wait;
  }

  function gridLayoutKey() {
    const selected = CAM_UIDS.filter((uid) => state.selected.has(uid));
    const landscape = $("stage").clientWidth > $("stage").clientHeight;
    const columns = selected.length <= 1 ? 1 : selected.length === 2 && !landscape ? 1 : 2;
    return { selected, columns, key: `${selected.join(",")}|${columns}` };
  }

  function updateTileOverlays(uid) {
    const tile = document.querySelector(`.tile[data-uid="${uid}"]`);
    if (!tile) return;
    const wait = tile.querySelector(".wait-copy");
    const user = remoteUser(uid);
    if (user?.videoTrack) {
      wait?.remove();
    } else if (!wait) {
      tile.appendChild(tileWaiting(uid));
    } else {
      wait.textContent = waitingText(uid);
    }
    const meta = tile.querySelector(".meta");
    if (meta) meta.textContent = camName(uid);
  }

  function renderGrid() {
    if (state.screen !== "live") return;
    const { selected, columns, key } = gridLayoutKey();
    $("empty").hidden = selected.length > 0;
    $("grid").hidden = selected.length === 0;
    if (selected.length === 0) {
      $("grid").innerHTML = "";
      state.gridKey = key;
      return;
    }
    if (key === state.gridKey) {
      for (const uid of selected) updateTileOverlays(uid);
      return;
    }

    $("grid").style.gridTemplateColumns = `repeat(${columns}, 1fr)`;
    $("grid").dataset.cams = String(selected.length);
    $("grid").classList.toggle("single", selected.length === 1);
    $("grid").innerHTML = "";
    for (const uid of selected) {
      const tile = document.createElement("div");
      tile.className = "tile";
      tile.dataset.uid = String(uid);
      const player = document.createElement("div");
      player.className = "player";
      player.id = `player-${uid}`;
      tile.appendChild(player);
      tile.appendChild(tileWaiting(uid));
      const meta = document.createElement("div");
      meta.className = "meta";
      meta.textContent = camName(uid);
      tile.appendChild(meta);
      $("grid").appendChild(tile);
      updateTileOverlays(uid);
    }
    state.gridKey = key;
    replaySelectedVideos();
  }

  function remoteUser(uid) {
    return state.client?.remoteUsers.find((user) => Number(user.uid) === uid);
  }

  function replaySelectedVideos() {
    if (!state.client) return;
    for (const uid of state.selected) {
      const user = remoteUser(uid);
      if (!user?.videoTrack) continue;
      playRemoteVideo(uid, user.videoTrack);
    }
  }

  function playRemoteVideo(uid, track) {
    const el = $(`player-${uid}`);
    if (!el || !track) return;
    track.play(el, { fit: "contain" });
    el.parentElement?.querySelector(".wait-copy")?.remove();
    bindVideoOrientation(uid, track, el);
  }

  function trackFrameSize(track, container) {
    try {
      const stats = typeof track.getStats === "function" ? track.getStats() : null;
      const sw = Number(stats?.receiveResolutionWidth || stats?.sendResolutionWidth || 0);
      const sh = Number(stats?.receiveResolutionHeight || stats?.sendResolutionHeight || 0);
      if (sw > 8 && sh > 8) return { w: sw, h: sh };
    } catch (_) {
      /* ignore */
    }
    try {
      const settings = track.getMediaStreamTrack?.()?.getSettings?.() || {};
      const w = Number(settings.width || 0);
      const h = Number(settings.height || 0);
      if (w > 8 && h > 8) return { w, h };
    } catch (_) {
      /* ignore */
    }
    const video = container?.querySelector("video");
    if (video?.videoWidth > 8 && video.videoHeight > 8) {
      return { w: video.videoWidth, h: video.videoHeight };
    }
    return null;
  }

  function applyTileOrientation(uid, size) {
    const tile = document.querySelector(`.tile[data-uid="${uid}"]`);
    if (!tile || !size) return;
    const portrait = size.h > size.w;
    tile.classList.toggle("portrait", portrait);
    tile.classList.toggle("landscape", !portrait);
    const video = tile.querySelector("video");
    if (video) {
      video.style.objectFit = "contain";
    }
    if (size && size.w > 8 && size.h > 8) setVideoReady(uid, true);
  }

  function bindVideoOrientation(uid, track, container) {
    const apply = () => applyTileOrientation(uid, trackFrameSize(track, container));
    const hookVideo = () => {
      const video = container.querySelector("video");
      if (!video || video.dataset.orientBound === "1") return;
      video.dataset.orientBound = "1";
      video.addEventListener("loadedmetadata", apply);
      video.addEventListener("resize", apply);
    };
    apply();
    hookVideo();
    window.setTimeout(() => {
      apply();
      hookVideo();
    }, 250);
    window.setTimeout(() => {
      apply();
      hookVideo();
    }, 1000);
    if (typeof track.on === "function" && !track.__hscOrient) {
      track.__hscOrient = true;
      track.on("first-frame-decoded", apply);
    }
  }

  function refreshAllOrientations() {
    if (state.screen !== "live" || !state.client) {
      syncVideoReady();
      return;
    }
    for (const uid of state.selected) {
      const user = remoteUser(uid);
      const el = $(`player-${uid}`);
      if (!user?.videoTrack || !el) continue;
      applyTileOrientation(uid, trackFrameSize(user.videoTrack, el));
    }
    syncVideoReady();
  }

  function camStatusText(uid) {
    if (!state.online.has(uid)) return "Assente";
    if (state.batteries.has(uid)) return `Batteria ${state.batteries.get(uid)}%`;
    return "Connessa";
  }

  function makeCamChip(uid) {
    const online = state.online.has(uid);
    const selected = state.selected.has(uid);
    const chip = document.createElement("div");
    chip.className = `chip ${online ? "online" : "offline"} ${selected ? "selected" : ""}`;

    const name = document.createElement("span");
    name.className = "name";
    name.textContent = camName(uid);
    const batt = document.createElement("span");
    batt.className = "batt";
    batt.textContent = camStatusText(uid);
    chip.appendChild(name);
    chip.appendChild(batt);

    chip.addEventListener("click", (event) => {
      if (event.target.closest(".chip-actions")) return;
      toggleCamera(uid).catch(console.warn);
    });
    chip.addEventListener("contextmenu", (event) => {
      event.preventDefault();
      renameCamera(uid);
    });

    const actions = document.createElement("div");
    actions.className = "chip-actions";
    const flashBtn = document.createElement("button");
    flashBtn.type = "button";
    flashBtn.title = "Flash";
    flashBtn.textContent = "Flash";
    flashBtn.disabled = !(online && selected);
    if (state.flashOn.get(uid)) flashBtn.classList.add("on");
    flashBtn.addEventListener("click", (event) => {
      event.stopPropagation();
      toggleFlash(uid);
    });
    const listenBtn = document.createElement("button");
    listenBtn.type = "button";
    listenBtn.title = "Audio camera";
    listenBtn.textContent = "Audio";
    listenBtn.disabled = !(online && selected);
    if (state.listenOn.has(uid)) listenBtn.classList.add("on");
    listenBtn.addEventListener("click", (event) => {
      event.stopPropagation();
      toggleListen(uid);
    });
    const lensBtn = document.createElement("button");
    lensBtn.type = "button";
    const front = state.frontCamera.get(uid) ?? false;
    lensBtn.title = front ? "Fotocamera frontale" : "Fotocamera posteriore";
    lensBtn.textContent = front ? "Front" : "Post";
    lensBtn.disabled = !(online && selected);
    if (front) lensBtn.classList.add("on");
    lensBtn.addEventListener("click", (event) => {
      event.stopPropagation();
      toggleLens(uid);
    });
    actions.appendChild(flashBtn);
    actions.appendChild(listenBtn);
    actions.appendChild(lensBtn);
    chip.appendChild(actions);
    return chip;
  }

  function renderChips() {
    const root = $("chips");
    if (!root) return;
    root.innerHTML = "";
    for (const uid of CAM_UIDS) {
      root.appendChild(makeCamChip(uid));
    }
    const canTalk = [...state.selected].some((uid) => state.online.has(uid));
    $("talk-btn").disabled = !canTalk;
    $("talk-btn").classList.toggle("live", state.talking);
    $("talk-btn").textContent = state.talking ? "Parlando" : "Parla";
  }

  function renderViewer() {
    refreshStatus();
    renderGrid();
    renderChips();
  }

  async function subscribeIfNeeded(user, mediaType) {
    const uid = Number(user.uid);
    if (!CAM_UIDS.includes(uid) || !state.selected.has(uid)) return;
    if (mediaType === "video") {
      await state.client.subscribe(user, "video");
      playRemoteVideo(uid, user.videoTrack);
      return;
    }
    if (mediaType === "audio" && state.listenOn.has(uid)) {
      await state.client.subscribe(user, "audio");
      user.audioTrack?.play();
    }
  }

  async function unsubscribeVideo(uid) {
    setVideoReady(uid, false);
    const user = remoteUser(uid);
    if (user?.videoTrack) {
      user.videoTrack.stop();
      try {
        await state.client.unsubscribe(user, "video");
      } catch (_) {
        /* già assente */
      }
    }
  }

  async function setListen(uid, enabled) {
    if (!state.online.has(uid)) return;
    await sendCommand(`LISTEN:${uid}:${enabled ? "ON" : "OFF"}`);
    const user = remoteUser(uid);
    if (enabled) {
      state.listenOn.add(uid);
      if (user?.hasAudio) {
        await state.client.subscribe(user, "audio");
        user.audioTrack?.play();
      }
    } else {
      state.listenOn.delete(uid);
      if (user?.audioTrack) {
        user.audioTrack.stop();
        try {
          await state.client.unsubscribe(user, "audio");
        } catch (_) {
          /* già assente */
        }
      }
    }
    renderChips();
  }

  async function toggleCamera(uid) {
    if (state.selected.has(uid)) {
      state.selected.delete(uid);
      if (state.listenOn.has(uid)) await setListen(uid, false);
      await unsubscribeVideo(uid);
    } else {
      state.selected.add(uid);
    }
    await sendCommand(watchPayload());
    const user = remoteUser(uid);
    if (user?.hasVideo && state.selected.has(uid)) {
      await subscribeIfNeeded(user, "video");
    }
    renderViewer();
  }

  async function toggleFlash(uid) {
    if (!state.online.has(uid) || !state.selected.has(uid)) return;
    const next = !(state.flashOn.get(uid) ?? false);
    await sendCommand(`FLASH:${uid}:${next ? "ON" : "OFF"}`);
    state.flashOn.set(uid, next);
    renderChips();
  }

  async function toggleListen(uid) {
    if (!state.online.has(uid) || !state.selected.has(uid)) return;
    await setListen(uid, !state.listenOn.has(uid));
  }

  async function toggleLens(uid) {
    if (!state.online.has(uid) || !state.selected.has(uid)) return;
    const nextFront = !(state.frontCamera.get(uid) ?? false);
    await sendCommand(`LENS:${uid}:${nextFront ? "FRONT" : "REAR"}`);
    state.frontCamera.set(uid, nextFront);
    renderChips();
  }

  function renameCamera(uid) {
    const next = window.prompt("Nome telecamera", camName(uid));
    if (next == null) return;
    const name = next.trim().replace(/\s+/g, " ");
    if (!name || name.length > 32) {
      window.alert("Il nome deve avere da 1 a 32 caratteri.");
      return;
    }
    localStorage.setItem(NAME_KEY(uid), name);
    updateTileOverlays(uid);
    renderChips();
    refreshStatus();
  }

  async function setTalking(enabled) {
    if (!state.client) return;
    if (enabled) {
      try {
        state.micTrack = await AgoraRTC.createMicrophoneAudioTrack();
        await state.client.publish(state.micTrack);
        state.talking = true;
      } catch (error) {
        state.micTrack?.close();
        state.micTrack = null;
        window.alert("Microfono non disponibile. Controlla il permesso del browser.");
        console.warn(error);
      }
    } else {
      if (state.micTrack) {
        await state.client.unpublish(state.micTrack);
        state.micTrack.close();
        state.micTrack = null;
      }
      state.talking = false;
    }
    renderChips();
  }

  function markCamerasFromRemoteUsers() {
    if (!state.client) return;
    for (const user of state.client.remoteUsers) {
      const uid = Number(user.uid);
      if (CAM_UIDS.includes(uid)) state.online.add(uid);
    }
  }

  function loadScript(src, timeoutMs = 8000) {
    return new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src = src;
      const timer = setTimeout(() => {
        script.remove();
        reject(new Error("timeout"));
      }, timeoutMs);
      script.onload = () => {
        clearTimeout(timer);
        resolve();
      };
      script.onerror = () => {
        clearTimeout(timer);
        script.remove();
        reject(new Error(src));
      };
      document.head.appendChild(script);
    });
  }

  async function ensureSdk() {
    if (typeof AgoraRTC !== "undefined") return;
    try {
      await loadScript("AgoraRTC_N.js?v=19e", 6000);
    } catch (_) {
      /* sotto */
    }
    if (typeof AgoraRTC === "undefined") {
      throw new Error("SDK Agora non caricato. Ricarica la pagina con Ctrl+F5.");
    }
  }

  function formatJoinError(error) {
    const blob = errorText(error);
    if (location.protocol === "file:" || location.hostname === "127.0.0.1") {
      return "Apri il visore da http://localhost:8787/ (doppio clic su avvia.bat). Non usare 127.0.0.1 né il file HTML diretto.";
    }
    if (/WEB_SECURITY_RESTRICT/i.test(blob)) {
      return "Agora accetta solo http://localhost o https. Chiudi questa scheda e riapri avvia.bat.";
    }
    if (/INVALID_VENDOR_KEY|INVALID_APP_ID|invalid appid/i.test(blob)) {
      return "App ID non valido. Incolla lo stesso codice dei telefoni, senza spazi.";
    }
    if (/dynamic use static key|CAN_NOT_GET_GATEWAY/i.test(blob)) {
      return "Questo progetto Agora richiede un token. In console Agora usa un progetto Testing senza App Certificate, come sui telefoni.";
    }
    if (/UID_CONFLICT/i.test(blob)) {
      return "C’è già un visore PC connesso. Chiudi l’altra scheda e riprova.";
    }
    if (/Timeout connessione|SDK Agora non caricato/i.test(blob)) return blob;
    return blob
      ? `Connessione non riuscita. ${blob}`
      : "Connessione non riuscita. Controlla App ID e internet.";
  }

  async function connect(appId) {
    dbg("connect start host=" + location.hostname);
    showGateStatus("Verifica SDK…");
    await ensureSdk();
    dbg("sdk ok AgoraRTC=" + (typeof AgoraRTC));
    AgoraRTC.setLogLevel(1);
    const client = AgoraRTC.createClient({ mode: "live", codec: "vp8" });
    client.on("user-joined", (user) => {
      const uid = Number(user.uid);
      if (!CAM_UIDS.includes(uid)) return;
      state.online.add(uid);
      sendCommand("BATTREQ");
      sendCommand(watchPayload());
      updateTileOverlays(uid);
      renderChips();
    });
    client.on("user-left", (user) => {
      const uid = Number(user.uid);
      state.online.delete(uid);
      state.batteries.delete(uid);
      state.flashOn.delete(uid);
      state.frontCamera.delete(uid);
      state.listenOn.delete(uid);
      setVideoReady(uid, false);
      updateTileOverlays(uid);
      renderChips();
    });
    client.on("user-published", (user, mediaType) => {
      subscribeIfNeeded(user, mediaType).catch(console.warn);
    });
    client.on("user-unpublished", (user, mediaType) => {
      const uid = Number(user.uid);
      if (mediaType === "video") {
        user.videoTrack?.stop();
        setVideoReady(uid, false);
        updateTileOverlays(uid);
      }
      if (mediaType === "audio") user.audioTrack?.stop();
    });
    client.on("stream-message", (_uid, payload) => handleMessage(payload));
    client.on("connection-state-change", (current) => {
      if (current === "CONNECTED") {
        sendCommand("BATTREQ");
        sendCommand(watchPayload());
      }
      refreshStatus();
    });

    showGateStatus("Ingresso nel canale casa_sicura…");
    dbg("join begin");
    await new Promise((resolve) => window.setTimeout(resolve, 80));
    try {
      await withTimeout(
        client.join(appId, CHANNEL, null, VIEWER_UID),
        10000,
        "Timeout connessione Agora. Controlla internet, VPN e firewall.",
      );
      dbg("join ok");
    } catch (error) {
      const blob = errorText(error);
      if (/UID_CONFLICT/i.test(blob)) {
        await withTimeout(
          client.join(appId, CHANNEL, null, null),
          10000,
          "Timeout connessione Agora. Controlla internet, VPN e firewall.",
        );
      } else {
        throw error;
      }
    }
    showGateStatus("Attivazione visore host…");
    await withTimeout(
      client.setClientRole("host"),
      8000,
      "Timeout sul ruolo Agora. Controlla internet o disattiva VPN.",
    );
    state.client = client;
    markCamerasFromRemoteUsers();
    await sendCommand("BATTREQ");
    await sendCommand(watchPayload());
    startHeartbeat();
    startOrientationWatch();
    for (const user of client.remoteUsers) {
      if (user.hasVideo) await subscribeIfNeeded(user, "video");
      if (user.hasAudio) await subscribeIfNeeded(user, "audio");
    }
  }

  async function disconnect() {
    stopHeartbeat();
    stopOrientationWatch();
    try {
      await sendCommand("BYE");
    } catch (_) {
      /* ignore */
    }
    await setTalking(false);
    if (state.client) {
      try {
        await state.client.leave();
      } catch (_) {
        /* ignore */
      }
    }
    state.client = null;
    state.selected.clear();
    state.online.clear();
    state.batteries.clear();
    state.flashOn.clear();
    state.frontCamera.clear();
    state.listenOn.clear();
    state.videoReady.clear();
    state.gridKey = "";
  }

  async function onConnect() {
    const appId = $("app-id").value
      .trim()
      .replace(/[\u200B-\u200D\uFEFF]/g, "")
      .replace(/^["']|["']$/g, "");
    if (appId.length < 8) {
      showGateError("Incolla un App ID Agora valido.");
      return;
    }
    const btn = $("connect-btn");
    btn.disabled = true;
    btn.textContent = "Collegamento…";
    showGateStatus("Collegamento ad Agora…");
    pingParent("joining");
    const watchdog = window.setTimeout(() => {
      pingParent("failed");
      showGateError(
        "Timeout: Agora non risponde. Controlla internet, disattiva VPN/antivirus e riprova.",
      );
      btn.disabled = false;
      btn.textContent = "Connetti";
    }, 15000);
    try {
      localStorage.setItem(APP_ID_KEY, appId);
      await connect(appId);
      window.clearTimeout(watchdog);
      pingParent("joined");
      showScreen("live");
      renderViewer();
    } catch (error) {
      window.clearTimeout(watchdog);
      pingParent("failed");
      dbg("connect error " + (error && (error.code || "") + " " + (error.message || error)));
      let text = "Connessione non riuscita.";
      try {
        text = formatJoinError(error) || text;
      } catch (_) {
        text = "Connessione non riuscita. " + errorText(error);
      }
      showGateError(text);
    } finally {
      btn.disabled = false;
      btn.textContent = "Connetti";
    }
  }

  function isIdeBrowser() {
    try {
      if (window.top === window) return false;
      const href = String(window.top.location.href || "");
      return !/^https?:\/\/(localhost|127\.0\.0\.1)/i.test(href);
    } catch (_) {
      return true;
    }
  }

  try {
    $("app-id").value = localStorage.getItem(APP_ID_KEY) || "";
    $("connect-btn").addEventListener("click", onConnect);
    $("app-id").addEventListener("keydown", (event) => {
      if (event.key === "Enter") onConnect();
    });
    async function goToLogin() {
      await disconnect();
      showScreen("gate");
      renderViewer();
    }
    $("leave-btn").addEventListener("click", goToLogin);
    $("talk-btn").addEventListener("click", async () => {
      await setTalking(!state.talking);
    });
    if (isIdeBrowser()) {
      showGateError(
        "Apri il visore in Chrome o Edge, non nella finestra di Cursor. Il Simple Browser non supporta Agora/WebRTC.",
      );
    } else if (typeof AgoraRTC === "undefined") {
      showGateError("SDK Agora mancante. Ricarica con Ctrl+F5 (build 19e).");
    }
  } catch (error) {
    console.error(error);
    showGateError("Pagina non inizializzata. Aggiorna con Ctrl+F5.");
  }

  window.addEventListener("beforeunload", () => {
    if (state.client) {
      stopHeartbeat();
      stopOrientationWatch();
      sendCommand("BYE");
      state.client.leave();
    }
  });

  window.addEventListener("resize", () => {
    if (state.screen === "live") {
      renderGrid();
      refreshAllOrientations();
    }
  });
})();
