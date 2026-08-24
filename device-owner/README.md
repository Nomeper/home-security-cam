# QR Android Enterprise — v1.0.1+18

File pronto: `device-owner/provisioning-qr.png`

Apri quell'immagine a schermo intero sul PC e inquadrala dal telefono factory-reset (6 tocchi sulla schermata iniziale). Serve un telefono **ARM 64-bit**.

## Contenuto

| Campo | Valore |
|---|---|
| Device Admin | `com.bebobbx.home_security_cam/.HomeSecurityDeviceAdminReceiver` |
| APK | `https://github.com/Nomeper/home-security-cam/releases/download/v1.0.1-18/home-security-cam-1.0.1-18.apk` |
| SHA-256 hex | `B2EA23D92B87D420003199D97C975FCB466C56DD0D21108D2F19C242245D949B` |
| SHA-256 Base64 URL-safe | `suoj2SuH1CAAMZnZfJdfy0ZsVt0NIRCNLxnCQiRdlJs` |

Non inserire password Wi‑Fi, token Agora o credenziali Firebase nel QR.

## Prima del test

Il telefono deve essere nuovo o ripristinato ai dati di fabbrica, **ARM 64-bit**, e avere rete durante il download (~120 MB). Non usare i QR/APK **v1.0.0** o **v1.0.1**. GitHub Releases usa un redirect HTTPS: se il provisioning fallisce sul download, serve un URL diretto senza redirect.

Dopo l'installazione: stesso Agora App ID e stessa chiave di casa sul visore e sulla telecamera. Progetto Agora Testing senza token, vedi `AGORA_SETUP.md`.
