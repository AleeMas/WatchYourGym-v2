# WatchYourGym

App iOS (SwiftUI, iOS 17+) per creare le proprie schede di allenamento ed eseguirle con timer di recupero.

## Struttura del progetto

```
WatchYourGym/
├── WatchYourGymApp.swift        # Entry point: crea gli store e li inietta nell'ambiente
├── Models/                      # Dati puri (struct Codable)
│   ├── Exercise.swift           # Un esercizio (nome, muscolo, kg, set, reps, rest, note)
│   ├── Workout.swift            # Una scheda o circuito con la lista di esercizi
│   └── UserProfile.swift        # Dati del profilo utente
├── Stores/                      # Classi: fonte unica di verità + persistenza JSON
│   ├── PersistenceManager.swift # Percorsi file, load/save JSON, migrazione dal vecchio formato
│   ├── WorkoutStore.swift       # CRUD delle schede (upsert/delete), salva automaticamente
│   ├── UserStore.swift          # Profilo utente e foto
│   ├── HistoryStore.swift       # Allenamenti completati
│   ├── WeightStore.swift        # Pesate, una per giorno
│   ├── SettingsStore.swift      # Preferenze (istanza condivisa)
│   └── ActiveSessionStore.swift # Allenamento in corso (istanza condivisa)
├── Services/                    # Effetti collaterali isolati dalle view
│   ├── SoundPlayer.swift        # Bip del timer con volume regolabile
│   ├── NotificationManager.swift# Notifica di fine recupero in background
│   └── LiveActivityManager.swift# Avvio/aggiornamento della Live Activity
├── Shared/                      # Da condividere con il target widget
│   └── WorkoutActivityAttributes.swift
├── Resources/Sounds/            # I tre bip in formato wav
├── Controllers/
│   └── WorkoutSessionController.swift  # Logica della sessione: set, timer, ripresa
└── Views/
    ├── ContentView.swift        # TabView principale
    ├── Workouts/                # Lista + editor unificato (creazione E modifica)
    ├── Session/                 # Schermata di allenamento con pagine e overlay recupero
    ├── Profile/                 # Profilo, storico, calendario/peso, impostazioni
    └── Components/              # Stili, picker durata riutilizzabile, helper Binding

WatchYourGymWidget/              # File pronti per il target Live Activity (vedi WIDGET_SETUP.md)
```

## Dati

I dati sono salvati in `Documents/WatchYourGym/` come JSON: `workouts.json`,
`profile.json`, `history.json`, `settings.json`, `weights.json` e
`activeSession.json` (allenamento in corso).
Al primo avvio, se presenti, i vecchi file di testo (`gymTabDataURL.txt`, `userData.txt`)
vengono migrati automaticamente e rinominati in `.bak`.

## Cronometro e storico

Aprendo una scheda si vedono gli esercizi ma il cronometro (in alto) parte solo
con **Start workout**. Durante l'allenamento il tasto Indietro è sostituito da
**Stop** (a sinistra, chiede conferma, non salva) e da **Finish** (a destra:
se mancano ancora serie chiede "Your workout isn't finished yet…", altrimenti
chiude subito; in entrambi i casi salva nello storico).
Al completamento la durata viene mostrata e registrata in `history.json`
(`Models/WorkoutRecord.swift`, `Stores/HistoryStore.swift`).

Nelle schede Tab ogni esercizio ha il proprio contatore di serie, che resta
anche cambiando pagina con lo swipe: tornando su un esercizio già completo si
vede "Completed" e, facendo una serie extra, "Current set: 6/5". Il
completamento automatico scatta all'ultima serie dell'ultimo esercizio, purché
tutti gli altri siano già completi.

Lo storico si apre da **Profile → History**: nome, tipo, data/ora e durata di
ogni allenamento completato; swipe verso sinistra per eliminare una voce.

## Suoni, notifiche e impostazioni

Profile › Settings regola i suoni del timer: interruttore generale, cursore del
volume con prova, avviso a 30 secondi dalla fine del recupero, notifica quando
l'app è in secondo piano e Live Activity.

I suoni (`Resources/Sounds/*.wav`, generati: tick del conto alla rovescia,
avviso a 30 secondi, fine recupero) sono riprodotti da `AVAudioPlayer`, non da
`AudioServicesPlaySystemSound`, perché i suoni di sistema ignorano qualsiasi
volume impostato dall'app. La sessione audio è `.playback` con `.mixWithOthers`,
quindi i bip si sentono anche con la suoneria in silenzioso e la musica continua.

Ad app chiusa il volume dell'app non si applica: l'avviso è una notifica locale
(`NotificationManager`), che usa il volume di sistema delle notifiche. In primo
piano il banner è soppresso, perché l'app suona già di suo.

## Ripresa dell'allenamento

Lo stato dell'allenamento in corso è salvato a ogni cambiamento in
`activeSession.json`: serie fatte per ogni esercizio, esercizio e round correnti,
istante di inizio e recupero in corso. Riaprendo l'app si torna direttamente
nella schermata dell'allenamento, sull'esercizio dove eri rimasto; il cronometro
conta il tempo reale, quindi include i minuti ad app chiusa. Una sessione più
vecchia di 12 ore viene scartata (`ActiveSession.maximumAge`).

## Dynamic Island

Il codice della Live Activity è pronto (`Shared/WorkoutActivityAttributes.swift`,
`Services/LiveActivityManager.swift`, `WatchYourGymWidget/`), ma serve un secondo
target Xcode: vedi **WIDGET_SETUP.md**. Senza quel target l'app funziona
normalmente, semplicemente non mostra nulla fuori dall'app.

## Calendario e peso

Profile › Calendar & weight: griglia mensile con un pallino per tipo di
allenamento svolto quel giorno (verde Tab, arancione Circuit) e un trattino
azzurro in basso a sinistra quando è stata registrata una pesata. Toccando un
giorno si vedono la pesata (modificabile) e gli allenamenti di quel giorno; sotto,
il grafico dell'andamento del peso su 3, 6 o 12 mesi (Swift Charts). Una pesata
per giorno, in kg.

## Import di una scheda da JSON

Dal pulsante `+` → **Import plan** si carica una scheda da un file `.json`
(una scheda per file). La schermata contiene anche il prompt da copiare e dare
a un'AI insieme alla foto della propria scheda cartacea.

Dopo l'import la scheda si apre nell'editor per la revisione: viene salvata solo
premendo Save. Gli identificativi (UUID) sono sempre generati dall'app, quindi
importare due volte lo stesso file crea due schede distinte e non ne sovrascrive
mai una esistente.

Schema atteso (in `Examples/` ci sono due file di prova):

```json
{
  "name": "Push Day",
  "type": "tab",
  "rounds": 1,
  "restBetweenExercises": 120,
  "exercises": [
    {
      "name": "Bench press",
      "muscle": "Chest",
      "weightKg": 60,
      "sets": 4,
      "reps": 10,
      "repsType": "reps",
      "restSeconds": 90,
      "notes": "",
      "superset": {
        "name": "Push up",
        "muscle": "Chest",
        "weightKg": 0,
        "reps": 15,
        "repsType": "reps",
        "notes": ""
      }
    }
  ]
}
```

`superset` è opzionale e solo per le schede Tab: il secondo esercizio si esegue
subito dopo il primo senza rest, e una serie comprende entrambi. Set e rest
sono quelli del primo esercizio; il secondo ha solo nome, muscolo, kg,
reps/secondi e note. Nell'editor si attiva con la spunta **Superset**.

Il parser è volutamente tollerante (`Models/WorkoutImport.swift`): accetta chiavi
in `snake_case` o con alias comuni, numeri scritti come stringhe (`"80 kg"`,
`"8-12"`, `"1:30"`), fence markdown ` ```json `, e l'eventuale wrapper
`{"workout": {...}}`. I campi mancanti diventano 0 o stringa vuota. Per i
superset accetta anche le forme "piatte" `"superset": "Push up"`,
`"superset": true` sul primo esercizio o `"supersetWithPrevious": true` sul
secondo, riconducendole tutte all'oggetto annidato.

## Requisiti

- Xcode 15 o superiore
- iOS 17.0+
