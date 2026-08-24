# Policy operativa e privacy

## Cattura della telecamera

- La telecamera pubblica video solo quando il visore è presente e quella CAM è selezionata.
- In attesa del visore il sensore resta spento (standby).
- Il microfono della telecamera si attiva solo su richiesta esplicita del visore (pulsante audio nel dock).
- Su Android, quando la telecamera passa in background o lo schermo si blocca, la sessione continua con foreground service e notifica persistente solo se quella camera è selezionata dal visore.

## Visore

- Il visore entra in Agora come host **senza** pubblicare video né microfono (non audience: in Live Broadcast l’audience non può inviare comandi data stream).
- Può mostrare più camere insieme; solo le camere selezionate nella griglia trasmettono.
- Per ogni camera può vedere la batteria, flash, lente (frontale/posteriore) e ascoltare l’audio ambientale.
- Flash posteriore: LED. Flash frontale: schermo della CAM bianco a luminosità massima.
- Il pulsante «Parla» attiva temporaneamente il microfono del visore verso le telecamere selezionate.

## Comandi remoti

- I comandi (selezione CAM, flash, audio, lente) viaggiano sul canale Agora via data stream, cifrati insieme a video e audio (AES-256-GCM2, chiave di casa).
- Le telecamere eseguono solo comandi indirizzati al proprio UID.

## Permessi

- All’avvio l’app chiede fotocamera, microfono e notifiche.
- Non usa Bluetooth né «dispositivi vicini».

## Limiti di piattaforma

- Android richiede una foreground service notification per cattura continua in background.
- Un avviso persistente deve comunicare chiaramente quando il video è in trasmissione.
