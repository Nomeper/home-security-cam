# Operazioni Device Owner — Recovery kiosk

## Policy scelta

- L'uscita dal kiosk è autorizzata solo dal proprietario della casa tramite comando backend.
- Non esiste PIN locale, gesto segreto o menu utente per uscire dal kiosk.
- Se il device è offline o non recuperabile, il fallback è il factory reset fisico secondo le istruzioni del produttore.

## Flusso di uscita online

1. Il proprietario autenticato seleziona la telecamera dal pannello amministrativo.
2. Il backend verifica proprietà della casa e del device.
3. Il backend crea un comando `exitKiosk` monouso, mirato al device e con scadenza breve.
4. L'app telecamera verifica di essere Device Owner, esegue l'uscita da Lock Task e invia conferma.
5. Il backend registra esito e timestamp; il device resta abbinato ma non rientra automaticamente in kiosk.

## Limiti di sicurezza

- Il comando non include segreti e non deve essere trasportato con Agora data stream.
- Nessun membro non proprietario può inviare o confermare il comando.
- L'app ignora comandi scaduti, duplicati, non mirati o ricevuti quando non è Device Owner.
- L'uscita dal kiosk non revoca automaticamente pairing o token; l'amministratore deve decidere se disassociare il device.

## Fallback offline

- Verificare la procedura di factory reset specifica del produttore prima della distribuzione.
- Il reset elimina app, pairing, dati locali e stato Device Owner.
- Dopo reset, il provisioning QR e pairing devono essere ripetuti.

## Test obbligatori

- Proprietario autorizzato: esce dal kiosk e riceve conferma.
- Membro non proprietario: riceve rifiuto.
- Comando scaduto o riutilizzato: viene ignorato.
- Device offline: nessuna uscita locale; recovery solo mediante reset fisico.
- Device non Device Owner: il comando viene rifiutato senza alterare la navigazione.
