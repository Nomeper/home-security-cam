# Configurazione Firebase e token Agora

Questo progetto non contiene credenziali Firebase, Agora App ID o Agora App Certificate.

## 1. Creare e collegare il progetto Firebase

1. Crea un progetto Firebase e abilita Authentication con email/password.
2. Installa Firebase CLI e FlutterFire CLI.
3. Dalla root del progetto esegui `flutterfire configure`.
4. Abilita App Check per Android e Apple, poi configura il provider indicato dalla console.
5. Seleziona `europe-west1` anche per eventuali servizi backend futuri.

Il comando FlutterFire genera `lib/firebase_options.dart` e le configurazioni native: sono necessari prima di inizializzare Firebase nel client.

## 2. Configurare e distribuire la Function

Accedi con `firebase login`, poi dalla root:

```powershell
firebase use --add
firebase functions:secrets:set AGORA_APP_ID
firebase functions:secrets:set AGORA_APP_CERTIFICATE
firebase deploy --only functions,firestore:rules
```

Non salvare i due valori in file, variabili Dart, `key.properties`, `.env` o nel repository.

## 3. Modello dati server-managed

Prima di consentire richieste di token, crea queste risorse tramite una console amministrativa o uno script eseguito con privilegi Admin SDK:

```text
homes/{homeId}/members/{firebaseUid}
  active: true
  agoraUid: <intero univoco 1..4294967295>

homes/{homeId}/devices/{deviceId}
  active: true
  ownerUid: <Firebase UID della telecamera>
  agoraUid: <intero univoco 1..4294967295>
```

`homeId` e `deviceId` accettano solo lettere, numeri, `_` e `-`, con massimo 40 caratteri.

La Function `createRtcSession` verifica l'utente Firebase, l'appartenenza attiva alla casa e, per le telecamere, la proprietà del dispositivo. Solo dopo rilascia un token Agora valido 15 minuti. Viewer e camera ricevono UID diversi.

## 4. Onboarding e abbinamento

L'app usa Firebase Authentication con email/password. Abilita questo provider prima del primo avvio.

Le risorse sono create esclusivamente da Function callable:

1. Il proprietario autenticato richiama `createHome`; diventa il solo membro `owner`.
2. Il proprietario richiama `createPairingCode` con `target: "camera"` oppure `"viewer"`.
3. Il dispositivo o viewer accede con il proprio account Firebase e richiama `redeemPairingCode` con `homeId` e codice.

I codici sono casuali, monouso e validi per 10 minuti. Nel database è salvato soltanto il loro hash SHA-256. Una telecamera riceve un `deviceId` e un UID Agora univoco, mentre un viewer riceve una membership con UID distinto.

## 5. Verifica

1. `cd functions; npm test`
2. Effettua l'accesso con un utente Firebase registrato.
3. Richiedi il token da un client con App Check attivo.
4. Controlla che utenti non membri, device ID alterati e token scaduti siano rifiutati.
