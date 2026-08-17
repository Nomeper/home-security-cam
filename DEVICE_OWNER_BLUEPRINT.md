# Blueprint — Android Enterprise Device Owner

## Obiettivo

Configurare gli smartphone Android dedicati alle telecamere come dispositivi Android Enterprise fully managed, con l'app Home Security Cam in kiosk mode solo dopo pairing e autorizzazione.

## Vincoli fondamentali

- Il provisioning Device Owner richiede un telefono nuovo o ripristinato ai dati di fabbrica.
- Device Owner non equivale a root: le capacità sono limitate dalle API Android Enterprise e dalla versione/OEM del dispositivo.
- QR, APK e backend non devono contenere App Certificate Agora, token persistenti o credenziali Firebase.
- Ogni modifica viene testata su un telefono secondario: un errore di kiosk mode può rendere difficile uscire dall'app.
- Il supporto prodotto resta limitato a smartphone Android.

## Fase D0 — Prerequisiti operativi

### D0.1 Definire dispositivi e canale di distribuzione

- Scegliere modelli e versioni Android reali da supportare.
- Decidere dove ospitare l'APK/AAB: serve un URL HTTPS diretto, stabile e versionato per l'APK firmato.
- Non usare URL che restituiscono pagine HTML o redirect non controllati.
- **Verifica:** download diretto dell'APK firmato da un dispositivo ripristinato.

### D0.2 Definire il recupero amministrativo — COMPLETATO

- Stabilire come uscire dal kiosk: codice amministrativo locale, comando backend autorizzato oppure procedura fisica documentata.
- Non creare un bypass accessibile a chi usa fisicamente la telecamera.
- Documentare factory reset, cambio proprietario e revoca del dispositivo.
- **Verifica:** un amministratore autorizzato recupera il dispositivo; un utente normale non può uscire dall'app.
- **Stato:** scelta uscita kiosk tramite comando backend esclusivo del proprietario, senza PIN o bypass locale. Factory reset fisico è il fallback offline. Dettagli e casi di test in `DEVICE_OWNER_OPERATIONS.md`.

### D0.3 Separare le identità

- Ogni telefono telecamera usa un account Firebase dedicato e pairing code monouso.
- Il Device Owner non sostituisce autenticazione, token Agora o autorizzazione backend.
- **Verifica:** un device non abbinato non può ottenere token RTC né entrare in kiosk operativo.

## Fase D1 — Base nativa Android Enterprise

### D1.1 Creare il Device Admin Receiver — COMPLETATO

- Aggiungere classe Kotlin `DeviceAdminReceiver`.
- Dichiarare receiver e file XML delle policy nel manifest Android.
- Richiedere solo policy necessarie; evitare amministrazione superflua.
- **Verifica:** l'app viene riconosciuta come componente DPC durante il provisioning.
- **Stato:** aggiunti `HomeSecurityDeviceAdminReceiver`, metadata manifest e `device_admin.xml` con policy vuote/minime. Il receiver non prova ad auto-attivarsi: il ruolo Device Owner può essere assegnato esclusivamente dal provisioning Android. Build debug Android superata.

### D1.2 Implementare il bridge Flutter–Android — COMPLETATO

- Esporre via Method Channel: stato Device Owner, avvio/arresto Lock Task e stato kiosk.
- Il bridge deve restituire errori espliciti quando l'app non è Device Owner.
- **Verifica:** test unitari Kotlin dove possibili e chiamata Flutter su device non gestito senza crash.
- **Stato:** aggiunto Method Channel per stato Device Owner, stato Lock Task e avvio/arresto Lock Task. Le chiamate native rifiutano device non provisionati. Il bridge non è ancora richiamato dalla UI, quindi nessun device entra in kiosk durante questa fase. Build debug e analisi superate.

### D1.3 Validare stato prima delle policy — COMPLETATO

- Attivare policy enterprise solo se `DevicePolicyManager.isDeviceOwnerApp()` è true.
- Non attivare kiosk durante sviluppo/debug o su device non provisionato.
- **Verifica:** build debug ordinaria mantiene normale navigazione Android.
- **Stato:** il bridge Flutter segnala l'eleggibilità solo in release su Device Owner; Android verifica anche runtime che l'app non sia debuggable e che sia Device Owner prima di avviare Lock Task. La build debug resta non attivabile e compila correttamente.

## Fase D2 — Kiosk mode sicuro

### D2.1 Consentire Lock Task solo alla telecamera — IMPLEMENTATO, DA TESTARE

- Inserire l'app fra i Lock Task packages.
- Attivare Lock Task dopo pairing riuscito e solo per il ruolo telecamera.
- Il viewer non entra in kiosk mode.
- **Verifica:** telecamera abbinata resta nell'app; viewer mantiene la normale navigazione.
- **Stato:** Lock Task è richiesto solo dal callback di join RTC riuscito della telecamera, quindi dopo token e pairing autorizzati. Viewer, setup e build debug non lo attivano. Occorre verificare il comportamento su APK release e device Device Owner factory-reset.

### D2.2 Configurare restrizioni minime — IMPLEMENTATO, DA TESTARE

- Limitare navigazione, impostazioni e funzioni di sistema solo nella misura richiesta.
- Conservare la notifica foreground della trasmissione video.
- Non disabilitare meccanismi di emergenza/sicurezza del sistema senza una policy operativa approvata.
- **Verifica:** Home/Recent non permettono uscita non autorizzata; l'indicatore di cattura resta visibile.
- **Stato:** su Android 9+ Lock Task mantiene system info e notifiche, inclusa la notifica foreground di cattura; Home/Overview restano bloccati dal Lock Task. Non sono applicate restrizioni Wi‑Fi, reset o emergenza. Build debug e analisi superate; richiede prova release Device Owner.

### D2.3 Gestire lifecycle e recovery — IMPLEMENTATO, DA TESTARE

- Riavviare il flusso telecamera solo dopo login/pairing validi.
- Se token, pairing o camera permission falliscono, mostrare schermata di recupero; non lasciare il device in una UI bloccata senza azioni.
- **Verifica:** token scaduto, rete assente e camera permission negato portano a stato recuperabile.
- **Stato:** errori di pairing/token/rete/fotocamera mostrano una schermata di recovery con messaggio e retry; il retry rilascia l'eventuale engine parziale e reinizializza la sessione. Non viene offerto un bypass per uscire dal kiosk. Build debug e analisi superate; da testare con errori reali su device.

## Fase D3 — Provisioning QR

### D3.1 Preparare artefatto firmato

- Creare APK release firmato da keystore produzione.
- Calcolare checksum SHA-256 dell'APK.
- Pubblicare il file su HTTPS diretto e immutabile per versione.
- **Verifica:** checksum del file scaricato corrisponde a quello inserito nel QR.

### D3.2 Generare payload QR Android Enterprise

- Inserire componente Device Admin, URL APK, checksum e parametri Wi‑Fi solo se indispensabili.
- Usare `adminExtras` per un codice enrollment monouso, mai per segreti.
- Limitare scadenza e uso del codice sul backend.
- **Verifica:** QR prova il provisioning su un device factory-reset e rifiuta codice scaduto/riusato.

### D3.3 Onboarding dopo provisioning

- Alla prima apertura, l'app effettua login/pairing Firebase dell'account telecamera.
- Registra il device nel backend e abilita il kiosk soltanto dopo conferma.
- **Verifica:** il QR installa l'app ma il video non parte finché pairing e autorizzazione non sono completi.

## Fase D4 — Operazioni e sicurezza

### D4.1 Audit e inventario

- Registrare nel backend identificatore logico del device, casa associata, versione app e ultimo check-in.
- Non archiviare IMEI o altri identificativi personali senza necessità e base legale.
- **Verifica:** il proprietario può vedere stato online/offline del proprio device.

### D4.2 Aggiornamento app

- Definire aggiornamento APK firmato, verificato e rollback.
- Testare aggiornamento mantenendo pairing e policy kiosk.
- **Verifica:** upgrade e rollback non perdono l'accesso della telecamera.

### D4.3 Play policy e privacy

- Verificare requisiti Google Play/Android Enterprise applicabili alla distribuzione.
- Mantenere informative sulla cattura video e notifica foreground.
- **Verifica:** checklist di rilascio completata prima di distribuzione esterna.

## Ordine di implementazione

1. D0.2 — recupero amministrativo.
2. D1.1–D1.3 — DPC e bridge senza kiosk.
3. D2.1–D2.3 — kiosk limitato alla telecamera e recovery.
4. D3.1–D3.3 — APK firmato, QR e onboarding.
5. D4.1–D4.3 — operazioni, aggiornamenti e rilascio.

## Primo intervento

Iniziare da **D0.2 — recupero amministrativo**. Il meccanismo scelto influenza l'implementazione del bridge nativo e del kiosk; non è sicuro attivare Lock Task prima di aver definito una via di recupero autorizzata.
