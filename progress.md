# Stato del Progetto — Home Security Cam

> Memoria a lungo termine per Cursor. All’inizio di ogni chat nuova: `@progress.md` → «Parti da qui».
> Aggiornare **dopo ogni modifica significativa** (e a fine sessione).

## Ultimo aggiornamento: 2026-08-17

- **Progetto:** Applicazione Flutter Android per telecamera di sicurezza domestica (Agora RTC).
- **Branch:** main
- **Working tree:** APK v1.0.1 firmato; da pubblicare su GitHub Releases

## Panoramica tecnica

| Area | Dettaglio |
|------|-----------|
| Stack | Flutter/Dart, Agora RTC, solo smartphone Android |
| Streaming | App ID Agora locale, token vuoto, canale `casa_sicura`, UID fissi (CAM 10–60, visore 100) |
| Backend | Nessuno. Firebase / Cloud Functions non usati (servirebbero Blaze a pagamento) |
| Device Owner | QR kiosk sulla telecamera dedicata; visore = APK sul telefono quotidiano |

## Completato

- Revisione, blueprint, signing release, privacy, lifecycle, permessi, R8, package `com.bebobbx.home_security_cam`.
- Viewer audience senza pubblicazione; camera solo video; FGS Android; kiosk dopo join RTC in release Device Owner.
- **Ripristino modello originale gratuito:** rimosso Firebase dal client; schermata App ID; join RTC con token vuoto; torcia via data stream `FLASH`.
- `flutter analyze` senza issue e 9 unit test superati.
- APK firmato `home-security-cam-1.0.1.apk` (253.4 MB). SHA-256 hex `9156159d4b7823056afc7816705790dc8bf1904d0f2040f5baae35e2cca6a4cf`, Base64 URL-safe `kVYVnUt4IwVq_HgWcFeQ3IvxkE0PIED1uq414sympM8`. QR in `device-owner/`.

## In corso

- Pubblicazione GitHub Release `v1.0.1` e verifica download QR.

## Problemi aperti / da verificare

- [ ] Console Agora: progetto Testing **senza token** (App Certificate disabilitata o equivalente).
- [ ] Stesso App ID su visore e telecamera; test video reale.
- [ ] Recupero kiosk: solo factory reset (nessun backend).
- [ ] Non usare il QR/APK v1.0.0.

## Prossimi passi

1. Pubblicare Release `v1.0.1` con APK e `SHA256SUMS.txt`.
2. Creare progetto Agora gratis e copiare l’App ID sui due telefoni.
3. Test: visore su telefono quotidiano, telecamera via QR su device dedicato.
