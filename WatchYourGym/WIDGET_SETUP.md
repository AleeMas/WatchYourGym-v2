# Dynamic Island (Live Activity) — fatto

Il target **WatchYourGymWidgetExtension** è stato creato e configurato: non c'è
più nulla da fare in Xcode, basta compilare ed eseguire lo schema **WatchYourGym**.

Questa pagina resta come promemoria di com'è messo insieme.

## Com'è configurato

Xcode 26 ha creato il target usando un **gruppo sincronizzato**
(`PBXFileSystemSynchronizedRootGroup`): ogni file dentro la cartella
`WatchYourGymWidget/` fa parte del target automaticamente, senza doverlo
trascinare né spuntare. Se aggiungi un file lì dentro, entra da solo nel widget.

Contenuto della cartella:

| File | Ruolo |
|---|---|
| `WorkoutLiveActivity.swift` | La Live Activity vera: schermata di blocco, Dynamic Island compatta, espansa e minimale |
| `WatchYourGymWidgetBundle.swift` | Punto di ingresso (`@main`), espone solo la Live Activity |
| `WatchYourGymWidget.swift` | Svuotato: era il widget di esempio con l'emoji |
| `WatchYourGymWidgetControl.swift` | Svuotato: era un toggle per Control Center, richiedeva iOS 18 |
| `WatchYourGymWidgetLiveActivity.swift` | Svuotato: era la Live Activity di esempio, con un suo tipo di attributi |

I tre file "svuotati" contengono solo un commento che spiega perché: puoi
cancellarli da Xcode quando vuoi, il progetto continua a compilare.

Due cose sistemate a mano nel progetto:

- `WatchYourGym/Shared/WorkoutActivityAttributes.swift` è ora membro di
  **entrambi** i target (app + estensione): è il tipo che descrive i dati della
  Live Activity, e deve essere lo stesso da tutte e due le parti.
- Il deployment target dell'estensione era **iOS 27.0** (Xcode lo imposta
  all'SDK più recente): portato a **17.0** come l'app, altrimenti la Live
  Activity non sarebbe apparsa su nessun iPhone non aggiornatissimo.

## Verificare

Lo schema da eseguire resta **WatchYourGym** (non quello del widget).
La chiave `NSSupportsLiveActivities` è già impostata nel progetto, non devi
aggiungerla.

Avvia un allenamento, premi **Start workout** e manda l'app in background:

- **iPhone 14 Pro e successivi**: il timer compare nella Dynamic Island.
  Tieni premuto per la vista espansa.
- **Altri iPhone** (e simulatore non-Pro): la Live Activity compare comunque
  nella schermata di blocco e nella Lock Screen; la Dynamic Island no, perché
  è l'hardware a non averla.

Durante il recupero l'icona diventa arancione e il conto alla rovescia sostituisce
il cronometro.

## Se qualcosa non torna

- **"Cannot find type 'WorkoutActivityAttributes'"** nel widget → il file
  `Shared/WorkoutActivityAttributes.swift` ha perso la spunta
  `WatchYourGymWidgetExtension` in File Inspector › Target Membership.
- **"Invalid redeclaration" o due `@main`** → è ricomparso uno dei file di
  esempio di Xcode: deve esserci un solo `@main`, in `WatchYourGymWidgetBundle.swift`.
- **Non compare nulla** → Impostazioni iOS › WatchYourGym › Live Activities
  deve essere attivo, e in Profile › Settings dell'app la voce
  "Lock Screen & Dynamic Island" deve essere accesa.
- **Se ricrei il target da zero**, Xcode riscrive i suoi file di esempio sopra
  i miei quando i nomi coincidono: è esattamente quello che è successo la prima
  volta con `WatchYourGymWidgetBundle.swift`.
