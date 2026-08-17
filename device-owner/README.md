# QR Android Enterprise — v1.0.1

File pronto: `device-owner/provisioning-qr.png`

Apri quell'immagine a schermo intero sul PC e inquadrala dal telefono factory-reset (6 tocchi sulla schermata iniziale).

## Contenuto

| Campo | Valore |
|---|---|
| Device Admin | `com.bebobbx.home_security_cam/.HomeSecurityDeviceAdminReceiver` |
| APK | `https://github.com/Nomeper/home-security-cam/releases/download/v1.0.1/home-security-cam-1.0.1.apk` |
| SHA-256 hex | `9156159d4b7823056afc7816705790dc8bf1904d0f2040f5baae35e2cca6a4cf` |
| SHA-256 Base64 URL-safe | `kVYVnUt4IwVq_HgWcFeQ3IvxkE0PIED1uq414sympM8` |

Non inserire password Wi‑Fi, token Agora o credenziali Firebase nel QR.

## Prima del test

Il telefono deve essere nuovo o ripristinato ai dati di fabbrica e avere rete durante il download (~253 MB). GitHub Releases usa un redirect HTTPS: se il provisioning fallisce sul download, serve un URL diretto senza redirect.

Dopo l'installazione: stesso Agora App ID sul visore e sulla telecamera. Progetto Agora Testing senza token, vedi `AGORA_SETUP.md`.
