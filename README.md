# Accettazione S.D.Garage

App per l'accettazione veicoli: dati auto e cliente, foto guidate, danni sul disegno dell'auto, controlli, firma del cliente, stampa/PDF.

- Online: https://accettazione.sdautogroup.it (progetto Vercel `accettazione`, team SD GARAGE)
- Pagina unica statica: `index.html`
- Dati: Supabase `sd-officina`, tabelle `acc_users` e `acc_schede`, funzioni RPC `acc_*` protette da PIN
- Foto: bucket privato `accettazione`, gestito dalla edge function `acc-foto`
- Titolare: entra con lo stesso PIN del timbratore; operatori scelgono il PIN al primo accesso
