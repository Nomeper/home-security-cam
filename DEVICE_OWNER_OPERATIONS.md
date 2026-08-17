# Operazioni Device Owner — Recovery kiosk

## Policy scelta (modello gratuito, senza backend)

- Non esiste comando backend per uscire dal kiosk: Firebase non è in uso.
- Non esiste PIN locale, gesto segreto o menu utente per uscire dal kiosk.
- Il recupero è il **factory reset fisico** secondo le istruzioni del produttore.

## Fallback

- Verificare la procedura di factory reset specifica del produttore prima della distribuzione.
- Il reset elimina app, App ID locale, dati e stato Device Owner.
- Dopo reset, ripetere provisioning QR e inserimento App ID.

## Test

- Device Owner in release: Lock Task dopo join RTC della telecamera.
- Build debug: Lock Task non parte.
- Device offline / kiosk: recovery solo mediante reset fisico.
