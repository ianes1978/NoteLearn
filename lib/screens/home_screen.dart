import 'package:flutter/material.dart';
import '../models/music_note.dart';
import '../services/progress_store.dart';
import 'quiz_screen.dart';
import 'midi_game_screen.dart';
import 'help_screen.dart';

/// Schermata iniziale: scelta della chiave, della notazione e avvio del quiz.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum ClefChoice { treble, bass, both }

class _HomeScreenState extends State<HomeScreen> {
  ClefChoice _clefChoice = ClefChoice.treble;
  Notation _notation = Notation.solfege;
  GameMode _mode = GameMode.read;
  AnswerInput _answerInput = AnswerInput.buttons;
  bool _invertedChords = false;

  final ProgressStore _store = ProgressStore();
  Progress _progress = Progress();

  @override
  void initState() {
    super.initState();
    _refreshProgress();
  }

  Future<void> _refreshProgress() async {
    final p = await _store.load();
    if (!mounted) return;
    setState(() => _progress = p);
  }

  List<Clef> get _selectedClefs {
    switch (_clefChoice) {
      case ClefChoice.treble:
        return [Clef.treble];
      case ClefChoice.bass:
        return [Clef.bass];
      case ClefChoice.both:
        return [Clef.treble, Clef.bass];
    }
  }

  Future<void> _start() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _mode == GameMode.midi
            ? MidiGameScreen(notation: _notation)
            : QuizScreen(
                clefs: _selectedClefs,
                notation: _notation,
                mode: _mode,
                answerInput: _answerInput,
                invertedChords: _invertedChords,
              ),
      ),
    );
    // Al ritorno aggiorna record, streak e badge.
    _refreshProgress();
  }

  void _openHelp() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HelpScreen(
          clefs: _selectedClefs,
          notation: _notation,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.music_note,
                      size: 72, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    'NoteLearn',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Impara i nomi delle note sul pentagramma',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                  const SizedBox(height: 20),
                  _ProgressCard(progress: _progress),
                  const SizedBox(height: 28),
                  const _SectionTitle('Pentagramma'),
                  const SizedBox(height: 8),
                  SegmentedButton<ClefChoice>(
                    segments: const [
                      ButtonSegment(
                        value: ClefChoice.treble,
                        label: Text('Violino'),
                        icon: Icon(Icons.looks_one_outlined),
                      ),
                      ButtonSegment(
                        value: ClefChoice.bass,
                        label: Text('Basso'),
                        icon: Icon(Icons.looks_two_outlined),
                      ),
                      ButtonSegment(
                        value: ClefChoice.both,
                        label: Text('Entrambe'),
                        icon: Icon(Icons.all_inclusive),
                      ),
                    ],
                    selected: {_clefChoice},
                    onSelectionChanged: (s) =>
                        setState(() => _clefChoice = s.first),
                  ),
                  const SizedBox(height: 28),
                  const _SectionTitle('Modalità di gioco'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final m in GameMode.values)
                        ChoiceChip(
                          label: Text(m.label),
                          avatar: Icon(
                            m.icon,
                            size: 18,
                            color: _mode == m
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.primary,
                          ),
                          selected: _mode == m,
                          selectedColor: theme.colorScheme.primary,
                          labelStyle: TextStyle(
                            color: _mode == m
                                ? theme.colorScheme.onPrimary
                                : null,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) => setState(() => _mode = m),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _mode.description,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                  if (_mode == GameMode.chord)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _invertedChords,
                        onChanged: (v) =>
                            setState(() => _invertedChords = v),
                        title: const Text('Accordi rivoltati'),
                        subtitle: const Text(
                            'Includi i rivolti (es. Do/Mi): scegli le note dal basso'),
                      ),
                    ),
                  const SizedBox(height: 28),
                  const _SectionTitle('Notazione'),
                  const SizedBox(height: 8),
                  SegmentedButton<Notation>(
                    segments: const [
                      ButtonSegment(
                        value: Notation.solfege,
                        label: Text('Do Re Mi'),
                      ),
                      ButtonSegment(
                        value: Notation.letters,
                        label: Text('A B C'),
                      ),
                      ButtonSegment(
                        value: Notation.both,
                        label: Text('Entrambe'),
                      ),
                    ],
                    selected: {_notation},
                    onSelectionChanged: (s) =>
                        setState(() => _notation = s.first),
                  ),
                  const SizedBox(height: 28),
                  const _SectionTitle('Come rispondere'),
                  const SizedBox(height: 8),
                  SegmentedButton<AnswerInput>(
                    segments: const [
                      ButtonSegment(
                        value: AnswerInput.buttons,
                        label: Text('Pulsanti'),
                        icon: Icon(Icons.apps),
                      ),
                      ButtonSegment(
                        value: AnswerInput.piano,
                        label: Text('Piano'),
                        icon: Icon(Icons.piano),
                      ),
                    ],
                    selected: {_answerInput},
                    onSelectionChanged: (s) =>
                        setState(() => _answerInput = s.first),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _answerInput == AnswerInput.buttons
                        ? 'Rispondi toccando il nome della nota'
                        : 'Rispondi toccando il tasto sulla tastiera del piano',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                  const SizedBox(height: 28),
                  const _SectionTitle('Traguardi'),
                  const SizedBox(height: 8),
                  _BadgesWrap(unlocked: _progress.unlockedBadges),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _start,
                    icon: const Icon(Icons.play_arrow),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Inizia', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _openHelp,
                    icon: const Icon(Icons.help_outline),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Aiuto · Mostra tutte le note',
                          style: TextStyle(fontSize: 16)),
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

/// Mostra streak giornaliera, record di serie e miglior punteggio a tempo.
class _ProgressCard extends StatelessWidget {
  final Progress progress;
  const _ProgressCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(
            emoji: '🔥',
            value: '${progress.dailyStreak}',
            label: progress.dailyStreak == 1 ? 'giorno' : 'giorni',
          ),
          _Stat(
            emoji: '🏆',
            value: '${progress.bestStreak}',
            label: 'serie',
          ),
          _Stat(
            emoji: '⏱️',
            value: '${progress.bestTimedScore}',
            label: 'a tempo',
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  const _Stat(
      {required this.emoji, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 2),
        Text(value,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline)),
      ],
    );
  }
}

/// Bacheca dei traguardi: badge sbloccati a colori, gli altri in grigio.
class _BadgesWrap extends StatelessWidget {
  final Set<String> unlocked;
  const _BadgesWrap({required this.unlocked});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        for (final b in kAchievements)
          Tooltip(
            message: '${b.title}\n${b.description}',
            child: Opacity(
              opacity: unlocked.contains(b.id) ? 1 : 0.3,
              child: CircleAvatar(
                radius: 22,
                backgroundColor: unlocked.contains(b.id)
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                child: Text(b.emoji, style: const TextStyle(fontSize: 20)),
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            letterSpacing: 1.2,
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
    );
  }
}
