# Stato del Progetto — Home Security Cam

> Memoria a lungo termine per Cursor. All’inizio di ogni chat nuova: `@progress.md` → «Parti da qui».
> Aggiornare **dopo ogni modifica significativa** (e a fine sessione).

## Ultimo aggiornamento: 2026-08-20 (GitHub Release v1.0.1-18)

- **Progetto:** Applicazione Flutter Android per telecamera di sicurezza domestica (Agora RTC) + visore PC statico.
- **Branch:** main
- **Working tree:** da allineare con release GitHub e QR Device Owner.

## Parti da qui (2026-08-20, GitHub allineato)

- Installare **[home-security-cam-1.0.1-18.apk](https://github.com/Nomeper/home-security-cam/releases/tag/v1.0.1-18)** su visore e **tutte** le camere. **Solo ARM 64-bit**.
- Release GitHub: https://github.com/Nomeper/home-security-cam/releases/tag/v1.0.1-18 (~120 MB).
- QR Device Owner aggiornato a questa APK (`device-owner/provisioning-qr.png`). Non usare v1.0.0 / v1.0.1.
- Flash frontale: schermo bianco a luminosità max. Link `www.agora.io` sotto l’App ID.
- Visore PC: `web-viewer/avvia.bat` → `http://localhost:8787/index.html?v=19e`.
- Manuale PDF: `docs/Manuale_uso_Casa_Sicura.pdf`.

## Panoramica tecnica

| Area | Dettaglio |
|------|-----------|
| Stack | Flutter/Dart Android; visore PC = HTML in `web-viewer/` (Agora Web SDK 4.24) |
| Versione app | `1.0.1+18` (`pubspec.yaml`) — APK locale **1.0.1+18** |
| Streaming | App ID Agora locale, token vuoto, canale `casa_sicura`, UID fissi (CAM 10–60, visore telefono 100, visore PC 101) |
| Ruolo visore | Host **senza** pubblicazione video/microfono (non audience). In Live Broadcast l’audience non genera `onUserJoined` e non può inviare data stream |
| On-demand | Le camere restano nel canale **senza** accendere il sensore. Il visore invia `WATCH:`; solo le camere scelte accendono la fotocamera e pubblicano. All’uscita del visore il sensore si spegne |
| Comandi data stream | `WATCH:`, `BATT:` / `BATTREQ`, `FLASH:uid:ON\|OFF`, `FLASHSTATE:`, `LISTEN:uid:ON\|OFF`, `LENS:uid:FRONT\|REAR`, `LENSSTATE:`, `BYE` (visore esce) |
| UI visore telefono | Tap: menu sopra+sotto appaiono e restano; altro tap: spariscono. Video sempre a schermo intero sotto. Pallino in alto a destra: verde = dati in transito, rosso = no. Dock: flash, audio, **lente**. |
| Visore PC | `web-viewer/avvia.bat` → `http://localhost:8787/` (build **19e**). Login App ID con link `www.agora.io`, poi griglia + dock CAM in diretta (come l’app). Bottone **Post/Front** accanto a Flash e Audio. Pallino verde solo con frame video. Video `contain` portrait/landscape. Agora Web non accetta `127.0.0.1`. Non usare il Simple Browser di Cursor. |
| ECO | Premendo Eco l’app va subito a nero (niente menu, niente pallino dell’app, niente preview locale). Il visore continua a vedere. Il **pallino verde di Android** (fotocamera in uso, Android 12+) può restare visibile finché il pannello è acceso: in Eco il sensore è acceso. Nello STANDBY a 0s il sensore è spento, quindi quel pallino non c’è. Doppio tocco per uscire (se spento: tasto accensione, poi 15 s per il doppio tocco). |
| Flash | Posteriore: LED torcia. Frontale: overlay bianco a luminosità 100%; spegnendo torna Eco o normale. Stesso comando `FLASH:` dal visore. |
| Batteria standby | Camera in attesa: countdown 15 s a luminosità di sistema. A 0s overlay nero e luminosità 0. In kiosk prova spegnimento pannello. Un tocco in STANDBY fa ripartire il conteggio. |
| Batteria visore | All’ingresso del visore: `BATTREQ` → ogni camera già attiva rinvia `BATT:` |
| Backend | Nessuno. Firebase / Cloud Functions non usati |
| Device Owner | QR kiosk sulla telecamera dedicata; visore = APK sul telefono quotidiano |
| APK locale / GitHub | `home-security-cam-1.0.1+18-local.apk` e Release **[v1.0.1-18](https://github.com/Nomeper/home-security-cam/releases/tag/v1.0.1-18)** (~120 MB). SHA-256 `B2EA23D92B87D420003199D97C975FCB466C56DD0D21108D2F19C242245D949B`. ABI: `arm64-v8a` + `x86_64`. |

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
- Build locale **1.0.1+18** firmata: `home-security-cam-1.0.1+18-local.apk` (**119.5 MB**, prima 253.7 MB). La +17 è stata eliminata. Non pubblicata su GitHub.

## Completato (sessione 2026-08-20, link Agora + flash frontale)

- Schermata App ID (app Android): sotto il campo, link piccolo `www.agora.io` che apre il browser predefinito del sistema (`Intent.ACTION_VIEW`).
- Visore PC **19e**: stesso link sotto l’App ID (`target=_blank`).
- Flash con lente frontale: schermo bianco a luminosità massima; spegnendo il flash si torna a Eco o alla UI normale. Posteriore resta il LED. Se il flash è acceso e si cambia lente, passa da LED a schermo (e viceversa).
- Peso APK: analizzato, nessuna modifica a ABI/plugin. Motivo: librerie native Agora (~99+78+74 MB non compressi per arm64 / armv7 / x86_64) più estensioni non usate (vision, lip-sync, spatial audio, AV1, ecc.).

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
- GitHub Release **v1.0.1** (codice **obsoleto**, senza griglia/WATCH/batteria/dock/ECO nuovo): https://github.com/Nomeper/home-security-cam/releases/tag/v1.0.1
- QR Device Owner in `device-owner/provisioning-qr.png` (non usare v1.0.0).

## In corso

- Installare APK **1.0.1+18** su visore e **tutte** le camere (64-bit).
- Test: link Agora, flash frontale a schermo, video come prima.

## Problemi aperti / da verificare

- [x] Ricostruire APK **1.0.1+18** (estensioni Agora extra e ARM 32-bit rimossi). La +17 è stata eliminata.
- [ ] Installare `home-security-cam-1.0.1+18-local.apk` su visore e tutte le camere. **Non** installare su telefoni ARM 32-bit.
- [ ] Verificare streaming: video e audio come prima (encoder H.264 tenuto).
- [ ] Verificare prima pagina: link piccolo `www.agora.io` sotto l’App ID; apre il browser predefinito (app e visore PC **19e**).
- [ ] Verificare flash visore con lente **frontale**: schermo CAM tutto bianco, luminosità max; OFF → torna Eco o normale. Posteriore: LED come prima.
- [ ] Verificare ECO: nero totale subito, niente menu/pallino **dell’app**; visore continua a vedere; doppio tocco esce. Il pallino verde di sistema Android può restare (fotocamera accesa).
- [ ] Verificare STANDBY: countdown 15→0; poi schermo nero senza menu/orario/testo; tocco fa ripartire i 15 s.
- [ ] Verificare visore: bottone lente accanto a flash e audio; frontale ↔ posteriore a caldo.
- [ ] Verificare visore PC **19e**: stesso bottone Post/Front sul chip CAM; link Agora in login.
- [ ] Verificare CAM in standby: schermo si spegne / si oscura; alla selezione visore si accende subito e trasmette.
- [ ] Verificare CAM: in attesa visore → STANDBY, fotocamera spenta; visore seleziona → si accende; visore esce → si spegne. Anche in ECO.
- [ ] Verificare visore: cam landscape → immagine landscape; cam portrait → immagine portrait.
- [ ] Verificare pallino in alto a destra: verde con dati in transito, rosso senza.
- [ ] Verificare visore: tap mostra menu e restano; altro tap li nasconde; video sempre a schermo intero.
- [ ] Verificare CAM: stato e pulsanti sempre visibili, senza toccare lo schermo.
- [ ] Verificare: visore esce → CAM mostra «IN ATTESA VISORE», non «TRASMISSIONE ATTIVA», video non in rete.
- [ ] Verificare all’avvio: camera, microfono, notifiche. **Niente** dialogo «dispositivi vicini».
- [ ] Verificare visore senza cam: barra con esci visibile; tap in mezzo la mostra se nascosta.
- [ ] Verificare: batteria visibile subito all’apertura visore, senza selezionare la camera.
- [ ] Verificare: selezione CAM → immagini; CAM mostra «TRASMISSIONE ATTIVA»; flash, audio, lente; «Parla».
- [ ] Verificare ECO: overlay nero, niente ora/icone; visore continua a vedere; doppio tocco o tasto accensione. Pallino verde di sistema Android possibile mentre il sensore gira.
- [ ] Verificare visore: batteria solo sotto l’icona cam nel dock, non in alto a sinistra sul video.
- [ ] Non usare visore telefono e visore PC insieme (ultimo `WATCH:` vince).
- [ ] Stesso App ID Agora (progetto Testing **senza token**) su tutti i telefoni e sul PC.
- [x] Modifiche committate e pushate su `main`.
- [x] GitHub Release **v1.0.1-18** pubblicata. QR Device Owner aggiornato. Non usare v1.0.0 / v1.0.1.
- [ ] Recupero kiosk: solo factory reset (nessun backend).
- [ ] Non usare il QR/APK v1.0.0.

## Prossimi passi

1. Installare [home-security-cam-1.0.1-18.apk](https://github.com/Nomeper/home-security-cam/releases/tag/v1.0.1-18) su visore e **tutte** le camere.
2. Verificare video, flash frontale, link Agora, Eco/STANDBY.
3. Eventuale ulteriore taglio `x86_64` **solo se richiesto** (scenderebbe ancora, ma niente emulatore).
