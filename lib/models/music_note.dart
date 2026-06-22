import 'dart:math';

/// Chiave musicale: violino (pentagramma superiore) o basso (pentagramma inferiore).
enum Clef {
  treble, // chiave di violino
  bass, // chiave di basso
}

extension ClefInfo on Clef {
  String get italianName =>
      this == Clef.treble ? 'Chiave di violino' : 'Chiave di basso';

  String get shortName =>
      this == Clef.treble ? 'Violino' : 'Basso';

  /// Glifo unicode della chiave musicale.
  String get glyph => this == Clef.treble ? '\u{1D11E}' : '\u{1D122}';
}

/// Modalità di visualizzazione del nome delle note.
enum Notation {
  solfege, // Do Re Mi Fa Sol La Si
  letters, // C D E F G A B
  both, // Do (C)
}

extension NotationInfo on Notation {
  String get label {
    switch (this) {
      case Notation.solfege:
        return 'Do Re Mi';
      case Notation.letters:
        return 'A B C';
      case Notation.both:
        return 'Entrambe';
    }
  }
}

/// Una nota musicale diatonica, definita da una lettera (0=Do/C ... 6=Si/B)
/// e da un'ottava (notazione scientifica, es. Do centrale = C4).
class MusicNote {
  /// 0=Do/C, 1=Re/D, 2=Mi/E, 3=Fa/F, 4=Sol/G, 5=La/A, 6=Si/B
  final int letterIndex;
  final int octave;

  /// Alterazione: 0 naturale, +1 diesis (♯), -1 bemolle (♭).
  final int accidental;

  const MusicNote(this.letterIndex, this.octave, [this.accidental = 0]);

  /// Indice diatonico assoluto (ogni passo = una lettera).
  int get diatonicIndex => octave * 7 + letterIndex;

  /// Semitoni dell'ottava per ogni nota naturale (Do Re Mi Fa Sol La Si).
  static const List<int> semitoneOffsets = [0, 2, 4, 5, 7, 9, 11];

  /// Classe di altezza cromatica (0=Do, 1=Do♯, … 11=Si).
  int get pitchClass => (semitoneOffsets[letterIndex] + accidental) % 12;

  /// Numero MIDI della nota (Do centrale C4 = 60).
  int get midiNumber =>
      (octave + 1) * 12 + semitoneOffsets[letterIndex] + accidental;

  /// Frequenza in Hz (temperamento equabile, La4 = 440 Hz).
  double get frequency => 440.0 * pow(2, (midiNumber - 69) / 12.0);

  /// Crea una nota dal numero MIDI usando la grafia con i diesis
  /// (i tasti neri diventano Do♯, Re♯, Fa♯, Sol♯, La♯). C4 (MIDI 60) = Do4.
  factory MusicNote.fromMidi(int midi) {
    // Per ogni classe di altezza: lettera naturale + alterazione.
    const pcToLetter = [0, 0, 1, 1, 2, 3, 3, 4, 4, 5, 5, 6];
    const pcToAcc = [0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0];
    final octave = (midi ~/ 12) - 1;
    final pc = midi % 12;
    return MusicNote(pcToLetter[pc], octave, pcToAcc[pc]);
  }

  static const List<String> _letters = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
  static const List<String> _solfege = [
    'Do',
    'Re',
    'Mi',
    'Fa',
    'Sol',
    'La',
    'Si'
  ];

  String get letterName => _letters[letterIndex];
  String get solfegeName => _solfege[letterIndex];

  /// Simbolo dell'alterazione (♯/♭/'').
  String get accidentalSymbol =>
      accidental > 0 ? '♯' : (accidental < 0 ? '♭' : '');

  /// Nome formattato secondo la notazione scelta (con l'eventuale alterazione).
  String name(Notation notation) {
    final s = accidentalSymbol;
    switch (notation) {
      case Notation.solfege:
        return '$solfegeName$s';
      case Notation.letters:
        return '$letterName$s';
      case Notation.both:
        return '$solfegeName$s ($letterName$s)';
    }
  }

  /// Indice diatonico della linea centrale (3ª linea) per ogni chiave.
  /// Violino: Si4 (B4). Basso: Re3 (D3).
  static int _middleLineIndex(Clef clef) =>
      clef == Clef.treble ? 4 * 7 + 6 : 3 * 7 + 1;

  /// Posizione sul pentagramma rispetto alla linea centrale.
  /// 0 = linea centrale, +1 = mezzo passo in su (uno spazio), ecc.
  /// Le 5 linee si trovano nelle posizioni -4, -2, 0, +2, +4.
  int staffPosition(Clef clef) => diatonicIndex - _middleLineIndex(clef);

  /// Numero di intervallo diatonico verso un'altra nota (unisono = 1,
  /// seconda = 2, terza = 3, …). Indipendente dalla direzione.
  int diatonicIntervalTo(MusicNote other) =>
      (other.diatonicIndex - diatonicIndex).abs() + 1;

  @override
  bool operator ==(Object other) =>
      other is MusicNote &&
      other.letterIndex == letterIndex &&
      other.octave == octave &&
      other.accidental == accidental;

  @override
  int get hashCode => Object.hash(letterIndex, octave, accidental);
}

/// Nomi italiani degli intervalli diatonici (indice = numero intervallo).
const List<String> _intervalNames = [
  '',
  'Unisono',
  'Seconda',
  'Terza',
  'Quarta',
  'Quinta',
  'Sesta',
  'Settima',
  'Ottava',
];

/// Nome italiano dell'intervallo dato il suo numero (1 = unisono … 8 = ottava).
String intervalName(int number) =>
    (number >= 0 && number < _intervalNames.length)
        ? _intervalNames[number]
        : '$numberª';

/// Triade diatonica (nota + terza + quinta) costruita sulle note naturali a
/// partire da [root], in ordine ascendente.
List<MusicNote> diatonicTriad(MusicNote root) {
  final d0 = root.diatonicIndex;
  final d2 = d0 + 2;
  final d4 = d0 + 4;
  return [
    root,
    MusicNote(d2 % 7, d2 ~/ 7),
    MusicNote(d4 % 7, d4 ~/ 7),
  ];
}

/// Classe di altezza (0..11) di ogni nota naturale (Do..Si).
const List<int> naturalPitchClass = [0, 2, 4, 5, 7, 9, 11];

/// Costruisce una triade reale (maggiore o minore) sulla nota naturale [root]
/// indicata, calcolando le alterazioni corrette di terza e quinta.
/// Es. Mi maggiore = Mi, Sol♯, Si; Do minore = Do, Mi♭, Sol.
List<MusicNote> chordTriad(int rootLetter, int rootOctave, bool major) {
  final rootMidi =
      (rootOctave + 1) * 12 + MusicNote.semitoneOffsets[rootLetter];

  MusicNote spell(int steps, int semis) {
    final li = rootLetter + steps;
    final letter = li % 7;
    final octave = rootOctave + (li ~/ 7);
    final naturalMidi =
        (octave + 1) * 12 + MusicNote.semitoneOffsets[letter];
    final acc = (rootMidi + semis) - naturalMidi;
    return MusicNote(letter, octave, acc);
  }

  return [
    MusicNote(rootLetter, rootOctave, 0),
    spell(2, major ? 4 : 3),
    spell(4, 7),
  ];
}

/// Qualità della triade diatonica costruita su [letterIndex] nella scala di Do
/// (Do/Fa/Sol maggiori, Si diminuito, le altre minori).
String triadQuality(int letterIndex) {
  switch (letterIndex) {
    case 0:
    case 3:
    case 4:
      return 'maggiore';
    case 6:
      return 'diminuito';
    default:
      return 'minore';
  }
}

/// Note "guida" di una chiave: riferimenti facili da cui ricavare le altre.
/// Violino: Do centrale e Sol (la chiave "gira" sul Sol). Basso: Do centrale
/// e Fa (la chiave segna il Fa fra i due punti).
List<MusicNote> anchorNotes(Clef clef) {
  if (clef == Clef.treble) {
    return const [MusicNote(0, 4), MusicNote(4, 4)]; // Do4, Sol4
  }
  return const [MusicNote(0, 4), MusicNote(3, 3)]; // Do4, Fa3
}

/// Genera l'elenco delle note per una chiave, entro un intervallo di posizioni
/// sul pentagramma (default: da un taglio addizionale sotto a uno sopra).
List<MusicNote> notesForClef(
  Clef clef, {
  int minPosition = -6,
  int maxPosition = 6,
}) {
  final middle = MusicNote._middleLineIndex(clef);
  final notes = <MusicNote>[];
  for (var pos = minPosition; pos <= maxPosition; pos++) {
    final di = middle + pos;
    notes.add(MusicNote(di % 7, di ~/ 7));
  }
  return notes;
}
