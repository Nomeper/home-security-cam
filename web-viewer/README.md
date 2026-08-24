# Visore PC (web)

Pagina locale per guardare le telecamere Android dal computer. Non è un’app Flutter web: è un visore HTML che usa lo stesso protocollo Agora dell’APK.

## Cosa fa

- Chiede l’**App ID Agora** e la **chiave di casa** (gli stessi dei telefoni). Sotto l’App ID c’è il link `www.agora.io`.
- Entra nel canale `casa_sicura` come visore (host silenzioso, UID **101**), con cifratura AES-256-GCM2.
- Non accende la webcam del PC.
- Tocca CAM 1–6 per chiedere il video (`WATCH:`). Batteria, flash, audio, lente (frontale/posteriore) e «Parla» come sul telefono visore.
- Flash sulla CAM frontale: lo schermo del telefono diventa bianco a piena luminosità.

Build attuale: **19g**.

## Avvio su Windows

1. Chiudi il visore sull’app Android (telefono). Due visori insieme si pestano i comandi WATCH.
2. Chiudi l’eventuale finestra nera di un visore PC già aperto, poi doppio clic su `avvia.bat`.
3. Si apre **`http://localhost:8787/`** nel browser (Chrome o Edge). Agora non funziona su `127.0.0.1`.
4. Incolla App ID e chiave di casa, poi premi **Connetti**.

Se la porta 8787 è già occupata da un avvio precedente (anche un `python -m http.server` rimasto appeso), lo script la libera e riparte. Se il visore è già in ascolto, apre solo il browser.

Se il file `.bat` non parte, da PowerShell:

```powershell
cd web-viewer
powershell -ExecutionPolicy Bypass -File .\avvia.ps1
```

Oppure:

```powershell
cd web-viewer
python -m http.server 8787
```

Poi apri `http://localhost:8787/`.

Non aprire `index.html` con doppio clic (`file://`): WebRTC di Agora richiede `http://localhost`. Non usare il Simple Browser di Cursor.

## Requisiti

- Progetto Agora in modalità Testing **senza token**, come in [AGORA_SETUP.md](../AGORA_SETUP.md).
- Telecamere con APK **1.0.1+19** (o più nuovo), stessa chiave di casa.
- Internet. L’SDK Agora è il file locale `AgoraRTC_N.js`.

## Note

- UID 101 evita di cacciare il visore telefono (UID 100) se restano entrambi in canale. Usa comunque **un visore alla volta**.
- Clic destro su una CAM per rinominarla (solo su questo PC).
- «Parla» chiede il microfono del browser.
