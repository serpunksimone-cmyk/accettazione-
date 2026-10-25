# Accettazione S.D.Garage

App per l'accettazione veicoli: dati auto e cliente, foto guidate, danni sul disegno dell'auto, controlli, firma del cliente, stampa/PDF.

- Online: https://accettazione.sdautogroup.it (progetto Vercel `accettazione`, team SD GARAGE)
- Pagina unica statica: `index.html`
- Dati: Supabase `sd-officina`, tabelle `acc_users` e `acc_schede`, funzioni RPC `acc_*` protette da PIN
- Foto: salvate SOLO sul tablet (IndexedDB del browser), mai su Supabase; restano collegate alla scheda su quel dispositivo (il tablet in accettazione è uno solo e ha il backup giornaliero). Il bucket `accettazione` e la edge function `acc-foto` restano ma non vengono più usati per le nuove foto.
- Titolare: entra con lo stesso PIN del timbratore; operatori scelgono il PIN al primo accesso
- Pubblicazione: ogni push su `main` viene pubblicato automaticamente da Vercel
- Tempi di lavoro (solo titolare): nella scheda, sotto lo storico, i tempi delle timbrature del timbratore per la stessa targa dalla data dell'accettazione (funzione `acc_ore`, migration `20261021_acc_ore.sql` nel repo `timbratore`). Timer rosso oltre l'obiettivo (Tagliando 2 h).

- Ricambi (per chi cerca i ricambi): https://accettazione.sdautogroup.it/ricambi — pagina `ricambi/index.html`, stesso accesso e PIN dell'accettazione. Richieste ricambio per auto con stati (da cercare → trovato → ordinato → arrivato), codice/fornitore/prezzo, collegamenti di ricerca ai fornitori (configurabili, con `{q}`), storico dei codici già usati per lo stesso modello. Tabelle `ric_richieste`, `ric_fornitori`, funzioni `ric_*` (migration `supabase/migrations/20261025_ricambi.sql`).
- Lavori e tempi (passo 6 «Lavori»): si detta (microfono su tablet/telefono) o si scrive cosa c'è da fare, «Calcola tempi» chiama la edge function `stima-lavori` (AI Anthropic con chiave nel secret `ANTHROPIC_API_KEY` di Supabase; senza chiave usa solo il tempario). Gli operatori propongono, il titolare approva. I lavori approvati compaiono nel timbratore per targa, con il tempo massimo. Ogni tempo approvato aggiorna il tempario per quel motore (pulsante «Tempario» nell'elenco, solo titolare). Tempi fissi: Tagliando 2 h, Diagnosi 3 h. Tabelle `acc_lavori` e `tempario`, migration `20261025_*` nel repo `timbratore`.
- Link diretto a una scheda (passo Lavori): `https://accettazione.sdautogroup.it/#s=<id scheda>` (usato dalla modalità titolare del timbratore).
- I meccanici del timbratore non possono essere aggiunti come operatori.
