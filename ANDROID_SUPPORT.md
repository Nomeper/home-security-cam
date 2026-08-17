# Supporto piattaforma Android

## Ambito di rilascio

Home Security Cam è supportata e distribuita esclusivamente per smartphone Android.

I target iOS, macOS, Windows, Linux e web presenti nel workspace sono scaffolding Flutter generato e non fanno parte del prodotto, del piano di rilascio o della garanzia di compatibilità.

## Requisiti

- Smartphone Android con fotocamera.
- Android API 23 o superiore, come definito dalla configurazione Flutter/Android del progetto.
- Connessione Internet TLS.
- Notifiche abilitate per visualizzare l'indicatore persistente della trasmissione video in background.

## Matrice di test pre-release

| Area | Casi minimi |
|---|---|
| Installazione | Installazione pulita e aggiornamento dalla release precedente |
| Account e pairing | Accesso, creazione casa, pairing viewer e telecamera, codici scaduti o riutilizzati |
| Streaming | Avvio camera, visualizzazione, riconnessione e token scaduto |
| Privacy | Permesso camera concesso, negato, permanente e ripristinato dalle impostazioni |
| Background | Home, lock screen, ritorno all'app, chiusura esplicita della sessione e notifica foreground |
| Comandi | Torcia autorizzata dal proprietario, rifiuto per membro non autorizzato, conferma camera |
| Rete | Wi‑Fi, rete cellulare, perdita/ripristino connessione e TLS |
| Release | APK/AAB firmato con keystore produzione, verifica firma e installazione su dispositivo reale |

## Comandi supportati

```powershell
flutter analyze
flutter test
flutter build apk --debug
flutter build appbundle --release
```

La build release richiede `android/key.properties` locale e un keystore esterno al repository.
