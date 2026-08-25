# Agora gratis (senza Firebase)

Casa Sicura serve a **guardare casa in diretta**: i telefoni in casa sono le telecamere, un altro telefono o il PC è il visore. Sul visore scegli quali CAM accendere (fino a sei).

Questa app **non ha un server proprio**. Il video in diretta tra telecamere e visore passa da **Agora**. Senza un account Agora e l’**App ID** (il codice API che ti danno), l’app non funziona: visore e telecamere non si vedono.

Visore e telecamera usano lo stesso Agora App ID, la stessa **chiave di casa**, il canale `casa_sicura` e nessun token.

Ogni mese hai **10.000 minuti di streaming gratis**. Per una casa di solito basta. Non serve carta di credito.

## 1. Crea un progetto Agora gratuito

1. Apri [www.agora.io](https://www.agora.io/) e **registrati** (console: [console.agora.io](https://console.agora.io)).
2. Crea un progetto in modalità Testing.
3. Copia l’**App ID** (è il codice API: incollalo sull’app).
4. Lascia disabilitata l’App Certificate: il progetto deve accettare il join **senza token**.

Non copiare l’App Certificate nell’app.

Sull’app e sul visore PC, sotto il campo App ID, c’è il link `www.agora.io` (registrati qui; 10.000 minuti gratis al mese) che apre il sito nel browser predefinito.

## 2. Chiave di casa (cifratura)

Scegli una parola o frase di almeno **8 caratteri**. Non è l’App ID: la inventi tu.

- Stessa chiave su visore telefono, tutte le CAM e visore PC (8–62 caratteri; oltre 62 il browser non entra).
- Cifra video, audio e comandi (`WATCH:`, flash, lente, batteria) con AES-256-GCM2 di Agora.
- Se un dispositivo ha una chiave diversa, vede schermo nero e i comandi non arrivano.
- Chi ha solo l’App ID, senza la chiave, non decifra il flusso.

Non pubblicare la chiave. Se la dimentichi, su ogni telefono usa «Reimposta App ID, chiave e ruolo» e reinserisci tutto.

## 3. Uso

- Telefono visore: installa l’APK, incolla App ID e chiave, scegli Visore.
- Telefono telecamera: stesso App ID e stessa chiave, scegli CAM 1–6 (o QR Device Owner, che usa CAM 1).
- Visore PC: avvia `web-viewer/avvia.bat`, incolla **lo stesso** App ID e **la stessa** chiave. Chiudi il visore sul telefono mentre usi il PC.

Le telecamere e almeno un visore devono essere online contemporaneamente. Un solo visore alla volta: l’ultimo comando `WATCH:` vince.

Serve l’APK **1.0.1+19** (o più nuovo) su tutti i telefoni. L’APK +18 non ha la cifratura e non parla con questa versione.
