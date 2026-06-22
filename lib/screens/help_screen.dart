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
              'Tutte le note sullo stesso pentagramma · scorri se non entrano',
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
    // Un solo pentagramma con tutte le note in fila ed etichette sotto.
    final painter = AllNotesStaffPainter(
      clef: clef,
      notes: notes,
      notation: notation,
      lineColor: theme.colorScheme.onSurface,
      noteColor: theme.colorScheme.primary,
      labelColor: theme.colorScheme.onSurface,
      lineSpacing: 16,
    );
    final size = painter.preferredSize;
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
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: CustomPaint(
              size: size,
              painter: painter,
            ),
          ),
        ),
      ],
    );
  }
}
