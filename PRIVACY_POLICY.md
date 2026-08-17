# Policy operativa e privacy

## Cattura della telecamera

- La telecamera pubblica esclusivamente il video.
- Il microfono della telecamera non viene attivato né pubblicato.
- Su Android, quando la telecamera passa in background o lo schermo si blocca, la sessione video continua con foreground service e notifica persistente.
- Su iOS, la pubblicazione e preview video si fermano in background e riprendono al ritorno nell'app: iOS non consente cattura video continua in background.

## Visore

- Il visore entra in Agora come audience e non pubblica tracce locali.
- Il push-to-talk non è disponibile finché il modello di autorizzazione non include esplicitamente un ruolo di pubblicazione temporanea.

## Comandi remoti

- Solo il proprietario della casa può inviare comandi remoti.
- I comandi sono mirati a un dispositivo abbinato, scadono e richiedono conferma di esecuzione.

## Limiti di piattaforma

- Android richiede una foreground service notification per cattura continua in background.
- iOS non supporta la cattura video continua in background; la configurazione finale deve rispettare le policy App Store.
- Un avviso persistente deve comunicare chiaramente quando il video è in trasmissione.
