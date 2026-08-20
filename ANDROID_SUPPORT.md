# Supporto piattaforma Android

## Ambito di rilascio

Home Security Cam è supportata e distribuita solo per smartphone Android **64-bit**. Il repository Flutter contiene soltanto il target Android.

Il visore per PC è una pagina statica in `web-viewer/` (HTML + Agora Web SDK), non un build Flutter web.

## Requisiti

- Smartphone Android con fotocamera, CPU **ARM 64-bit** (`arm64-v8a`). I telefoni 32-bit (`armeabi-v7a`) non installano l’APK.
- Android API 23 o superiore, come definito dalla configurazione Flutter/Android del progetto.
- Connessione Internet TLS.
- Permessi all’avvio: fotocamera, microfono, notifiche. Niente Bluetooth.
- Notifiche abilitate per l’indicatore persistente della trasmissione in background.

L’APK include `arm64-v8a` (telefoni) e `x86_64` (emulatore). Peso circa **120 MB** dopo il taglio delle estensioni Agora non usate.

## Matrice di test pre-release

| Area | Casi minimi |
|---|---|
| Installazione | Installazione pulita su telefono 64-bit; rifiuto su 32-bit |
| App ID | Stesso codice su visore e CAM; link `www.agora.io` apre il browser di sistema |
| Ruoli | Visore, CAM 1–6, Device Owner → CAM 1 |
| Streaming | Selezione CAM → video; visore esce → CAM in standby, sensore spento |
| Flash | Posteriore: LED; frontale: schermo bianco a luminosità max; OFF → Eco o normale |
| Lente | Frontale ↔ posteriore a caldo da visore telefono e visore PC |
| Privacy | Permesso camera/microfono concesso, negato e ripristinato dalle impostazioni |
| Background | Home, lock screen, ritorno all’app, notifica foreground mentre la CAM è selezionata |
| Eco / standby | Eco: nero subito; standby: countdown 15 s poi nero; doppio tocco esce da Eco |
| Rete | Wi‑Fi, rete cellulare, perdita/ripristino connessione |
| Release | APK firmato con keystore produzione, verifica firma e installazione su dispositivo reale |

## Comandi supportati

```powershell
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release --target-platform android-arm64,android-x64
```

La build release richiede `android/key.properties` locale e un keystore esterno al repository. L’artefatto pubblicato è [GitHub Release v1.0.1+18](https://github.com/Nomeper/home-security-cam/releases/tag/v1.0.1-18) (~120 MB, 64-bit).
