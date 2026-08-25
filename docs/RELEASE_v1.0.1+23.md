# Cosa è cambiato — Home Security Cam 1.0.1+23

Rispetto alla Release GitHub **v1.0.1-18**. Installare **la stessa APK** sul visore e su **tutte** le telecamere. L’APK +18 non parla con questa versione.

**Download:** [home-security-cam-1.0.1-23.apk](https://github.com/Nomeper/home-security-cam/releases/download/v1.0.1-23/home-security-cam-1.0.1-23.apk)  
**Peso:** 119.6 MB (solo Android 64-bit)  
**SHA-256:** `3092B36E53C54389959DC9B6544151F869F07CCC228ED99A62CDDEB9D45F6D06`

---

## A cosa serve

Casa Sicura è un’app per **guardare casa in diretta** con telefoni che hai già. I telefoni in casa diventano telecamere; un altro telefono (o il PC) è il **visore**. Non è un allarme professionale e non serve comprare telecamere dedicate: vedi salotto, ingresso o cortile dal telefono che tieni con te.

## Come funziona (in breve)

1. Installi **la stessa app** sul telefono visore e sui telefoni che restano in casa (**CAM 1–6**, fino a sei).
2. Tutti usano lo **stesso App ID Agora** e la **stessa chiave di casa**.
3. Sul visore scegli quali CAM guardare: **solo quelle** accendono la fotocamera. Da lì puoi anche accendere il flash, cambiare lente e ascoltare l’audio.
4. Puoi guardare anche dal **PC**. Un visore alla volta: telefono **oppure** computer.

---

## Serve Agora, altrimenti l’app non parte

Questa app **non ha un server proprio**. Il video in diretta tra le telecamere e il visore passa da **Agora**, un servizio di streaming su internet ([www.agora.io](https://www.agora.io/)).

Per questo ti serve l’**API di Agora**: è l’**App ID**, un codice lungo che Agora ti dà dopo la registrazione. Lo incolli sull’app. Senza quell’App ID visore e telecamere non si trovano: lo streaming non parte.

Cosa fare (è gratis):

1. Vai su [www.agora.io](https://www.agora.io/) e **registrati**.
2. Nella console crea un progetto in modalità **Testing** (senza token).
3. Copia l’**App ID** e incollalo su **tutti** i telefoni e sul visore PC (sempre lo stesso).

Ogni mese hai **10.000 minuti di streaming gratis**. Per una casa (qualche telecamera, uso quotidiano) di solito è abbastanza. Non serve carta di credito.

Poi scegli una **chiave di casa** (8–62 caratteri, la inventi tu) e usala identica ovunque. Non è l’App ID: cifra il video.

---

## Da fare subito

1. Disinstalla la vecchia app (o aggiorna sopra) su visore e camere.
2. Installa `home-security-cam-1.0.1-23.apk` su **ogni** telefono.
3. Registrati su [www.agora.io](https://www.agora.io/), crea un progetto Testing e inserisci lo stesso **App ID Agora** e la stessa **chiave di casa** (8–62 caratteri) su tutti i dispositivi, anche sul visore PC.
4. All’apertura dell’app compare **Scegli Ruolo**: tocca VISORE o CAM 1–6. Non entra più da sola come visore.

La chiave di casa **non è** l’App ID: la inventi tu. Senza la stessa chiave, video e comandi restano neri/muti.

---

## Novità principali

### Cifratura del canale

Video, audio e comandi (flash, lente, batteria, quale camera guardare) sono cifrati con AES-256-GCM2 di Agora. Chi ha solo l’App ID, senza la chiave, non vede il flusso.

### Prima pagina = Scegli Ruolo

Aprendo l’app (dopo App ID e chiave) si sceglie sempre il ruolo. Non viene più ripristinato in automatico l’ultimo VISORE. Le telecamere in kiosk (Device Owner) restano CAM 1.

### Ruoli già occupati

Sulla pagina Scegli Ruolo, se una CAM o il VISORE è già nel canale, il bottone resta **grigio** (stesso testo di prima). Il messaggio «Controllo chi è già nel canale…» sta fermo sotto i bottoni e non sposta nulla.

### Visore in background

Se premi Home, il visore **resta nel canale**. Tornando in app dovresti rivedere batteria e camera. Non serve più uscire e rientrare da VISORE, salvo se la connessione è caduta.

### Visore PC (build 19g)

Stesso App ID e stessa chiave di casa. Avvio: `web-viewer/avvia.bat` → `http://localhost:8787/` (non `127.0.0.1`). C’è anche il bottone lente, come sul telefono.

---

## Altre migliorie (già nel codice dopo la +18)

- Flash: LED sulla lente posteriore; sulla frontale lo schermo della CAM diventa bianco a luminosità massima.
- Bottone **lente** (frontale/posteriore) sul visore telefono e PC.
- Eco: schermo nero subito. Standby: conto alla rovescia 15 s, poi nero.
- Le CAM tengono il sensore spento finché il visore non le seleziona (`WATCH:`).
- Permessi camera, microfono e notifiche chiesti all’avvio. Niente Bluetooth.

---

## Cosa non è cambiato

- Canale fisso `casa_sicura`, progetto Agora Testing **senza token**.
- Un solo visore alla volta (telefono **oppure** PC).
- Niente Firebase, niente backend.
- Recupero kiosk: solo reset di fabbrica.

---

## Kiosk (Device Owner)

QR aggiornato: `device-owner/provisioning-qr.png` (scarica questa APK +23). Telefono nuovo o azzerato, ARM 64-bit, rete durante il download.
