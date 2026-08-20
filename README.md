# Home Security Cam

App Android per usare telefoni come telecamere di casa e un altro telefono (o il PC) come visore. Video in tempo reale via Agora, senza Firebase né backend.

## Piattaforme

- **Telecamere e visore telefono:** solo Android **64-bit** (`arm64-v8a`). Vedi [ANDROID_SUPPORT.md](ANDROID_SUPPORT.md).
- **Visore PC:** pagina locale in [`web-viewer/`](web-viewer/README.md). Doppio clic su `web-viewer/avvia.bat`, incolla l’App ID, seleziona le CAM. Non usa la webcam del computer.

I telefoni ARM a 32 bit non sono supportati. L’APK include anche `x86_64` per l’emulatore.

## Cosa fa

- Stesso **App ID Agora** su visore e telecamere (progetto Testing senza token). Canale fisso `casa_sicura`.
- Fino a 6 CAM. Restano nel canale a sensore spento; solo quelle scelte dal visore accendono la fotocamera (`WATCH:`).
- Flash: LED sulla posteriore; sulla frontale lo schermo della CAM diventa bianco a luminosità massima.
- Lente frontale/posteriore, ascolto audio, batteria nel dock, Eco e standby schermo.
- Sulla prima pagina, sotto l’App ID, c’è il link piccolo [www.agora.io](https://www.agora.io/).

## Configurazione (gratis)

1. Crea un progetto Agora di test senza token: [AGORA_SETUP.md](AGORA_SETUP.md).
2. Installa l’APK **[1.0.1+18](https://github.com/Nomeper/home-security-cam/releases/tag/v1.0.1-18)** su visore e telecamere.
3. Incolla **lo stesso App ID** su tutti i dispositivi. Il link Agora nella schermata iniziale apre il browser predefinito.
4. Sul visore scegli Visore; sulla telecamera scegli CAM 1–6 (un Device Owner usa CAM 1).

Non usare visore telefono e visore PC insieme. Non serve Firebase, carta di credito o backend.

L’APK GitHub **[v1.0.1+18](https://github.com/Nomeper/home-security-cam/releases/tag/v1.0.1-18)** è quella da usare. Non usare v1.0.0 né v1.0.1. Per il kiosk vedi [device-owner/README.md](device-owner/README.md). Manuale: [docs/Manuale_uso_Casa_Sicura.pdf](docs/Manuale_uso_Casa_Sicura.pdf).

## Verifica

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

La build release richiede `android/key.properties` locale e un keystore esterno al repository. L’APK di rilascio locale pesa circa **120 MB**.
