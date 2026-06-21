import 'package:flutter/material.dart';
import '../models/music_note.dart';
import '../widgets/staff_painter.dart';

/// Schermata di aiuto: mostra tutte le note sul pentagramma (per ogni chiave
/// scelta) con il relativo nome, in lettere o in solfège.
class HelpScreen extends StatefulWidget {
  final List<Clef> clefs;
  final Notation notation;

  const HelpScreen({
    super.key,
    required this.clefs,
    required this.notation,
  });

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  late Notation _notation;

  @override
  void initState() {
    super.initState();
    // In aiuto mostriamo un nome alla volta: se era "Entrambe" partiamo dal
    // solfège (resta comunque commutabile).
    _notation =
        widget.notation == Notation.both ? Notation.solfege : widget.notation;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aiuto · Tutte le note'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SegmentedButton<Notation>(
                segments: const [
                  ButtonSegment(
                    value: Notation.solfege,
                    label: Text('Do Re Mi'),
                  ),
                  ButtonSegment(
                    value: Notation.letters,
                    label: Text('A B C'),
                  ),
                ],
                selected: {_notation},
                onSelectionChanged: (s) => setState(() => _notation = s.first),
              ),
            ),
            Text(
              'Tocca per memorizzare la posizione di ogni nota',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final clef in widget.clefs) ...[
                    _ClefSection(clef: clef, notation: _notation),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClefSection extends StatelessWidget {
  final Clef clef;
  final Notation notation;

  const _ClefSection({required this.clef, required this.notation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notes = notesForClef(clef);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          clef.italianName,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final note in notes)
              _NoteCard(clef: clef, note: note, notation: notation),
          ],
        ),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Clef clef;
  final MusicNote note;
  final Notation notation;

  const _NoteCard({
    required this.clef,
    required this.note,
    required this.notation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 96,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          SizedBox(
            height: 120,
            width: double.infinity,
            child: CustomPaint(
              painter: StaffPainter(
                clef: clef,
                note: note,
                lineColor: theme.colorScheme.onSurface,
                noteColor: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            note.name(notation),
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
