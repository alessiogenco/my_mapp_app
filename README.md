# My Locals

Una mappa personale di locali consigliati, con filtri, dettagli del posto e una
lista privata **Want to go** salvata sul dispositivo.

## Come avviare l'app

Apri PowerShell nella cartella del progetto e usa uno di questi comandi:

```powershell
.\scripts\run_app.ps1 -Device chrome
```

Oppure, se il browser non viene aperto automaticamente:

```powershell
.\scripts\run_app.ps1 -Device web-server
```

Nel secondo caso apri nel browser l'indirizzo `http://localhost:7357` mostrato
da Flutter.

Al primo avvio lo script chiede il **public token** Mapbox (quello che inizia
con `pk.`) e lo salva soltanto nel file locale `mapbox.env.json`. Il file è
escluso da Git e non deve essere condiviso.

## Mappa

L'app usa Mapbox Standard su browser e Android. I dati dei locali restano in
`assets/data/places.json`; filtri, schede dei locali e Want to go non dipendono
dal fornitore della mappa.

La versione desktop Windows non è supportata dal renderer Mapbox. Per lo
sviluppo usa Chrome, Edge oppure un dispositivo/emulatore Android.

## Dati

- Locali pubblicati nella mappa: `assets/data/places.json`
- Bozza/modello per inserire un locale: `assets/data/place_template.json`
- Want to go: dati privati nel browser/dispositivo, non nel repository Git
