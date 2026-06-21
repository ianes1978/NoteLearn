import 'package:flutter/material.dart';
import '../models/music_note.dart';
import 'quiz_screen.dart';

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

  void _start() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
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
                  const SizedBox(height: 32),
                  _SectionTitle('Pentagramma'),
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
                  const SizedBox(height: 8),
                  Text(
                    _clefChoice == ClefChoice.treble
                        ? 'Pentagramma superiore (chiave di violino)'
                        : _clefChoice == ClefChoice.bass
                            ? 'Pentagramma inferiore (chiave di basso)'
                            : 'Si alternano violino e basso',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                  const SizedBox(height: 28),
                  _SectionTitle('Notazione'),
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
                  const SizedBox(height: 40),
                  FilledButton.icon(
                    onPressed: _start,
                    icon: const Icon(Icons.play_arrow),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Inizia', style: TextStyle(fontSize: 18)),
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
