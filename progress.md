# Stato del Progetto — Home Security Cam

> Memoria a lungo termine per Cursor. All’inizio di ogni chat nuova: `@progress.md` → «Parti da qui».
> Aggiornare **dopo ogni modifica significativa** (e a fine sessione).

## Ultimo aggiornamento: 2026-08-24

- **APK corrente:** Release GitHub **v1.0.1+23** (`home-security-cam-1.0.1-23.apk`, **119.6 MB**, versionCode 23). SHA-256 `3092B36E53C54389959DC9B6544151F869F07CCC228ED99A62CDDEB9D45F6D06`.
- **Branch:** `main`. Note **v1.0.1+23**: a cosa serve, come funziona, Agora (registrazione, API/App ID, 10.000 minuti gratis). Stesso testo su schermata App ID, README, visore PC.
- **Note release:** `docs/RELEASE_v1.0.1+23.md`.

## Parti da qui (2026-08-24)

- Chi usa l’app deve **registrarsi su agora.io**: senza App ID (codice API) visore e telecamere non si vedono. Ogni mese **10.000 minuti di streaming gratis**.
- Installare **`home-security-cam-1.0.1-23.apk`** (Release **v1.0.1+23**) su visore e **tutte** le camere.
- Test avvio telefono (non Device Owner): dopo splash → **Scegli Ruolo**, mai ingresso automatico come VISORE.
- Test picker: bottoni e «Controllo chi è già nel canale…» **non si spostano**.
- Test visore: Home → ritorno in app → batteria cam ancora visibile; la cam che stavi guardando si rivede.
- Visore PC: `web-viewer/avvia.bat` → build **19g**. Ctrl+F5 se la pagina era già aperta.
- Chiave di casa: **8–62 caratteri**, identica su telefoni e PC (non l’App ID).
- Manuale: `docs/Manuale_uso_Casa_Sicura.pdf` (generatore aggiornato; PDF da rigenerare su Windows).
- Note release: `docs/RELEASE_v1.0.1+23.md`.
- QR kiosk: `device-owner/provisioning-qr.png` punta ancora a **v1.0.1-18**.

## Panoramica tecnica

| Area | Dettaglio |
|------|-----------|
| Stack | Flutter/Dart Android; visore PC = HTML in `web-viewer/` (Agora Web SDK 4.24) |
| Versione app | `1.0.1+23` (`pubspec.yaml`) — APK locale **1.0.1+23** |
| Streaming | App ID Agora locale, token vuoto, canale `casa_sicura`, UID fissi (CAM 10–60, visore telefono 100, visore PC 101). Probe ruoli: UID 190–199 (non svegliano le camere). Serve account agora.io (gratis, 10.000 min/mese); senza App ID l’app non parte. |
| Cifratura | Agora AES-256-GCM2 + data stream. Chiave di casa **in chiaro** (8–62 caratteri) + salt SHA-256. Stessa chiave su tutti i dispositivi. |
| Occupancy ruoli | «Scegli ruolo»: probe senza pubblicare (UID 190–199). CAM occupata = UID 10–60; VISORE = 100, 101 o altro visore. Occupato = stesso bottone **grigio**, senza testo extra. Griglia CAM 2×3 fissa; «Controllo chi è già nel canale…» in uno **slot alto 24 px** (si nasconde senza spostare nulla). Refresh a ogni ingresso (`_refreshOccupancy`) e dopo uscita visore (`_leaveToRoleSelection`). |
| Avvio app | Dopo App ID + chiave, i telefoni vanno **sempre** su «Scegli Ruolo» (il ruolo salvato non viene più ripristinato). Solo Device Owner (kiosk) entra diretto come CAM 1. |
| Ruolo visore | Host **senza** pubblicazione video/microfono (non audience). In Live Broadcast l’audience non genera `onUserJoined` e non può inviare data stream |
| On-demand | Le camere restano nel canale **senza** accendere il sensore. Il visore invia `WATCH:`; solo le camere scelte accendono la fotocamera e pubblicano. All’uscita del visore il sensore si spegne |
| Comandi data stream | `WATCH:`, `BATT:` / `BATTREQ`, `FLASH:uid:ON\|OFF`, `FLASHSTATE:`, `LISTEN:uid:ON\|OFF`, `LENS:uid:FRONT\|REAR`, `LENSSTATE:`, `BYE` (visore esce) |
| UI visore telefono | Tap: menu sopra+sotto appaiono e restano; altro tap: spariscono. Video sempre a schermo intero sotto. Pallino in alto a destra: verde = dati in transito, rosso = no. Dock: flash, audio, **lente**. |
| Visore in background | Resta nel canale (niente `BYE`/`leaveChannel`). In pausa: heartbeat off + `WATCH:` vuoto. Al ritorno: ricrea SurfaceView, rinvia `WATCH:` / `BATTREQ`. Se Agora è caduto, rientra nel canale. |
| Visore PC | `web-viewer/avvia.bat` → `http://localhost:8787/` (build **19g**). Login App ID + chiave di casa (8–62 car.), link `www.agora.io`, poi griglia + dock CAM. Agora Web non accetta `127.0.0.1`. Non usare il Simple Browser di Cursor. |
| ECO | Premendo Eco l’app va subito a nero (niente menu, niente pallino dell’app, niente preview locale). Il visore continua a vedere. Il **pallino verde di Android** (fotocamera in uso, Android 12+) può restare visibile finché il pannello è acceso: in Eco il sensore è acceso. Nello STANDBY a 0s il sensore è spento, quindi quel pallino non c’è. Doppio tocco per uscire (se spento: tasto accensione, poi 15 s per il doppio tocco). |
| Flash | Posteriore: LED torcia. Frontale: overlay bianco a luminosità 100%; spegnendo torna Eco o normale. Stesso comando `FLASH:` dal visore. |
| Batteria standby | Camera in attesa: countdown 15 s a luminosità di sistema. A 0s overlay nero e luminosità 0. In kiosk prova spegnimento pannello. Un tocco in STANDBY fa ripartire il conteggio. |
| Batteria visore | All’ingresso del visore: `BATTREQ` → ogni camera già attiva rinvia `BATT:` |
| Backend | Nessuno. Firebase / Cloud Functions non usati |
| Device Owner | QR kiosk sulla telecamera dedicata; visore = APK sul telefono quotidiano |
| APK locale / GitHub | Release GitHub **v1.0.1+23** (`home-security-cam-1.0.1-23.apk`, **119.6 MB**). SHA-256 `3092B36E53C54389959DC9B6544151F869F07CCC228ED99A62CDDEB9D45F6D06`. ABI: `arm64-v8a` + `x86_64`. Note: `docs/RELEASE_v1.0.1+23.md`. |

## Completato (sessione 2026-08-25, a cosa serve)

- Note **v1.0.1+23**, schermata App ID, README e visore PC: breve spiegazione di **a cosa serve** (telefoni come telecamere di casa, visore sul telefono o PC) e **come funziona** (stessa app, App ID + chiave, scegli le CAM da accendere).

## Completato (sessione 2026-08-24, spiegazione Agora)

- Note **v1.0.1+23**: spiegato in modo semplice che serve registrarsi su agora.io, che l’App ID è l’API necessaria all’app, e che ci sono **10.000 minuti** di streaming gratis al mese.
- Stesso testo chiaro su schermata App ID, visore PC, README, `AGORA_SETUP.md`, generatore del manuale.

## Completato (sessione 2026-08-24, APK 23)

- APK **`home-security-cam-1.0.1+23-local.apk`** (119.6 MB, avvio su «Scegli Ruolo» + layout picker fisso). La +22 eliminata.

## Completato (sessione 2026-08-24, avvio Scegli Ruolo + layout fisso)

- All’apertura dell’app (telefono, non kiosk) la prima pagina è **Scegli Ruolo**: non si entra più da soli come VISORE se quel ruolo era salvato.
- Picker: bottoni in posizione fissa (griglia CAM 2×3, niente Wrap/scroll). Il messaggio «Controllo chi è già nel canale…» ha uno slot riservato e non sposta VISORE, CAM né «Reimposta».
- Incluso in APK **+23**; su GitHub in `ea043cd`.

## Completato (sessione 2026-08-22, APK 22)

- APK **`home-security-cam-1.0.1+22-local.apk`** (119.6 MB, visore in background + picker ruoli). La +21 eliminata.

## Completato (sessione 2026-08-22, visore background + picker)

- Visore in background: **non** esce più dal canale Agora (niente `BYE`/`leaveChannel`). Al ritorno ricrea le SurfaceView, rinvia `WATCH:` / `BATTREQ` (subito e a 400/1200 ms). Se la connessione è caduta, rientra nel canale; se il join fallisce, reinizializza l’engine.
- «Scegli Ruolo»: bottoni occupati grigi con lo **stesso testo** di prima (niente «già in uso» / «in uso»). Messaggio occupancy **sotto** i bottoni, che restano fissi.
- Incluso in APK **+22**; codice **non committato**.

## Completato (sessione 2026-08-20, APK 21)

- APK **`home-security-cam-1.0.1+21-local.apk`** (119.6 MB, fix occupancy al ritorno da visore). La +20 eliminata.

## Completato (sessione 2026-08-20, fix occupancy al ritorno)

- Uscita da VISORE/CAM verso «Scegli Ruolo»: shutdown RTC **completato** prima della navigazione (`_leaveToRoleSelection`).
- `RoleSelectionScreen`: `_refreshOccupancy()` a ogni ingresso (stop probe, pausa 450 ms, nuovo probe con session id).
- Probe: re-emit occupazione a 0/400/900/1600 ms dopo join (cattura utenti già presenti).

## Completato (sessione 2026-08-20, fix visore PC + APK 20)

- Fix `OperationError` visore Web: la chiave non va più hashata in hex (64 caratteri superavano il limite RSA di Agora). Ora si usa la passphrase diretta (max 62 caratteri UTF-8), stesso salt SHA-256.
- Visore PC **19g**. APK **1.0.1+20** (`home-security-cam-1.0.1+20-local.apk`). La +19 eliminata.

## Completato (sessione 2026-08-20, cifratura canale)

- Agora built-in encryption AES-256-GCM2 su app e visore PC, anche data stream (`WATCH:`, flash, lente, batteria).
- Campo «Chiave di casa» (8–62 caratteri) sulla prima pagina app e sul login PC.

## Completato (sessione 2026-08-20, ruoli occupati)

- `RoleSelectionScreen` entra nel canale senza pubblicare e grigia CAM 1–6 e VISORE già connessi («già in uso» / «in uso»). Se l’occupante esce, il ruolo torna selezionabile.
- VISORE occupato da UID 100, 101 o qualsiasi altro visore remoto; CAM da 10–60. Probe 190–199 esclusi da `isRemoteViewerUid` (le camere non li scambiano per visori).
- File: `lib/services/role_occupancy_probe.dart`, `lib/role_selection_screen.dart`, `lib/security_page.dart`, `lib/utils.dart`. Test occupancy in `test/widget_test.dart`. Incluso in APK **+21**; codice **non committato**.

## Completato (sessione 2026-08-20, manuale d'uso PDF)

- Creato `docs/Manuale_uso_Casa_Sicura.pdf` (17 pagine, italiano): copertina, indice, setup Agora, app camera/visore, webapp `web-viewer`, Eco/standby, kiosk, privacy, problemi frequenti.
- Generatore: `docs/genera_manuale.py`.

## Completato (sessione 2026-08-20, GitHub allineato a 1.0.1+18)

- Descrizione About del repo GitHub aggiornata.
- Release **v1.0.1-18** pubblicata con APK `home-security-cam-1.0.1-18.apk` (~120 MB).
- QR Device Owner e `provisioning-qr.json` puntano a questa APK.
- Release v1.0.1 marcata come superata.

## Completato (sessione 2026-08-20, APK più leggera 1.0.1+18)

- Tolte le estensioni Agora non usate (vision, lip-sync, spatial audio, AV1, face/screen capture, beauty, AINS, AEC AI, VQA, ecc.) e il modulo screen-sharing.
- Tolto ARM 32-bit (`armeabi-v7a`). Restano `arm64-v8a` (telefoni) e `x86_64` (emulatore).
- Build locale **1.0.1+18** firmata (~120 MB). Pubblicata su GitHub come **v1.0.1-18**. La +17 è stata eliminata.

## Completato (sessione 2026-08-20, link Agora + flash frontale)

- Schermata App ID (app Android): sotto il campo, link piccolo `www.agora.io` che apre il browser predefinito del sistema (`Intent.ACTION_VIEW`).
- Visore PC **19e**: stesso link sotto l’App ID (`target=_blank`).
- Flash con lente frontale: schermo bianco a luminosità massima; spegnendo il flash si torna a Eco o alla UI normale. Posteriore resta il LED. Se il flash è acceso e si cambia lente, passa da LED a schermo (e viceversa).
- Peso APK: da ~254 MB a ~120 MB togliendo estensioni Agora extra e ABI 32-bit. Restano `arm64-v8a` + `x86_64` e encoder/decoder H.264.

## Completato (sessione 2026-08-20, luminosità solo Eco/standby)

- Tolto l’abbassamento luminosità da `setCameraPowerSave` (prima andava a ~1% anche con i menu visibili). Ora la luminosità di sistema resta durante l’uso; si forza lo schermo scuro solo in Eco e nello STANDBY a 0s (`blankDisplay`).

## Completato (sessione 2026-08-20, APK 1.0.1+17)

- Build locale **1.0.1+17** firmata: `home-security-cam-1.0.1+17-local.apk` (luminosità di sistema fuori da Eco/standby a 0s). La `1.0.1+16-local.apk` è stata eliminata. Non pubblicata su GitHub.

## Completato (sessione 2026-08-20, APK 1.0.1+16)

- Build locale **1.0.1+16** firmata: `home-security-cam-1.0.1+16-local.apk` (ECO spegne subito schermo/pallino, niente preview locale). La `1.0.1+15-local.apk` è stata eliminata. Non pubblicata su GitHub.

## Completato (sessione 2026-08-19, ECO spegne schermo subito)

- Eco ora va subito a schermo nero totale (niente pallino/preview SurfaceView). Il video verso il visore resta acceso. STANDBY tiene il countdown 15 s.

## Completato (sessione 2026-08-19, APK 1.0.1+15)

- Build locale **1.0.1+15** firmata: `home-security-cam-1.0.1+15-local.apk` (a 0s overlay nero senza scritte). La `1.0.1+14-local.apk` è stata eliminata. Non pubblicata su GitHub.

## Completato (sessione 2026-08-19, schermo nero a 0s)

- Il countdown era solo un testo: a 0s STANDBY/ECO restavano visibili. Ora a 0s overlay nero senza scritte, luminosità 0; in Device Owner `lockNow` per spegnere il pannello. Il visore può comunque collegarsi e ricevere il video.

## Completato (sessione 2026-08-19, APK 1.0.1+14)

- Build locale **1.0.1+14** firmata, poi **eliminata** dalla root a favore della +15. Non pubblicata su GitHub.

## Completato (sessione 2026-08-19, countdown schermo + ECO)

- STANDBY: testo «Fotocamera spenta. Lo schermo si spegnerà fra Ns» con conto alla rovescia da 15. Il tocco fa ripartire i 15 s.
- ECO: overlay nero invariato, ma ora può spegnere il pannello dopo 15 s **anche mentre trasmette**. Restano due gesti distinti: standby automatico in attesa; ECO manuale, anche in diretta.

## Completato (sessione 2026-08-19, APK 1.0.1+13)

- Build locale **1.0.1+13** firmata: `home-security-cam-1.0.1+13-local.apk` (lente visore + standby batteria). Superata dalla **+14**. Non pubblicata su GitHub.

## Completato (sessione 2026-08-19, lente visore + standby batteria)

- Visore telefono e visore PC: bottone lente (frontale/posteriore) accanto a flash e audio. Comandi `LENS:` / `LENSSTATE:`. Default posteriore.
- Camera in standby: schermo non resta acceso, niente wake/wifi lock extra, audio locale spento. Reattiva: resta in canale e accende il sensore al `WATCH:`.

## Completato (sessione 2026-08-18, APK 1.0.1+12)

- Build locale **1.0.1+12** firmata: `home-security-cam-1.0.1+12-local.apk` (include standby sensore cam). Sostituisce `1.0.1+11-local.apk`. Non pubblicata su GitHub. **Non include** lente visore né risparmio schermo standby.

## Completato (sessione 2026-08-18, cam standby sensore)

- Prima: fotocamera hardware sempre accesa (anche in ECO); in rete andava solo se selezionata.
- Ora: in attesa visore / visore disconnesso / cam non selezionata → sensore spento (STANDBY). Si accende solo quando il visore la seleziona; si spegne quando il visore esce o la toglie dalla griglia.

## Completato (sessione 2026-08-18, visore PC pallino tx)

- Pallino visore PC come l’app: **verde solo se arrivano frame video** da una camera selezionata; **rosso** se non c’è trasmissione (connesso ma in attesa, nessuna cam, video fermo). Superato da build **19d** (stesso pallino + bottone lente).

## Completato (sessione 2026-08-18, APK 1.0.1+11)

- Build locale **1.0.1+11** firmata: `home-security-cam-1.0.1+11-local.apk` (visore telefono adatta landscape/portrait della cam). Sostituisce `1.0.1+10-local.apk`. Non pubblicata su GitHub.

## Completato (sessione 2026-08-18, visore adatta orientamento cam)

- Visore telefono: video in `contain` (niente crop). Se la cam filma landscape o portrait, il visore mostra l’immagine in quel formato (bande nere se serve). Segue anche la rotazione a caldo.

## Completato (sessione 2026-08-18, visore PC dock + orientamento)

- Dopo il login: stesso schema dell’app (griglia + tutte le CAM in basso, click in diretta, niente «esci e rientra»).
- Video PC: `object-fit: contain`; se il frame è più alto che largo → portrait, altrimenti landscape (anche a caldo).
- Encoder camera: `orientationModeAdaptive` e rotazione telefono sbloccata, così ruotando il telefono il flusso diventa landscape/portrait. Incluso in APK **1.0.1+10**. Build visore PC **19b**.

## Completato (sessione 2026-08-18, APK 1.0.1+10)

- Build locale **1.0.1+10** firmata: `home-security-cam-1.0.1+10-local.apk` (pallino tx, visore fullscreen, niente Bluetooth, encoder adaptive). Sostituisce `1.0.1+9-local.apk`. Non pubblicata su GitHub.

## Completato (sessione 2026-08-18, niente Bluetooth)

- Rimossi permesso e richiesta «dispositivi vicini» / Bluetooth Connect. All’avvio restano solo camera, microfono e notifiche.

## Completato (sessione 2026-08-18, pallino tx + visore fullscreen)

- Pallino in alto a destra (visore e camera): verde se c’è trasmissione video, rosso se non c’è.
- Visore: tap mostra/nasconde barra sopra e dock sotto e restano così; il filmato è sempre a schermo intero sotto i menu.

## Completato (sessione 2026-08-18, visore PC tre schermate) — superato

- Build **19a** aveva login e picker separati. **Sostituito da 19b/19c/19d:** dopo il login si resta sul visore con dock CAM in diretta.

## Completato (sessione 2026-08-18, APK 1.0.1+9)

- Build locale **1.0.1+9** firmata: `home-security-cam-1.0.1+9-local.apk` (stop tx senza visore, menu camera sempre visibili). Sostituisce `1.0.1+8-local.apk`. Non pubblicata su GitHub.

## Completato (sessione 2026-08-18, chrome camera fisso)

- Sulla telecamera menu e scritte (stato, flash, eco, esci) restano sempre visibili: niente auto-hide a 5 s e il tap non li nasconde. ECO continua a oscurare tutto.

## Completato (sessione 2026-08-18, stop tx senza visore)

- Camera smette di pubblicare quando il visore esce: comando `BYE`, leave RTC atteso, heartbeat `WATCH:` ogni 4 s, timeout 12 s se Agora non manda `onUserOffline`.
- Schermo camera: niente «TRASMISSIONE ATTIVA» senza visore (torna «IN ATTESA VISORE»).

## Completato (sessione 2026-08-18, APK 1.0.1+8)

- Build locale **1.0.1+8** firmata: `home-security-cam-1.0.1+8-local.apk` (permessi avvio, esci visore senza cam). Sostituisce `1.0.1+7-local.apk`. Non pubblicata su GitHub.

## Completato (sessione 2026-08-18, permessi avvio + visore)

- All’avvio (splash, prima di App ID / ruolo) l’APK chiede subito camera, microfono e notifiche; non aspetta «Parla» o il ruolo camera. Niente Bluetooth / dispositivi vicini.
- Visore senza cam selezionata: la barra con esci resta visibile; un tap in mezzo allo schermo la riporta (area vuota ora riceve il tocco). Non si resta più bloccati.

## Completato (sessione 2026-08-18, APK locale)

- Build locale **1.0.1+7** firmata (ECO chrome, batteria visore). Sostituita da **1.0.1+8**. Non pubblicata su GitHub.

## Completato (sessione 2026-08-18, visore PC)

- Webapp visore PC in `web-viewer/`: App ID, join host silenzioso UID 101, griglia CAM, WATCH/BATTREQ/flash/audio/Parla.
- Avvio Windows: `avvia.bat` / `avvia.ps1` (server locale, perché Agora non gira da `file://`).
- `avvia.ps1` apre `http://localhost:8787/` (non 127.0.0.1: Agora Web lo rifiuta). Se la porta è occupata da un avvio precedente la libera, oppure apre solo il browser se il visore è già in ascolto.
- Connetti: il join Agora funziona in Chrome/Edge (verificato: uid 101 CONNECTED in ~1s). La finestra Simple Browser di Cursor non supporta WebRTC e resta ferma su «Ingresso nel canale».

## Completato (sessione 2026-08-18, ECO / batteria visore)

- ECO nasconde status bar (ora/icone) e navigation bar; su Device Owner anche `setStatusBarDisabled` e lock-task senza SYSTEM_INFO.
- Visore telefono e visore PC: percentuale batteria solo sotto l’icona cam nel dock/chip, non in overlay in alto a sinistra sul video.

## Completato (sessione 2026-08-18)

- Visore come host silenzioso: la camera vede il visore, riceve WATCH/flash/audio, pubblica il video.
- Video visore: niente `muteLocalVideoStream` in conflitto con `publishCameraTrack`; subscribe alle camere scelte; SurfaceView; view ricreata al primo frame.
- Dock visore fisso (non scende più dopo 5 s); flash e audio nel riquadro telecamere, non sulla griglia.
- ECO = solo overlay schermo camera; non ferma il video.
- Batteria immediata all’ingresso visore (`BATTREQ`).
- Rimossi dal working tree i target Flutter iOS, macOS, Linux, Windows e web (solo Android).
- Build locale **1.0.1+6** firmata, non pubblicata su GitHub.

## Completato (prima)

- Revisione, blueprint, signing release, privacy, lifecycle, permessi, R8, package `com.bebobbx.home_security_cam`.
- FGS Android; kiosk dopo join RTC in release Device Owner.
- Modello gratuito: niente Firebase nel client; schermata App ID; join RTC con token vuoto.
- GitHub Release **v1.0.1** (codice **obsoleto**): https://github.com/Nomeper/home-security-cam/releases/tag/v1.0.1 — superata da **v1.0.1-18**.
- QR Device Owner in `device-owner/provisioning-qr.png` (usa **v1.0.1-18**, non v1.0.0 / v1.0.1).

## In corso

- Test sul campo della Release **v1.0.1+23** (visore + tutte le camere): avvio «Scegli Ruolo», layout picker fisso, background visore, occupancy, cifratura, Eco.
- Rigenerare il PDF del manuale su Windows (`docs/genera_manuale.py`) dopo il testo Agora.

## Problemi aperti / da verificare

- [ ] Avvio telefono: dopo splash compare **Scegli Ruolo**, non il visore.
- [ ] Picker: VISORE, CAM e «Controllo chi è già nel canale…» restano **fermi**; il messaggio sparisce senza spostare il resto.
- [ ] Visore: Home → ritorno in app: batteria cam ancora visibile; cam selezionata si rivede (o un tap la riaccende). Uscire/rientrare da VISORE resta il fallback.
- [ ] Occupancy picker: bottoni occupati grigi **senza** scritte extra.
- [ ] Installare `home-security-cam-1.0.1-23.apk` su visore e **tutte** le camere (64-bit).
- [ ] Stesso App ID Agora (Testing **senza token**, account agora.io con 10.000 min/mese) e stessa chiave di casa (8–62 car.) su telefoni e visore PC **19g**.
- [ ] Occupancy picker: CAM/VISORE occupati grigi; **dopo uscita da visore** CAM occupata resta grigia; se l’occupante esce dal canale torna selezionabile.
- [ ] Cifratura: chiave sbagliata → niente video; chiave corretta → streaming e comandi data stream ok.
- [ ] Visore PC: login, join, griglia CAM, flash/audio/lente, pallino tx verde/rosso.
- [ ] Eco/STANDBY, flash frontale (schermo bianco), sensore on-demand (`WATCH:`), `BYE` quando il visore esce.
- [ ] Non usare visore telefono e visore PC insieme (ultimo `WATCH:` vince).
- [ ] Rigenerare `docs/Manuale_uso_Casa_Sicura.pdf` su Windows.

## Prossimi passi

1. Test APK **+23** su dispositivi reali (avvio «Scegli Ruolo», layout picker fisso, visore background, occupancy, cifratura, Eco).
2. Rigenerare il PDF del manuale su Windows.

