# NoteLearn 🎵

App Flutter per **imparare il nome delle note sul pentagramma** in chiave di
violino (pentagramma superiore) e in chiave di basso (pentagramma inferiore).

I nomi delle note possono essere mostrati in due notazioni:

- **Solfège**: Do Re Mi Fa Sol La Si
- **Lettere**: C D E F G A B
- oppure **entrambe** insieme (es. `Do (C)`)

## Funzionalità

- 🎼 Pentagramma disegnato a schermo con la nota da indovinare (inclusi i tagli
  addizionali sopra e sotto le 5 linee).
- 🎹 Scelta della chiave: **Violino**, **Basso** o **Entrambe** (si alternano).
- 🔤 Scelta della notazione: **Do Re Mi**, **A B C** o **Entrambe**.
- ✅ Quiz a risposta multipla con riscontro immediato (verde/rosso).
- 🔊 **Suono della nota**: ogni nota mostrata viene anche suonata (tono
  sintetizzato, nessun file audio), con pulsante **Riascolta** e interruttore
  audio on/off.
- 🎧 Due **modalità di gioco**:
  - **Leggi**: vedi la nota sul pentagramma (e la senti) e indovini il nome;
  - **Ascolta**: senti solo il suono e indovini la nota; dopo la risposta
    viene rivelata la posizione sul pentagramma.
- 🔥 Conteggio punteggio, serie corrente e record di serie consecutive.
- ❓ Schermata **Aiuto** che mostra **tutte le note** sul pentagramma con il
  nome (commutabile tra lettere A B C e solfège Do Re Mi), per ogni chiave.
- 🌗 Tema chiaro/scuro automatico (Material 3).

## Versione online (GitHub Pages)

A ogni push del branch, la versione Web viene pubblicata automaticamente su
GitHub Pages dal workflow `.github/workflows/pages.yml`:

👉 **https://ianes1978.github.io/NoteLearn/**

> Su repository **privati** GitHub Pages richiede un piano a pagamento
> (Pro/Team/Enterprise). Su repository pubblici funziona con il piano gratuito.

## Come eseguire
Servono [Flutter](https://docs.flutter.dev/get-started/install) (SDK 3.x) e un
dispositivo/emulatore o un browser.

```bash
# 1. Genera le cartelle di piattaforma (android, ios, web, ...)
flutter create .

# 2. Scarica le dipendenze
flutter pub get

# 3. Avvia l'app
flutter run            # su dispositivo/emulatore
# oppure
flutter run -d chrome  # nel browser
```

> Nota: in questo repository sono inclusi solo il codice sorgente (`lib/`),
> i test (`test/`) e `pubspec.yaml`. Il comando `flutter create .` aggiunge le
> cartelle specifiche di piattaforma senza toccare il codice esistente.

## Test

```bash
flutter test
```

## Struttura del progetto

```
lib/
├── main.dart                  # Avvio app e tema
├── audio/
│   └── note_player.dart       # Sintetizza e riproduce il suono delle note
├── models/
│   └── music_note.dart        # Modello nota, chiavi, notazioni, MIDI/frequenza
├── widgets/
│   └── staff_painter.dart     # Disegno del pentagramma, chiave, nota e tagli
└── screens/
    ├── home_screen.dart       # Scelta chiave/notazione e avvio
    ├── quiz_screen.dart       # Quiz con punteggio e serie
    └── help_screen.dart       # Aiuto: tutte le note con il nome
```

## Come funziona la posizione delle note

Ogni nota ha una *posizione sul pentagramma* relativa alla linea centrale:

- **Chiave di violino**: la linea centrale (3ª) è il **Si4 (B4)**.
- **Chiave di basso**: la linea centrale (3ª) è il **Re3 (D3)**.

Le 5 linee corrispondono alle posizioni `-4, -2, 0, +2, +4`; gli spazi a quelle
dispari. Le posizioni oltre `±4` generano automaticamente i tagli addizionali.
