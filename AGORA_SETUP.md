# Agora gratis (senza Firebase)

Visore e telecamera usano lo stesso Agora App ID, canale `casa_sicura` e nessun token.

## 1. Crea un progetto Agora gratuito

1. Apri [console.agora.io](https://console.agora.io) (sito: [www.agora.io](https://www.agora.io/)) e registrati.
2. Crea un progetto in modalità Testing.
3. Copia l’**App ID**.
4. Lascia disabilitata l’App Certificate: il progetto deve accettare il join **senza token**.

Non copiare l’App Certificate nell’app.

Sull’app e sul visore PC, sotto il campo App ID, c’è il link piccolo `www.agora.io` che apre il sito nel browser predefinito.

## 2. Uso

- Telefono visore: installa l’APK, incolla l’App ID, scegli Visore.
- Telefono telecamera: stesso App ID, scegli CAM 1–6 (o QR Device Owner, che usa CAM 1).
- Visore PC: avvia `web-viewer/avvia.bat`, incolla lo **stesso** App ID. Chiudi il visore sul telefono mentre usi il PC.

Le telecamere e almeno un visore devono essere online contemporaneamente. Un solo visore alla volta: l’ultimo comando `WATCH:` vince.
