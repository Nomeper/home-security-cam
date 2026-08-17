# Blueprint di correzione — Home Security Cam

## Obiettivo

Portare l'app a un livello distribuibile, correggendo prima i rischi di accesso non autorizzato e privacy, poi affidabilità, qualità e manutenzione. Nessuna release deve essere pubblicata prima del completamento delle fasi 0–2.

## Regole di esecuzione

- Una voce per volta: implementazione, test automatici, test manuale su dispositivo e revisione del diff.
- Le credenziali non entrano nel repository, nel client o nella documentazione.
- Ogni voce conclusa aggiorna `progress.md`.
- Prima dei test di integrazione RTC: usare un progetto Agora di sviluppo separato.

## Fase 0 — Contenimento immediato

### 0.1 Ruotare ed eliminare i segreti esposti

- **Rischio:** critico.
- **Problema:** un file nella root sembra contenere un Agora App ID; l'ID e i dettagli di accesso sono inoltre gestiti lato client.
- **Azioni:** revocare/ruotare l'identificativo nel portale Agora; eliminare il file; aggiungere una configurazione di esempio senza valori reali; definire come il client riceve solo token temporanei.
- **Verifica:** ricerca del workspace senza chiavi/App ID reali; token precedente inutilizzabile.

### 0.2 Bloccare la distribuzione Android non sicura — DONE (code)

- **Rischio:** critico.
- **Problema:** la variante release usa la firma debug.
- **Azioni:** configurare keystore di rilascio esterno al repository e variabili/`key.properties` locali esclusi da Git; interrompere la build release se la configurazione manca.
- **Verifica:** APK/AAB release firmato con certificato di produzione e verificato con `apksigner`.
- **Stato:** `build.gradle.kts` non usa più la debug key; manca `key.properties` → la build release fallisce; creato `android/key.properties.example`; `.gitignore` esclude keystore e `key.properties`. Resta da creare il keystore reale sul PC e firmare/verificare un artefatto release.

## Fase 1 — Accesso RTC e autorizzazione

### 1.1 Introdurre un backend per token Agora — IMPLEMENTATO, DA CONFIGURARE

- **Rischio:** critico; prerequisito per 1.2–1.5.
- **Problema:** token vuoto, canale fisso e UID prevedibili consentono accessi non autorizzati.
- **Azioni:** realizzare un endpoint autenticato che emetta token RTC a durata breve; generare channel ID e UID per installazione/sessione; usare privilegi e scadenze Agora; non esporre la chiave App Certificate.
- **Verifica:** il client entra soltanto con token valido; token scaduto/rimosso non accede; il certificato resta solo nel backend.
- **Stato:** aggiunta Cloud Function Firebase `createRtcSession` con token di 15 minuti, segreti Firebase, App Check obbligatorio e autorizzazione Firestore per casa/dispositivo. Aggiunto client `RtcSessionService`. Restano configurazione Firebase, segreti Agora, dati di onboarding e integrazione della sessione nella UI (punti 1.2–1.3).

### 1.2 Autenticare utenti e dispositivi — IMPLEMENTATO, DA CONFIGURARE

- **Rischio:** critico.
- **Problema:** non esiste un'identità verificabile per viewer e camera.
- **Azioni:** definire login dell'utente, onboarding sicuro della telecamera e associazione proprietario-dispositivo; autorizzare ogni richiesta token sul server.
- **Verifica:** un utente non proprietario non riceve token per canale/dispositivo altrui.
- **Stato:** aggiunti login/registrazione Firebase nel client e callable Function server-managed per creare case e codici di pairing. I codici sono hashati, monouso e validi dieci minuti; la camera riceve un'identità Firebase e UID Agora distinti. Resta da distribuire Firebase, abilitare App Check e collegare il flusso di pairing alla selezione ruoli/alla sessione RTC.

### 1.3 Separare rigorosamente i ruoli RTC — IMPLEMENTATO, DA TESTARE

- **Rischio:** critico.
- **Problema:** il viewer entra come broadcaster e pubblica audio/video.
- **Azioni:** viewer come audience/subscriber, con pubblicazione locale esplicitamente disabilitata; camera come broadcaster con sole tracce necessarie.
- **Verifica:** packet/log RTC e test integrazione confermano che il viewer non pubblica tracce.
- **Stato:** il setup client ora abbina casa/dispositivo, richiede una sessione al backend e usa `appId`, canale, UID e token ricevuti. La camera entra come broadcaster con sole tracce locali; il viewer entra come audience con pubblicazione camera/microfono disattivata. Le camere remote usano gli UID dinamici ricevuti da Agora. Restano da testare token e App Check sul progetto Firebase reale.

### 1.4 Autorizzare i comandi remoti — IMPLEMENTATO, DA TESTARE

- **Rischio:** critico.
- **Problema:** chiunque raggiunga il canale può inviare comandi torcia.
- **Azioni:** preferire endpoint backend autenticato rispetto a data stream RTC; se si conserva il data stream, firmare i messaggi, includere nonce, timestamp, device ID, autorizzazione server e protezione replay.
- **Verifica:** comando da sender non autorizzato, duplicato o scaduto viene ignorato e registrato.
- **Stato:** rimosso il comando torcia sul data stream RTC. Il proprietario della casa invia un comando mirato tramite Function; soltanto l'account della telecamera associata può leggere il proprio feed Firestore e confermare l'esito. I comandi scadono dopo 30 secondi e non sono scrivibili direttamente dal client. La policy iniziale autorizza solo il proprietario della casa.

### 1.5 Definire privacy e modello operativo — COMPLETATO

- **Rischio:** alto.
- **Decisioni richieste:** la camera deve trasmettere in background? l'audio della camera è necessario? il viewer ha push-to-talk? quali utenti possono controllare torcia e cambio camera?
- **Output:** policy documentata, indicatori UI, permessi minimi e test di accettazione per ogni ruolo.
- **Stato:** policy registrata in `PRIVACY_POLICY.md`. La camera pubblica solo video; viewer e camera non richiedono microfono e il push-to-talk è disabilitato. La telecamera deve continuare il video in background; l'implementazione nativa e gli indicatori persistenti sono pianificati nella fase 2.1.

## Fase 2 — Privacy, rete e piattaforme native

### 2.1 Rendere esplicito il comportamento in background — IMPLEMENTATO, DA TESTARE

- **Rischio:** alto.
- **Problema:** `WidgetsBindingObserver` è registrato ma non gestisce gli stati dell'app.
- **Azioni:** implementare `didChangeAppLifecycleState`; fermare/riattivare correttamente preview, tracce, canale e wake lock secondo la policy 1.5; mostrare stato chiaro all'utente.
- **Verifica:** background, lock, chiamata/interruzione, split-screen e ritorno all'app rispettano la policy e non lasciano cattura ambigua.
- **Stato:** Android avvia un foreground service `camera` con notifica persistente prima del background e lo termina quando la sessione si chiude. Su iOS la pubblicazione video e preview si fermano in background e riprendono al ritorno: la cattura video continua non è consentita dal sistema operativo. Build debug Android e analisi Flutter superate; rimangono test su dispositivi reali e configurazione della notifica Android.

### 2.2 Correggere permessi e privacy Apple — COMPLETATO

- **Rischio:** alto.
- **Problema:** `Info.plist` iOS/macOS non dichiara motivazioni camera/microfono; sandbox macOS non include entitlement media.
- **Azioni:** aggiungere `NSCameraUsageDescription` e `NSMicrophoneUsageDescription` localizzabili; configurare entitlement macOS richiesti; verificare il comportamento su device reale.
- **Verifica:** richiesta di permesso comprensibile e approvazione senza crash/reject di build.
- **Stato:** aggiunto `NSCameraUsageDescription` a iOS e macOS. Aggiunti entitlement macOS sandbox per camera e client network in Debug/Profile e Release. Il microfono non richiede descrizioni né entitlement perché la policy corrente non lo usa.

### 2.3 Disabilitare il cleartext globale Android — COMPLETATO

- **Rischio:** alto.
- **Problema:** `usesCleartextTraffic="true"` abilita HTTP non cifrato.
- **Azioni:** rimuoverlo; se un'eccezione locale è realmente necessaria, usare un `network_security_config` ristretto a dominio e debug.
- **Verifica:** release rifiuta HTTP e funziona esclusivamente con endpoint TLS validi.
- **Stato:** rimosso `android:usesCleartextTraffic="true"` dal manifest. Build debug Android e analisi Flutter superate; gli endpoint Firebase/Agora usano TLS.

### 2.4 Limitare e recuperare dai permessi negati — COMPLETATO

- **Rischio:** medio.
- **Azioni:** richiedere solo il permesso necessario al ruolo e all'azione; distinguere negato, permanentemente negato, ristretto e hardware assente; offrire accesso alle impostazioni quando appropriato.
- **Verifica:** test manuali per ogni stato di permesso su Android e Apple.
- **Stato:** il viewer non richiede permessi hardware; la telecamera richiede solo camera. La UI distingue negazione temporanea da negazione permanente/restrizione e offre l'apertura delle impostazioni in quest'ultimo caso. Resta da verificare manualmente su Android e Apple.

### 2.5 Dichiarare le piattaforme supportate — COMPLETATO

- **Rischio:** medio.
- **Problema:** il progetto include target generati ma non completati.
- **Azioni:** decidere i target realmente supportati; completare configurazioni e test o rimuovere i target non supportati dalla distribuzione/documentazione.
- **Verifica:** matrice dispositivi/OS documentata e smoke test per ogni target distribuito.
- **Stato:** Android smartphone è l'unica piattaforma supportata/distribuita. Creato `ANDROID_SUPPORT.md` con requisiti e matrice pre-release; README aggiornato. I target Flutter generati per altre piattaforme non sono supportati e non devono essere inclusi nelle release.

## Fase 3 — Stabilità del client Flutter

### 3.1 Rendere sicuro il ciclo di vita dell'engine RTC — COMPLETATO

- **Rischio:** medio.
- **Problema:** `_engine` può restare non inizializzato e `dispose` genera `LateInitializationError`.
- **Azioni:** rendere l'engine nullable o tracciare l'inizializzazione; gestire fallimenti di setup; rilasciare risorse una sola volta.
- **Verifica:** avvio senza configurazione, errore init e navigazione rapida non producono eccezioni.
- **Stato:** il rilascio dell'engine è condizionato alla sua creazione effettiva; un fallimento prima della creazione non può più generare `LateInitializationError` durante `dispose`.

### 3.2 Evitare aggiornamenti UI dopo dispose — COMPLETATO

- **Rischio:** medio.
- **Azioni:** dopo ogni `await` e nei callback RTC, controllare `mounted` prima di `setState`; annullare listener/timer quando necessario.
- **Verifica:** test widget e navigazione durante join, leave e salvataggio impostazioni.
- **Stato:** aggiunti controlli `mounted` dopo le operazioni asincrone di sessione, discovery camere, inizializzazione engine e salvataggio nome; i callback RTC che aggiornano la UI sono protetti.

### 3.3 Rendere affidabili le azioni media — COMPLETATO

- **Rischio:** medio.
- **Problema:** mute, torcia, cambio camera e comandi audio ignorano errori RTC.
- **Azioni:** attendere le chiamate asincrone, gestire esito/rollback e mostrare errori recuperabili; aggiornare lo stato UI solo dopo successo.
- **Verifica:** simulare errori API e confermare coerenza fra UI e stato engine.
- **Stato:** torcia, cambio camera, modalità eco e audio remoto ora attendono l'esito dell'engine, aggiornano la UI solo dopo successo e mostrano un errore recuperabile altrimenti. Il comando torcia remoto mostra un errore se l'invio al backend fallisce.

### 3.4 Correggere side effect e reset configurazione — COMPLETATO

- **Rischio:** medio.
- **Azioni:** spostare lock orientamento fuori da `build`; sostituire `SharedPreferences.clear()` con rimozione delle sole chiavi dell'app.
- **Verifica:** rebuild ripetuti non ripetono operazioni piattaforma; reset conserva preferenze future non correlate.
- **Stato:** l'orientamento è impostato in `initState`, non in `build`. Il reset rimuove solamente ruolo, pairing, nomi camera legacy e la vecchia chiave App ID, senza usare più `SharedPreferences.clear()` né disconnettere l'account Firebase.

## Fase 4 — Dati, UX e accessibilità

### 4.1 Rimuovere configurazione sensibile dal client — COMPLETATO

- **Rischio:** medio.
- **Problema:** App ID, ruolo e nomi delle telecamere sono in `SharedPreferences`.
- **Azioni:** eliminare l'App ID dal flusso client; usare storage sicuro solo per credenziali/sessioni quando necessario; minimizzare e proteggere i metadati domestici.
- **Verifica:** backup/ispezione locale non espone segreti; logout/reset elimina correttamente i dati previsti.
- **Stato:** rimosso il flusso UI che richiedeva/salvava Agora App ID, oltre a canale e UID RTC fissi. Il client ottiene i parametri RTC temporanei solo dalla Function. Il reset rimuove ogni residuo di configurazione locale precedente.

### 4.2 Validare i nomi delle telecamere — COMPLETATO

- **Rischio:** basso.
- **Azioni:** trim, limite di lunghezza, caratteri consentiti e messaggi di errore; sanitizzare l'output semantico.
- **Verifica:** input vuoto, molto lungo e con caratteri anomali resta gestito e leggibile.
- **Stato:** i nomi sono trim-mati, gli spazi sono normalizzati, la lunghezza è limitata a 32 caratteri e i caratteri di controllo sono rifiutati. Il dialog resta aperto e mostra un errore se il salvataggio non supera la validazione.

### 4.3 Completare l'accessibilità — COMPLETATO

- **Rischio:** medio.
- **Azioni:** sostituire/integrare gesture con controlli semantici; aggiungere label, ruolo, hint, tooltip, focus e azioni tastiera; non comunicare lo stato solo a colori.
- **Verifica:** TalkBack/VoiceOver e navigazione tastiera consentono tutte le azioni principali.
- **Stato:** ruoli, selezione camera e azioni principali usano controlli semantici focalizzabili; sono presenti label, hint e stato selezionato. Lo stato di connessione ha etichette testuali/semantiche e il titolo segnala connessione o disconnessione, non solo colore.

## Fase 5 — Qualità di rilascio e manutenzione

### 5.1 Abilitare hardening Android — IMPLEMENTATO, DA VERIFICARE

- **Rischio:** basso.
- **Azioni:** attivare R8/minify e resource shrinking dopo aver aggiunto le keep rule verificate per Agora.
- **Verifica:** build release funziona nelle funzioni RTC essenziali e riduce dimensione artefatto.
- **Stato:** R8/minificazione e resource shrinking sono abilitati per release; aggiunte keep rule conservative per Agora RTC e foreground service. Build debug e analisi Flutter superate. La build release con R8 resta da verificare dopo la creazione del keystore di produzione.

### 5.2 Sostituire i placeholder di prodotto — COMPLETATO

- **Rischio:** basso.
- **Azioni:** impostare application ID/namespace definitivi e aggiornare README, web manifest e metadati.
- **Verifica:** package name univoco, branding coerente e documentazione d'avvio reale.
- **Stato:** namespace/application ID Android impostati a `com.bebobbx.home_security_cam`; package Kotlin rinominato e nome visualizzato aggiornato a “Home Security Cam”. README e documentazione Android descrivono il prodotto e la configurazione reale.

### 5.3 Creare una suite di test utile — IMPLEMENTATO, DA ESTENDERE

- **Rischio:** alto per affidabilità.
- **Azioni:** sostituire il test no-op; aggiungere unit test per ruoli, validazione, token e comandi; widget test per permessi/stati/errori; integrazione per lifecycle RTC; test manuale privacy/accessibilità.
- **Verifica:** pipeline esegue analisi, test e build release; la copertura include tutti i flussi critici.
- **Stato:** sostituito il test no-op con 8 unit test per persistenza ruoli, nomi telecamera e parsing/validazione della sessione RTC. Restano test widget, test della Function Firebase con emulator e test di integrazione su device per i flussi critici.

### 5.4 Inizializzare controllo versione e igiene workspace — IMPLEMENTATO

- **Rischio:** medio.
- **Azioni:** inizializzare Git, escludere artefatti, keystore, credenziali, backup e file IDE; definire CI, revisioni e gestione release.
- **Verifica:** clone pulito, build riproducibile e nessun segreto/artifact generato tracciato.
- **Stato:** inizializzato repository Git senza commit; `.gitignore` esclude keystore, configurazioni locali, node_modules, backup e simboli generati. Aggiunta workflow GitHub Actions Android per dipendenze, analisi, test e build debug. Il primo commit e il collegamento a un remoto restano intenzionalmente manuali.

## Ordine operativo proposto

1. 0.1, 0.2 e 1.1: contenere esposizione e rendere sicura l'identità.
2. 1.2–1.5: completare modello di autorizzazione e privacy.
3. 2.1–2.4: correggere lifecycle, rete e piattaforme native.
4. 3.1–3.4: rendere robusto il client.
5. 4.1–4.3: privacy locale, UX e accessibilità.
6. 5.1–5.4: hardening, test, distribuzione e manutenzione.

## Prima correzione

Iniziare da **0.1 — rotazione e rimozione dei segreti esposti**, perché non richiede modifiche invasive al client e riduce subito il rischio. Per completarla serve però la disponibilità del progetto Agora e l'accesso al relativo portale.
