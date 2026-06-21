import 'dart:math';
import 'package:flutter/material.dart';
import '../models/music_note.dart';
import '../audio/note_player.dart';
import '../widgets/staff_painter.dart';
import 'help_screen.dart';

/// Modalità di gioco.
enum GameMode {
  read, // vedi la nota sul pentagramma e indovini il nome
  listen, // ascolti il suono e indovini la nota
}

/// Schermata del quiz: a seconda della modalità mostra la nota sul pentagramma
/// oppure la fa solo ascoltare, chiedendo di indovinarne il nome.
class QuizScreen extends StatefulWidget {
  final List<Clef> clefs;
  final Notation notation;
  final GameMode mode;

  const QuizScreen({
    super.key,
    required this.clefs,
    required this.notation,
    this.mode = GameMode.read,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final _random = Random();
  final NotePlayer _audio = NotePlayer();

  late Clef _currentClef;
  late MusicNote _currentNote;

  int _score = 0;
  int _total = 0;
  int _streak = 0;
  int _bestStreak = 0;
  int? _selectedLetter; // lettera scelta (0..6), null se nessuna
  bool _answered = false;
  bool _soundOn = true;

  bool get _isListen => widget.mode == GameMode.listen;

  @override
  void initState() {
    super.initState();
    _nextQuestion();
  }

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  void _playCurrentNote() {
    if (_soundOn) _audio.play(_currentNote.frequency);
  }

  void _nextQuestion() {
    final clef = widget.clefs[_random.nextInt(widget.clefs.length)];
    final notes = notesForClef(clef);
    setState(() {
      _currentClef = clef;
      _currentNote = notes[_random.nextInt(notes.length)];
      _selectedLetter = null;
      _answered = false;
    });
    // Suona la nuova nota (sia in modalità "leggi" che "ascolta").
    WidgetsBinding.instance.addPostFrameCallback((_) => _playCurrentNote());
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
        _bestStreak = max(_bestStreak, _streak);
      } else {
        _streak = 0;
      }
    });
  }

  /// Area centrale: in "Ascolta" mostra un grande pulsante finché non si
  /// risponde, poi rivela la nota sul pentagramma; in "Leggi" mostra sempre
  /// il pentagramma con la nota.
  Widget _buildStage(ThemeData theme, bool isCorrect) {
    final showStaff = !_isListen || _answered;
    if (showStaff) {
      return CustomPaint(
        painter: StaffPainter(
          clef: _currentClef,
          note: _currentNote,
          lineColor: theme.colorScheme.onSurface,
          noteColor: _answered
              ? (isCorrect ? Colors.green : Colors.red)
              : theme.colorScheme.primary,
        ),
        child: const SizedBox.expand(),
      );
    }
    // Modalità ascolto, prima della risposta: grande pulsante "Ascolta".
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filled(
            iconSize: 72,
            onPressed: _playCurrentNote,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCorrect =
        _answered && _selectedLetter == _currentNote.letterIndex;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isListen ? 'Ascolta' : _currentClef.shortName),
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
                '$_score / $_total',
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
                  _StreakBar(streak: _streak, bestStreak: _bestStreak),
                  const SizedBox(height: 12),
                  // Area centrale: pentagramma o pulsante d'ascolto.
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
                  // Pulsante per (ri)ascoltare la nota.
                  TextButton.icon(
                    onPressed: _playCurrentNote,
                    icon: const Icon(Icons.replay),
                    label: const Text('Riascolta'),
                  ),
                  const SizedBox(height: 4),
                  // Riscontro dopo la risposta.
                  SizedBox(
                    height: 48,
                    child: _answered
                        ? _Feedback(
                            correct: isCorrect,
                            note: _currentNote,
                            notation: widget.notation,
                          )
                        : Text(
                            'Che nota è?',
                            style: theme.textTheme.titleLarge,
                          ),
                  ),
                  const SizedBox(height: 8),
                  // Pulsanti risposta (7 nomi).
                  Expanded(
                    flex: 3,
                    child: _AnswerGrid(
                      notation: widget.notation,
                      answered: _answered,
                      correctLetter: _currentNote.letterIndex,
                      selectedLetter: _selectedLetter,
                      onAnswer: _answer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _answered ? _nextQuestion : null,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Avanti'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StreakBar extends StatelessWidget {
  final int streak;
  final int bestStreak;
  const _StreakBar({required this.streak, required this.bestStreak});

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
        Text('Record: $bestStreak',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline)),
      ],
    );
  }
}

class _Feedback extends StatelessWidget {
  final bool correct;
  final MusicNote note;
  final Notation notation;
  const _Feedback({
    required this.correct,
    required this.note,
    required this.notation,
  });

  @override
  Widget build(BuildContext context) {
    final color = correct ? Colors.green : Colors.red;
    final text = correct
        ? 'Esatto! ${note.name(notation)}'
        : 'È ${note.name(notation)}';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(correct ? Icons.check_circle : Icons.cancel, color: color),
        const SizedBox(width: 8),
        Text(
          text,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _AnswerGrid extends StatelessWidget {
  final Notation notation;
  final bool answered;
  final int correctLetter;
  final int? selectedLetter;
  final void Function(int) onAnswer;

  const _AnswerGrid({
    required this.notation,
    required this.answered,
    required this.correctLetter,
    required this.selectedLetter,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // I 7 nomi nella notazione scelta (riusa MusicNote per il formato).
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
        if (answered) {
          if (i == correctLetter) {
            bg = Colors.green;
            fg = Colors.white;
          } else if (i == selectedLetter) {
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
          onPressed: answered ? null : () => onAnswer(i),
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
