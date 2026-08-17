# Stato del Progetto — Home Security Cam

> Memoria a lungo termine per Cursor. All’inizio di ogni chat nuova: `@progress.md` → «Parti da qui».
> Aggiornare **dopo ogni modifica significativa** (e a fine sessione).

## Ultimo aggiornamento: 2026-08-17

- **Progetto:** Applicazione Flutter per una telecamera di sicurezza domestica.
- **Branch:** non disponibile (workspace non inizializzato come repository Git)
- **Ultimo commit:** non disponibile
- **Working tree:** non disponibile

## Panoramica tecnica

| Area | Dettaglio |
|------|-----------|
| Stack | Flutter/Dart con Agora RTC, Android/iOS/macOS/web/desktop |
| Note | Firebase Functions pronta per token RTC; configurazione Firebase/deployment ancora necessari |

## Completato

- Creata la memoria persistente del progetto.
- Completata revisione statica di sorgenti, configurazioni native e test.
- Creato `BLUEPRINT.md` con ordine, verifiche e criteri di completamento.
- Rimosso dalla root il file non referenziato che esponeva l'Agora App ID.
- Fase 0.2: release non usa più la debug key; build release fallisce senza `android/key.properties`; aggiunto esempio e ignore keystore.
- Fase 1.1: aggiunta Function Firebase autorizzata per token RTC temporanei e client service; `npm test` e `flutter analyze` superati.
- Fase 1.2: aggiunti Firebase Auth, creazione casa e pairing server-side con codici monouso hashati; `npm test` e `flutter analyze` superati.
- Fase 1.3: il client usa sessioni RTC server-side; viewer audience senza pubblicazione locale e camera broadcaster; `npm test` e `flutter analyze` superati.
- Fase 1.4: comandi torcia autorizzati e mirati via Function/Firestore; data stream RTC rimosso; `npm test` e `flutter analyze` superati.
- Fase 1.5: definita policy privacy; microfono e push-to-talk disabilitati, solo il video telecamera è pubblicato; `flutter analyze` superato.
- Fase 2.1: lifecycle esplicito; Android foreground service con notifica persistente, iOS interrompe il video in background; `flutter analyze` e build debug Android superati.
- Fase 2.2: dichiarazioni privacy camera iOS/macOS ed entitlement macOS aggiunti; XML Apple e `flutter analyze` validati.
- Fase 2.3: cleartext HTTP globale Android disabilitato; `flutter analyze` e build debug Android superati.
- Fase 2.4: richiesta camera limitata alla telecamera con recupero da negazione permanente/restrizione; `flutter analyze` superato.
- Fase 2.5: Android smartphone dichiarata unica piattaforma supportata; documentata matrice test; `flutter test` superato (test placeholder).
- Fase 3.1: rilascio engine RTC protetto da inizializzazione parziale; `flutter analyze` superato.
- Fase 3.2: callback RTC e operazioni asincrone protetti da `mounted`; `flutter analyze` superato.
- Fase 3.3: azioni media attendono l'esito dell'engine e gestiscono errori; `flutter analyze` superato.
- Fase 3.4: orientamento spostato in lifecycle e reset reso selettivo; `flutter analyze` superato.
- Fase 4.1: rimosso flusso App ID e costanti RTC fisse dal client; `flutter analyze` superato.
- Fase 4.2: nomi telecamere normalizzati e validati; `flutter analyze` superato.
- Fase 4.3: controlli principali semantici/focalizzabili e stato connessione testuale; `flutter analyze` superato.
- Fase 5.1: R8 e resource shrinking abilitati per release; keep rule Agora/foreground service aggiunte; build debug e analisi superate.
- Fase 5.2: Android application ID/namespace e branding aggiornati; build debug e analisi superate.
- Fase 5.3: test no-op sostituito con 8 unit test per ruoli, nomi e sessione RTC; test e analisi superati.
- Fase 5.4: repository Git inizializzato, ignore verificati e CI Android aggiunta; nessun commit creato.
- Creato `DEVICE_OWNER_BLUEPRINT.md` per Android Enterprise Device Owner/kiosk mode.
- Device Owner D0.2: recovery definito via comando backend del proprietario; factory reset come fallback offline.
- Device Owner D1.1: aggiunto Device Admin Receiver e manifest/XML DPC minimi; build debug e analisi superate.
- Device Owner D1.2: aggiunto bridge Flutter–Android per stato e Lock Task; non ancora attivato dalla UI; build debug e analisi superate.
- Device Owner D1.3: Lock Task bloccato in debug e su device non Device Owner; build debug e analisi superate.
- Device Owner D2.1: Lock Task richiesto solo dopo join RTC autorizzato della telecamera; build debug e analisi superate.
- Device Owner D2.2: Lock Task conserva system info/notifica foreground senza restrizioni Wi‑Fi/reset/emergenza; build debug e analisi superate.
- Device Owner D2.3: errori di sessione mostrano recovery con retry senza bypass kiosk; build debug e analisi superate.

## In corso

- Fasi 1.1–5.4 pronte al test su dispositivi Android; serve verifica release firmata con R8 e test Firebase/emulator.

## Problemi aperti / da verificare

- [ ] Ruotare/verificare l'identificativo nel progetto Agora e impedire accesso senza token.
- [ ] Creare keystore di produzione e `android/key.properties` locale (non in repo) per firmare release.
- [ ] Configurare Firebase, App Check e segreti Agora, poi distribuire la Function.
- [ ] Configurare Firebase/App Check e provare pairing, token e ruoli su dispositivi reali.
- [ ] Testare background, lock, interruzioni e ritorno in app su Android/iOS reali.
- [ ] Correggere configurazioni di privacy e ciclo di vita.
- [ ] Aggiungere test reali e definire le piattaforme supportate.

## Prossimi passi

1. Configurare Firebase, App Check e secret Agora; distribuire Functions.
2. Eseguire test end-to-end su dispositivi Android reali e build release firmata.
3. Implementare Device Owner D3.1: preparare APK release firmato e hosting verificabile.
