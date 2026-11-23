+# MyLocals — handoff per Claude
+
+Questo progetto e una app Flutter per salvare e scoprire locali su una mappa.
+L'utente comunica in italiano: rispondi in italiano, in modo chiaro e poco tecnico.
+
+## Punto di partenza
+
+- Repository: `https://github.com/alessiogenco/my_mapp_app.git`
+- Branch da usare: `codex/mapbox-standard-renderer` (non lavorare direttamente su `main` senza una richiesta esplicita)
+- Supabase: progetto `my-locals` (ref `opqrdzjlunjhcdjlectr`)
+- Google Cloud: progetto `my-map-app-495216`
+
+Per preparare un nuovo computer:
+
+```powershell
+git clone --branch codex/mapbox-standard-renderer https://github.com/alessiogenco/my_mapp_app.git
+cd my_mapp_app
+flutter pub get
+```
+
+Poi copiare nella cartella principale del progetto i due file privati che l'utente conserva nel backup OneDrive:
+
+- `mapbox.env.json`
+- `supabase.env.json`
+
+Non chiedere mai di incollare token, chiavi API o password nella chat e non includerli nei commit.
+
+## Avvio dell'app
+
+Per usare o aggiungere/modificare locali:
+
+```powershell
+.\scripts\start_place_writer.ps1
+```
+
+Lasciare aperta questa finestra mentre si aggiungono o modificano locali. In una seconda finestra:
+
+```powershell
+.\scripts\run_app.ps1 -Device chrome
+```
+
+Il writer non serve per la semplice consultazione dell'app.
+
+## Stato attuale dell'app
+
+- Inserimento locale: scelta “I'm here” (geolocalizzazione e lista entro circa 500 m) oppure “Not here” (nome/città o pin sulla mappa).
+- Il pin usa la stessa mappa Mapbox dell'app e cerca locali Google vicino al punto scelto.
+- La selezione Google Places completa automaticamente nome, indirizzo, Paese, valuta, link Maps, Place ID e coordinate.
+- Se le coordinate non sono disponibili, il flusso chiede solo l'indirizzo, non coordinate manuali.
+- `Want to go` usa lo stesso flusso di inserimento dei locali.
+- Scheda locale: badge in tempo reale “Aperto · chiude alle …” o “Chiuso · apre …”, allineato a destra della riga del nome.
+- Filtro mappa “Open now”: controlla i locali visibili e usa cache locale di 5 minuti.
+- Categorie includono `fish and chips`, con immagine dedicata; esistono anche `sushi` e `japanese` come categorie distinte.
+
+## Servizi esterni già configurati
+
+- Google Places è richiamato solo dal backend Supabase `place-search`, così la chiave non è nell'app.
+- La funzione Supabase gestisce ricerca, Place Details e stato di apertura.
+- Il fallback coordinate Foursquare OS Places gira su Cloud Run:
+  `https://my-locals-fsq-resolver-958648493238.europe-north1.run.app`
+- Le credenziali dei servizi sono già salvate come segreti remoti. Non sono necessarie per eseguire normalmente l'app su un nuovo PC.
+- Modifiche a `supabase/functions/place-search/index.ts` richiedono un deploy deliberato con `./scripts/deploy_place_search.ps1`; il comando richiederà un token Supabase personale temporaneo.
+
+## Dati e backup
+
+- Dati principali dei locali: `assets/data/places.json`.
+- I backup zip locali sono in `backups/` e non vanno aggiunti a Git.
+- La lista “Want to go” è salvata nel browser: importare il suo backup separato sul nuovo browser dopo l'avvio dell'app.
+- Il backup personale dell'utente è in OneDrive; GitHub è la fonte principale per codice e catalogo dei locali.
+
+## Controlli sicuri prima di pubblicare modifiche
+
+```powershell
+.\scripts\check_places.ps1
dart analyze
git diff --check
+```
+
+L'analisi completa può segnalare alcuni warning non bloccanti già noti (deprecazioni e un import inutilizzato); gli errori di compilazione non sono accettabili.
+
+## Regole per le modifiche
+
+- Prima leggere il codice esistente e individuare la causa con log o test: non far fare all'utente molti tentativi casuali.
+- Non modificare o aggiungere per errore `.codex_mail_ops/`, `supabase/.temp/`, `mapbox.env.json`, `supabase.env.json` o `backups/`.
+- Prima di un intervento che cambia dati o servizi remoti, spiegare in italiano cosa verrà modificato.
+- Dopo una modifica verificata: eseguire i controlli pertinenti, fare un commit chiaro e inviarlo al branch remoto. Non includere file estranei o segreti.
