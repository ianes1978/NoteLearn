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
    final anchors = anchorNotes(clef).toSet();
    const anchorColor = Color(0xFFE65100);
    // Un solo pentagramma con tutte le note in fila ed etichette sotto.
    final painter = AllNotesStaffPainter(
      clef: clef,
      notes: notes,
      notation: notation,
      lineColor: theme.colorScheme.onSurface,
      noteColor: theme.colorScheme.primary,
      labelColor: theme.colorScheme.onSurface,
      lineSpacing: 16,
      anchors: anchors,
      anchorColor: anchorColor,
    );
    final size = painter.preferredSize;
    final anchorText = clef == Clef.treble
        ? 'Note guida (in arancione): Do centrale e Sol — la chiave di violino '
            '«gira» proprio sul Sol (2ª riga).'
        : 'Note guida (in arancione): Do centrale e Fa — la chiave di basso '
            'segna il Fa fra i suoi due punti (4ª riga).';
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
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 3, right: 6),
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: anchorColor,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Text(
                anchorText,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _MnemonicsCard(clef: clef, notation: notation),
      ],
    );
  }
}

/// Regole mnemoniche per ricordare le note su righe e spazi del pentagramma.
class _MnemonicsCard extends StatelessWidget {
  final Clef clef;
  final Notation notation;

  const _MnemonicsCard({required this.clef, required this.notation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTreble = clef == Clef.treble;

    // Sequenze (dal basso verso l'alto) in solfège e in lettere, con il
    // classico acronimo inglese usato per memorizzarle.
    final linesSolfege =
        isTreble ? 'Mi · Sol · Si · Re · Fa' : 'Sol · Si · Re · Fa · La';
    final linesLetters = isTreble ? 'E · G · B · D · F' : 'G · B · D · F · A';
    final linesPhrase = isTreble
        ? 'Every Good Boy Does Fine'
        : 'Good Boys Do Fine Always';
    final linesItalian = isTreble
        ? 'Mi Sono Sicuro, Resto Fermo'
        : 'Sole Sincero Regala Favole Lassù';

    final spacesSolfege =
        isTreble ? 'Fa · La · Do · Mi' : 'La · Do · Mi · Sol';
    final spacesLetters = isTreble ? 'F · A · C · E' : 'A · C · E · G';
    // In chiave di violino gli spazi formano la parola "FACE", quindi non
    // serve una frase; in chiave di basso si usa "All Cows Eat Grass".
    final String? spacesPhrase = isTreble ? null : 'All Cows Eat Grass';
    final spacesItalian =
        isTreble ? 'Fa La Dolce Mimosa' : 'La Dolce Mia Sorpresa';
    final spacesExtra = isTreble
        ? 'Le lettere F-A-C-E formano la parola «FACE» (faccia)!'
        : null;

    final useLetters = notation == Notation.letters;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💡', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(
                'Come ricordarle',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _MnemonicRow(
            group: 'Note sulle RIGHE',
            primary: useLetters ? linesLetters : linesSolfege,
            secondary: useLetters ? linesSolfege : linesLetters,
            phrase: linesPhrase,
            italian: linesItalian,
          ),
          const SizedBox(height: 10),
          _MnemonicRow(
            group: 'Note negli SPAZI',
            primary: useLetters ? spacesLetters : spacesSolfege,
            secondary: useLetters ? spacesSolfege : spacesLetters,
            phrase: spacesPhrase,
            italian: spacesItalian,
            extra: spacesExtra,
          ),
        ],
      ),
    );
  }
}

class _MnemonicRow extends StatelessWidget {
  final String group;
  final String primary;
  final String secondary;
  final String? phrase;
  final String? italian;
  final String? extra;

  const _MnemonicRow({
    required this.group,
    required this.primary,
    required this.secondary,
    this.phrase,
    this.italian,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$group (dal basso in alto)',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          primary,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          secondary,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        if (italian != null)
          Text(
            'Filastrocca: «$italian»',
            style: theme.textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        if (phrase != null)
          Text(
            'In inglese: «$phrase»',
            style: theme.textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        if (extra != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              extra!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }
}
