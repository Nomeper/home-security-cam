# Home Security Cam

Applicazione Android per usare dispositivi abbinati come telecamere domestiche e monitorare il video in tempo reale.

## Piattaforma supportata

Solo smartphone Android. I target Flutter generati per altre piattaforme non sono supportati né distribuiti.

Consulta [ANDROID_SUPPORT.md](ANDROID_SUPPORT.md) per requisiti e matrice di test.

## Configurazione

- Configura Firebase, App Check e i segreti Agora seguendo [FIREBASE_SETUP.md](FIREBASE_SETUP.md).
- Configura il keystore Android locale tramite `android/key.properties.example`.

## Verifica

```powershell
flutter analyze
flutter test
flutter build apk --debug
```
