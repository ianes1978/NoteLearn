import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/music_note.dart';
import '../audio/note_player.dart';
import '../services/progress_store.dart';
import '../widgets/staff_painter.dart';
import 'help_screen.dart';

/// Modalità di gioco.
enum GameMode {
  read, // vedi la nota sul pentagramma e indovini il nome
  listen, // ascolti il suono e indovini la nota
  timed, // a tempo: quante note indovini in 60 secondi
  interval, // indovini l'intervallo fra due note
  chord, // costruisci l'accordo selezionando le tre note
}

extension GameModeInfo on GameMode {
  String get label {
    switch (this) {
      case GameMode.read:
        return 'Leggi';
      case GameMode.listen:
        return 'Ascolta';
      case GameMode.timed:
        return 'A tempo';
      case GameMode.interval:
        return 'Intervalli';
      case GameMode.chord:
        return 'Accordi';
    }
  }

  String get description {
    switch (this) {
      case GameMode.read:
        return 'Vedi la nota sul pentagramma (e la senti) e indovini il nome';
      case GameMode.listen:
        return 'Ascolti il suono e indovini la nota';
      case GameMode.timed:
        return 'Quante note indovini in 60 secondi?';
      case GameMode.interval:
        return 'Guardi due note e indovini l\'intervallo (seconda, terza…)';
      case GameMode.chord:
        return 'Costruisci l\'accordo selezionando le tre note';
    }
  }

  IconData get icon {
    switch (this) {
      case GameMode.read:
        return Icons.visibility_outlined;
      case GameMode.listen:
        return Icons.hearing;
      case GameMode.timed:
        return Icons.timer_outlined;
      case GameMode.interval:
        return Icons.swap_vert;
      case GameMode.chord:
        return Icons.library_music_outlined;
    }
  }
}

/// Durata della partita a tempo.
const int kTimedSeconds = 60;

/// Come si risponde: con i pulsanti dei nomi oppure toccando una tastiera.
enum AnswerInput { buttons, piano }

/// Schermata del quiz.
class QuizScreen extends StatefulWidget {
  final List<Clef> clefs;
  final Notation notation;
  final GameMode mode;
  final AnswerInput answerInput;

  /// In modalità accordi: include anche i rivolti (es. Do/Mi).
  final bool invertedChords;

  const QuizScreen({
    super.key,
    required this.clefs,
    required this.notation,
    this.mode = GameMode.read,
    this.answerInput = AnswerInput.buttons,
    this.invertedChords = false,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final _random = Random();
  final NotePlayer _audio = NotePlayer();
  final ProgressStore _store = ProgressStore();

  late Clef _currentClef;
  late MusicNote _currentNote;
  MusicNote? _currentNote2; // seconda nota (modalità intervalli)
  MusicNote? _prevNote; // per evitare la stessa nota due volte di fila

  // Modalità accordi.
  List<MusicNote> _chordNotes = []; // note dell'accordo, ordine ascendente
  List<int> _chordExpected = []; // lettere attese (ordine = dal basso)
  final List<int> _chordPicked = []; // lettere scelte dall'utente
  String _chordLabel = '';
  String _chordQuality = '';

  // Ripetizione spaziata: peso di estrazione per ogni nota (più alto = esce
  // più spesso). Le note sbagliate salgono di peso, quelle giuste scendono.
  final Map<MusicNote, double> _weights = {};

  int _score = 0;
  int _total = 0;
  int _streak = 0;
  int _record = 0; // record di serie (persistente)
  int? _selectedLetter; // risposta scelta nei modi "nota"
  int? _selectedInterval; // risposta scelta nel modo intervalli
  bool _answered = false;
  bool _soundOn = true;

  // Modalità a tempo.
  Timer? _timer;
  int _secondsLeft = kTimedSeconds;
  bool _timedFinished = false;

  bool get _isListen => widget.mode == GameMode.listen;
  bool get _isTimed => widget.mode == GameMode.timed;
  bool get _isInterval => widget.mode == GameMode.interval;
  bool get _isChord => widget.mode == GameMode.chord;

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _nextQuestion();
    if (_isTimed) _startTimer();
  }

  Future<void> _loadProgress() async {
    final p = await _store.registerPlayedToday();
    if (!mounted) return;
    setState(() => _record = p.bestStreak);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audio.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsLeft = kTimedSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        _finishTimed();
      }
    });
  }

  Future<void> _finishTimed() async {
    setState(() => _timedFinished = true);
    final newly = await _store.recordTimedScore(_score);
    if (!mounted) return;
    _showBadges(newly);
    _showTimedResult();
  }

  double _weightFor(MusicNote n) => _weights[n] ?? 1.0;

  /// Estrae una nota dando più probabilità a quelle sbagliate di recente.
  MusicNote _pickWeightedNote(List<MusicNote> notes) {
    var total = 0.0;
    for (final n in notes) {
      total += _weightFor(n);
    }
    var r = _random.nextDouble() * total;
    for (final n in notes) {
      r -= _weightFor(n);
      if (r <= 0) return n;
    }
    return notes.last;
  }

  void _nextQuestion() {
    final clef = widget.clefs[_random.nextInt(widget.clefs.length)];
    final notes = notesForClef(clef);

    if (_isChord) {
      _nextChord(clef);
      return;
    }

    if (_isInterval) {
      // Due note sulla stessa chiave, entro un'ottava (intervallo 1..8).
      final a = notes[_random.nextInt(notes.length)];
      final candidates = notes
          .where((n) => (n.diatonicIndex - a.diatonicIndex).abs() <= 7)
          .toList();
      final b = candidates[_random.nextInt(candidates.length)];
      setState(() {
        _currentClef = clef;
        _currentNote = a;
        _currentNote2 = b;
        _selectedInterval = null;
        _answered = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _playCurrent());
      return;
    }

    // Modi "nota": estrazione pesata, evitando la stessa nota due volte.
    var note = _pickWeightedNote(notes);
    if (notes.length > 1 && _prevNote != null) {
      var guard = 0;
      while (note == _prevNote && guard < 5) {
        note = _pickWeightedNote(notes);
        guard++;
      }
    }
    _prevNote = note;
    setState(() {
      _currentClef = clef;
      _currentNote = note;
      _currentNote2 = null;
      _selectedLetter = null;
      _answered = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _playCurrent());
  }

  /// Prepara un nuovo accordo (eventualmente rivoltato).
  void _nextChord(Clef clef) {
    final rootLetter = _random.nextInt(7);
    final rootOctave = clef == Clef.treble ? 4 : 3;
    final rootDi = rootOctave * 7 + rootLetter;
    final triadDi = [rootDi, rootDi + 2, rootDi + 4]; // posizione fondamentale

    final inversion = widget.invertedChords ? _random.nextInt(3) : 0;
    final List<int> orderedDi;
    switch (inversion) {
      case 1: // primo rivolto: basso = terza
        orderedDi = [triadDi[1], triadDi[2], triadDi[0] + 7];
        break;
      case 2: // secondo rivolto: basso = quinta
        orderedDi = [triadDi[2], triadDi[0] + 7, triadDi[1] + 7];
        break;
      default: // posizione fondamentale
        orderedDi = [triadDi[0], triadDi[1], triadDi[2]];
    }

    final chordNotes =
        orderedDi.map((di) => MusicNote(di % 7, di ~/ 7)).toList();
    final labelNotation =
        widget.notation == Notation.both ? Notation.solfege : widget.notation;
    final rootNote = MusicNote(rootLetter, rootOctave);
    final label = inversion == 0
        ? rootNote.name(labelNotation)
        : '${rootNote.name(labelNotation)} / '
            '${chordNotes.first.name(labelNotation)}';

    setState(() {
      _currentClef = clef;
      _chordNotes = chordNotes;
      _chordExpected = chordNotes.map((n) => n.letterIndex).toList();
      _chordPicked.clear();
      _chordLabel = label;
      _chordQuality = triadQuality(rootLetter);
      _selectedLetter = null;
      _answered = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _playCurrent());
  }

  /// Suona la nota corrente (o l'accordo/intervallo).
  void _playCurrent() {
    if (!_soundOn) return;
    if (_isChord) {
      for (var i = 0; i < _chordNotes.length; i++) {
        final f = _chordNotes[i].frequency;
        Future.delayed(Duration(milliseconds: i * 450),
            () => _soundOn ? _audio.play(f) : null);
      }
      return;
    }
    _audio.play(_currentNote.frequency);
    final n2 = _currentNote2;
    if (n2 != null) {
      Future.delayed(const Duration(milliseconds: 650),
          () => _soundOn ? _audio.play(n2.frequency) : null);
    }
  }

  void _adjustWeight(MusicNote note, bool correct) {
    final w = _weightFor(note);
    _weights[note] =
        correct ? max(0.4, w * 0.55) : min(6.0, max(w, 1.0) * 2.0);
  }

  Future<void> _registerCorrect() async {
    final newly = await _store.recordCorrect(_streak);
    if (!mounted) return;
    if (_streak > _record) setState(() => _record = _streak);
    _showBadges(newly);
  }

  void _answer(int letterIndex) {
    if (_answered) return;
    final correct = letterIndex == _currentNote.letterIndex;
    setState(() {
      _answered = true;
      _selectedLetter = letterIndex;
      _total++;
      if (correct) {
        _score++;
        _streak++;
      } else {
        _streak = 0;
      }
    });
    _adjustWeight(_currentNote, correct);
    if (correct) _registerCorrect();
    // Rinforzo multisensoriale.
    if (widget.answerInput == AnswerInput.piano && _soundOn) {
      // Suona il tasto premuto, poi (se sbagliato) la nota giusta.
      _audio.play(MusicNote(letterIndex, _currentNote.octave).frequency);
      if (!correct) {
        Future.delayed(
            const Duration(milliseconds: 700), () => _playCurrent());
      }
    } else {
      _playCurrent();
    }
    _scheduleAutoAdvance();
  }

  void _answerInterval(int number) {
    if (_answered) return;
    final actual = _currentNote.diatonicIntervalTo(_currentNote2!);
    final correct = number == actual;
    setState(() {
      _answered = true;
      _selectedInterval = number;
      _total++;
      if (correct) {
        _score++;
        _streak++;
      } else {
        _streak = 0;
      }
    });
    if (correct) _registerCorrect();
    _playCurrent();
    _scheduleAutoAdvance();
  }

  /// Selezione di una nota nell'accordo. Alla terza nota verifica da sola.
  void _pickChordNote(int letterIndex) {
    if (_answered) return;
    if (_chordPicked.contains(letterIndex)) return; // ignora i doppioni
    setState(() => _chordPicked.add(letterIndex));
    if (_soundOn) {
      _audio.play(MusicNote(letterIndex, _currentClef == Clef.treble ? 4 : 3)
          .frequency);
    }
    if (_chordPicked.length < 3) return;

    // Tre note scelte: valuta. Con i rivolti conta anche l'ordine (dal basso).
    final correct = widget.invertedChords
        ? _listEq(_chordPicked, _chordExpected)
        : _chordPicked.toSet().containsAll(_chordExpected.toSet()) &&
            _chordPicked.length == _chordExpected.length;
    setState(() {
      _answered = true;
      _total++;
      if (correct) {
        _score++;
        _streak++;
      } else {
        _streak = 0;
      }
    });
    if (correct) _registerCorrect();
    _playCurrent();
    _scheduleAutoAdvance();
  }

  static bool _listEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Avanza da solo alla domanda successiva: nessuna conferma da parte
  /// dell'utente (basta scegliere la risposta).
  void _scheduleAutoAdvance() {
    final ms = _isTimed ? 650 : 1200;
    Future.delayed(Duration(milliseconds: ms), () {
      if (mounted && _answered && !_timedFinished) _nextQuestion();
    });
  }

  void _showBadges(List<Achievement> badges) {
    if (badges.isEmpty || !mounted) return;
    for (final b in badges) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${b.emoji}  Nuovo traguardo: ${b.title}!'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showTimedResult() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Tempo scaduto! ⏱️'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$_score',
                style: Theme.of(ctx)
                    .textTheme
                    .displaySmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const Text('note indovinate'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Esci'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _restartTimed();
            },
            child: const Text('Rigioca'),
          ),
        ],
      ),
    );
  }

  void _restartTimed() {
    setState(() {
      _score = 0;
      _total = 0;
      _streak = 0;
      _timedFinished = false;
    });
    _nextQuestion();
    _startTimer();
  }

  // ---- UI ----

  /// Area centrale: pentagramma, accordo o pulsante d'ascolto.
  Widget _buildStage(ThemeData theme, bool isCorrect) {
    if (_isChord) {
      // Prima della risposta mostra il nome dell'accordo; dopo, lo rivela
      // sul pentagramma.
      if (_answered) {
        return CustomPaint(
          painter: StaffPainter(
            clef: _currentClef,
            note: null,
            chord: _chordNotes,
            lineColor: theme.colorScheme.onSurface,
            noteColor: isCorrect ? Colors.green : Colors.red,
          ),
          child: const SizedBox.expand(),
        );
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Costruisci l\'accordo',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline)),
            const SizedBox(height: 6),
            Text(
              _chordLabel,
              style: theme.textTheme.displaySmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text('($_chordQuality)',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline)),
            const SizedBox(height: 6),
            Text('Scegli 3 note · ${_chordPicked.length}/3',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.primary)),
          ],
        ),
      );
    }
    final showStaff = !_isListen || _answered;
    if (showStaff) {
      return CustomPaint(
        painter: StaffPainter(
          clef: _currentClef,
          note: _currentNote,
          note2: _isInterval ? _currentNote2 : null,
          lineColor: theme.colorScheme.onSurface,
          noteColor: _answered
              ? (isCorrect ? Colors.green : Colors.red)
              : theme.colorScheme.primary,
        ),
        child: const SizedBox.expand(),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filled(
            iconSize: 72,
            onPressed: _playCurrent,
            icon: const Icon(Icons.play_arrow),
          ),
          const SizedBox(height: 12),
          Text(
            'Tocca per ascoltare',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }

  /// Calcola gli insiemi di evidenziazione (verde/rosso/in corso) per i
  /// pulsanti o la tastiera, validi sia per i modi a nota singola sia accordi.
  _Highlights _noteHighlights() {
    if (_isChord) {
      if (_answered) {
        final exp = _chordExpected.toSet();
        return _Highlights(
          green: exp,
          red: _chordPicked.toSet().difference(exp),
          selected: const <int>{},
          enabled: false,
        );
      }
      return _Highlights(
        green: const <int>{},
        red: const <int>{},
        selected: _chordPicked.toSet(),
        enabled: true,
      );
    }
    if (_answered) {
      final correctL = _currentNote.letterIndex;
      return _Highlights(
        green: {correctL},
        red: (_selectedLetter != null && _selectedLetter != correctL)
            ? {_selectedLetter!}
            : const <int>{},
        selected: const <int>{},
        enabled: false,
      );
    }
    return const _Highlights(
        green: <int>{}, red: <int>{}, selected: <int>{}, enabled: true);
  }

  Widget _buildAnswerArea() {
    if (_isInterval) {
      return _IntervalGrid(
        answered: _answered,
        correct: _answered
            ? _currentNote.diatonicIntervalTo(_currentNote2!)
            : null,
        selected: _selectedInterval,
        onAnswer: _answerInterval,
      );
    }
    final h = _noteHighlights();
    final onTap = _isChord ? _pickChordNote : _answer;
    if (widget.answerInput == AnswerInput.piano) {
      return _PianoKeyboard(
        notation: widget.notation,
        highlights: h,
        onAnswer: onTap,
      );
    }
    return _AnswerGrid(
      notation: widget.notation,
      highlights: h,
      onAnswer: onTap,
    );
  }

  bool _answerWasCorrect() {
    if (_isChord) {
      return widget.invertedChords
          ? _listEq(_chordPicked, _chordExpected)
          : _chordPicked.toSet().containsAll(_chordExpected.toSet()) &&
              _chordPicked.length == _chordExpected.length;
    }
    if (_isInterval) {
      return _selectedInterval ==
          _currentNote.diatonicIntervalTo(_currentNote2!);
    }
    return _selectedLetter == _currentNote.letterIndex;
  }

  String _appBarTitle() {
    if (_isListen) return 'Ascolta';
    if (_isTimed) return 'A tempo';
    if (_isInterval) return 'Intervalli';
    if (_isChord) return 'Accordi';
    return _currentClef.shortName;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCorrect = _answered && _answerWasCorrect();

    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle()),
        actions: [
          IconButton(
            tooltip: _soundOn ? 'Disattiva audio' : 'Attiva audio',
            icon: Icon(_soundOn ? Icons.volume_up : Icons.volume_off),
            onPressed: () => setState(() => _soundOn = !_soundOn),
          ),
          IconButton(
            tooltip: 'Aiuto · Mostra tutte le note',
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => HelpScreen(
                    clefs: widget.clefs,
                    notation: widget.notation,
                  ),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                _isTimed ? '⏱️ $_secondsLeft' : '$_score / $_total',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _StreakBar(streak: _streak, record: _record),
                  const SizedBox(height: 12),
                  Expanded(
                    flex: 4,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 24),
                      child: _buildStage(theme, isCorrect),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _playCurrent,
                    icon: const Icon(Icons.replay),
                    label: const Text('Riascolta'),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 48,
                    child: _answered
                        ? _Feedback(
                            correct: isCorrect,
                            text: _feedbackText(isCorrect),
                          )
                        : Text(
                            _isChord
                                ? 'Tocca le 3 note'
                                : _isInterval
                                    ? 'Che intervallo è?'
                                    : 'Che nota è?',
                            style: theme.textTheme.titleLarge,
                          ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    flex: 3,
                    child: _buildAnswerArea(),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _feedbackText(bool correct) {
    if (_isChord) {
      final ln =
          widget.notation == Notation.both ? Notation.solfege : widget.notation;
      final names = _chordNotes.map((n) => n.name(ln)).join(' · ');
      return correct ? 'Esatto! $names' : '$_chordLabel = $names';
    }
    if (_isInterval) {
      final actual = _currentNote.diatonicIntervalTo(_currentNote2!);
      final name = intervalName(actual);
      return correct ? 'Esatto! $name' : 'È una $name';
    }
    final n = _currentNote.name(widget.notation);
    return correct ? 'Esatto! $n' : 'È $n';
  }
}

/// Insiemi di evidenziazione per i pulsanti/tasti risposta.
class _Highlights {
  final Set<int> green;
  final Set<int> red;
  final Set<int> selected;
  final bool enabled;
  const _Highlights({
    required this.green,
    required this.red,
    required this.selected,
    required this.enabled,
  });
}

class _StreakBar extends StatelessWidget {
  final int streak;
  final int record;
  const _StreakBar({required this.streak, required this.record});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.local_fire_department,
                color: Colors.orange, size: 20),
            const SizedBox(width: 4),
            Text('Serie: $streak', style: theme.textTheme.bodyMedium),
          ],
        ),
        Text('Record: ${max(record, streak)}',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline)),
      ],
    );
  }
}

class _Feedback extends StatelessWidget {
  final bool correct;
  final String text;
  const _Feedback({required this.correct, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = correct ? Colors.green : Colors.red;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(correct ? Icons.check_circle : Icons.cancel, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _AnswerGrid extends StatelessWidget {
  final Notation notation;
  final _Highlights highlights;
  final void Function(int) onAnswer;

  const _AnswerGrid({
    required this.notation,
    required this.highlights,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = List.generate(
      7,
      (i) => MusicNote(i, 4).name(notation),
    );

    return GridView.count(
      crossAxisCount: notation == Notation.both ? 2 : 4,
      childAspectRatio: notation == Notation.both ? 2.6 : 1.6,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(7, (i) {
        Color? bg;
        Color? fg;
        if (highlights.green.contains(i)) {
          bg = Colors.green;
          fg = Colors.white;
        } else if (highlights.red.contains(i)) {
          bg = Colors.red;
          fg = Colors.white;
        } else if (highlights.selected.contains(i)) {
          bg = theme.colorScheme.tertiaryContainer;
          fg = theme.colorScheme.onTertiaryContainer;
        }
        return FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: bg ?? theme.colorScheme.secondaryContainer,
            foregroundColor: fg ?? theme.colorScheme.onSecondaryContainer,
            padding: EdgeInsets.zero,
          ),
          onPressed: highlights.enabled ? () => onAnswer(i) : null,
          child: FittedBox(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                labels[i],
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Tastiera di pianoforte (un'ottava di tasti bianchi Do…Si) per rispondere
/// toccando il tasto corrispondente alla nota. I tasti neri sono decorativi
/// (l'app usa solo note naturali).
class _PianoKeyboard extends StatelessWidget {
  final Notation notation;
  final _Highlights highlights;
  final void Function(int) onAnswer;

  const _PianoKeyboard({
    required this.notation,
    required this.highlights,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Etichetta dei tasti bianchi (con "Entrambe" usiamo il solfège).
    final labelNotation =
        notation == Notation.both ? Notation.solfege : notation;
    final labels =
        List.generate(7, (i) => MusicNote(i, 4).name(labelNotation));

    // Tasti neri: dopo Do, Re, Fa, Sol, La (indici bianchi 0,1,3,4,5).
    const blackAfter = [0, 1, 3, 4, 5];

    return LayoutBuilder(
      builder: (context, constraints) {
        final whiteW = constraints.maxWidth / 7;
        final h = constraints.maxHeight;
        final blackW = whiteW * 0.58;
        final blackH = h * 0.6;

        return Stack(
          children: [
            Row(
              children: List.generate(7, (i) {
                Color bg = Colors.white;
                Color fg = Colors.black87;
                if (highlights.green.contains(i)) {
                  bg = Colors.green;
                  fg = Colors.white;
                } else if (highlights.red.contains(i)) {
                  bg = Colors.red;
                  fg = Colors.white;
                } else if (highlights.selected.contains(i)) {
                  bg = theme.colorScheme.tertiaryContainer;
                  fg = theme.colorScheme.onTertiaryContainer;
                }
                return SizedBox(
                  width: whiteW,
                  height: h,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Material(
                      color: bg,
                      elevation: 1,
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(8)),
                      child: InkWell(
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(8)),
                        onTap: highlights.enabled ? () => onAnswer(i) : null,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: theme.colorScheme.outlineVariant),
                            borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(8)),
                          ),
                          alignment: Alignment.bottomCenter,
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            labels[i],
                            style: TextStyle(
                              color: fg,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            // Tasti neri decorativi (non rispondono).
            for (final g in blackAfter)
              Positioned(
                left: (g + 1) * whiteW - blackW / 2,
                top: 0,
                width: blackW,
                height: blackH,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(5)),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _IntervalGrid extends StatelessWidget {
  final bool answered;
  final int? correct;
  final int? selected;
  final void Function(int) onAnswer;

  const _IntervalGrid({
    required this.answered,
    required this.correct,
    required this.selected,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Intervalli da unisono (1) a ottava (8).
    return GridView.count(
      crossAxisCount: 4,
      childAspectRatio: 1.6,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(8, (i) {
        final number = i + 1;
        Color? bg;
        Color? fg;
        if (answered) {
          if (number == correct) {
            bg = Colors.green;
            fg = Colors.white;
          } else if (number == selected) {
            bg = Colors.red;
            fg = Colors.white;
          }
        }
        return FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: bg ?? theme.colorScheme.secondaryContainer,
            foregroundColor: fg ?? theme.colorScheme.onSecondaryContainer,
            padding: EdgeInsets.zero,
          ),
          onPressed: answered ? null : () => onAnswer(number),
          child: FittedBox(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                intervalName(number),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        );
      }),
    );
  }
}
