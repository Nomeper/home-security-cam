# Home Security Cam

App Android per **guardare casa in diretta** con telefoni che hai già. I telefoni in casa diventano telecamere; un altro telefono (o il PC) è il visore. Video in tempo reale via Agora, senza Firebase né backend.

## A cosa serve

Usi vecchi (o nuovi) telefoni Android come telecamere di salotto, ingresso o cortile. Dal visore vedi in diretta, accendi il flash, cambi lente e ascolti l’audio. Non è un allarme professionale e non serve comprare telecamere dedicate.

## Come funziona

1. Installa **la stessa app** sul telefono visore e sui telefoni che restano in casa (**CAM 1–6**, fino a sei).
2. Tutti usano lo **stesso App ID Agora** e la **stessa chiave di casa**.
3. Sul visore scegli quali CAM guardare: solo quelle accendono la fotocamera.
4. Puoi guardare anche dal PC. Un visore alla volta: telefono **oppure** computer.

## Piattaforme

- **Telecamere e visore telefono:** solo Android **64-bit** (`arm64-v8a`). Vedi [ANDROID_SUPPORT.md](ANDROID_SUPPORT.md).
- **Visore PC:** pagina locale in [`web-viewer/`](web-viewer/README.md). Doppio clic su `web-viewer/avvia.bat`, incolla App ID e chiave di casa, seleziona le CAM. Non usa la webcam del computer.

I telefoni ARM a 32 bit non sono supportati. L’APK include anche `x86_64` per l’emulatore.

## Cosa fa

- Stesso **App ID Agora** e stessa **chiave di casa** su visore e telecamere (progetto Testing senza token). Canale fisso `casa_sicura`. Video, audio e comandi sono cifrati con AES-256-GCM2 di Agora. Serve un account [agora.io](https://www.agora.io/) (gratis, **10.000 minuti** di streaming al mese): senza App ID l’app non parte.
- Fino a 6 CAM. Restano nel canale a sensore spento; solo quelle scelte dal visore accendono la fotocamera (`WATCH:`).
- Flash: LED sulla posteriore; sulla frontale lo schermo della CAM diventa bianco a luminosità massima.
- Lente frontale/posteriore, ascolto audio, batteria nel dock, Eco e standby schermo.
- Sulla prima pagina, sotto l’App ID, c’è il link [www.agora.io](https://www.agora.io/) per registrarsi (10.000 minuti gratis al mese).

## Configurazione (gratis)

L’app ha bisogno dell’**API di Agora** per funzionare: non ha un server proprio, il video passa da [agora.io](https://www.agora.io/). Senza un App ID, visore e telecamere non si vedono.

1. **Registrati** su [www.agora.io](https://www.agora.io/) e crea un progetto di test senza token: [AGORA_SETUP.md](AGORA_SETUP.md). Ogni mese hai **10.000 minuti di streaming gratis**.
2. Installa l’APK **`home-security-cam-1.0.1-23.apk`** (Release **v1.0.1+23**) su visore e telecamere.
3. Incolla **lo stesso App ID** (il codice API di Agora) e **la stessa chiave di casa** (almeno 8 caratteri) su tutti i dispositivi. Il link Agora nella schermata iniziale apre il browser predefinito.
4. Sul visore scegli Visore; sulla telecamera scegli CAM 1–6 (un Device Owner usa CAM 1).

Non usare visore telefono e visore PC insieme. Non serve Firebase, carta di credito o backend.

L’APK da usare è la Release GitHub **[v1.0.1+23](https://github.com/Nomeper/home-security-cam/releases/tag/v1.0.1-23)**. Chiave di casa: 8–62 caratteri, identica su telefoni e visore PC **19g**. Non usare v1.0.0 né v1.0.1. Per il kiosk vedi [device-owner/README.md](device-owner/README.md). Manuale: [docs/Manuale_uso_Casa_Sicura.pdf](docs/Manuale_uso_Casa_Sicura.pdf). Note della release: [docs/RELEASE_v1.0.1+23.md](docs/RELEASE_v1.0.1+23.md).

## Verifica

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

La build release richiede `android/key.properties` locale e un keystore esterno al repository. L’APK di rilascio locale pesa circa **120 MB**.
