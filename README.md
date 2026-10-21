# Accettazione S.D.Garage

App per l'accettazione veicoli: dati auto e cliente, foto guidate, danni sul disegno dell'auto, controlli, firma del cliente, stampa/PDF.

- Online: https://accettazione.sdautogroup.it (progetto Vercel `accettazione`, team SD GARAGE)
- Pagina unica statica: `index.html`
- Dati: Supabase `sd-officina`, tabelle `acc_users` e `acc_schede`, funzioni RPC `acc_*` protette da PIN
- Foto: salvate SOLO sul tablet (IndexedDB del browser), mai su Supabase; restano collegate alla scheda su quel dispositivo (il tablet in accettazione è uno solo e ha il backup giornaliero). Il bucket `accettazione` e la edge function `acc-foto` restano ma non vengono più usati per le nuove foto.
- Titolare: entra con lo stesso PIN del timbratore; operatori scelgono il PIN al primo accesso
- Pubblicazione: ogni push su `main` viene pubblicato automaticamente da Vercel
- Tempi di lavoro (solo titolare): nella scheda, sotto lo storico, i tempi delle timbrature del timbratore per la stessa targa dalla data dell'accettazione (funzione `acc_ore`, migration `20261021_acc_ore.sql` nel repo `timbratore`). Timer rosso oltre l'obiettivo (Tagliando 2 h).
