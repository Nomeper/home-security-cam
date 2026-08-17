# Home Security Cam

Applicazione Android per usare un telefono come telecamera domestica e un altro come visore, con video in tempo reale via Agora.

## Piattaforma supportata

Solo smartphone Android. I target Flutter generati per altre piattaforme non sono supportati né distribuiti.

Consulta [ANDROID_SUPPORT.md](ANDROID_SUPPORT.md) per requisiti e matrice di test.

## Configurazione (gratis)

1. Crea un progetto Agora di test senza token: [AGORA_SETUP.md](AGORA_SETUP.md).
2. Installa l'APK su visore e telecamera.
3. Incolla **lo stesso App ID** su entrambi i telefoni.
4. Sul visore scegli Visore; sulla telecamera scegli CAM 1–6 (un Device Owner usa CAM 1).

Non serve Firebase, carta di credito o backend.

## Verifica

```powershell
flutter analyze
flutter test
flutter build apk --debug
```
