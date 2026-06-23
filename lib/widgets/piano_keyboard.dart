import 'package:flutter/material.dart';
import '../models/music_note.dart';

/// Tastiera di pianoforte su una o più ottave (7 tasti bianchi + 5 neri per
/// ottava). Chiama [onKey] con il numero MIDI assoluto del tasto premuto.
/// Gli insiemi [green]/[red]/[selected] evidenziano i tasti (per numero MIDI);
/// [enabled] abilita o disabilita il tocco. [baseOctave] è l'ottava del Do più
/// a sinistra; [octaves] quante ottave mostrare.
class PianoKeyboard extends StatefulWidget {
  final Notation notation;
  final void Function(int midi) onKey;
  final Set<int> green;
  final Set<int> red;
  final Set<int> selected;
  final bool enabled;
  final int baseOctave;
  final int octaves;

  const PianoKeyboard({
    super.key,
    required this.notation,
    required this.onKey,
    this.green = const {},
    this.red = const {},
    this.selected = const {},
    this.enabled = true,
    this.baseOctave = 4,
    this.octaves = 1,
  });

  @override
  State<PianoKeyboard> createState() => _PianoKeyboardState();
}

class _PianoKeyboardState extends State<PianoKeyboard> {
  int? _pressed; // MIDI del tasto premuto (flash)

  // Tasti neri: dopo i tasti bianchi locali 0,1,3,4,5 (Do,Re,Fa,Sol,La).
  static const _blackAfter = [0, 1, 3, 4, 5];
  static const _blackPc = [1, 3, 6, 8, 10];

  int _whiteMidi(int i) {
    final octaveIndex = i ~/ 7;
    final letter = i % 7;
    return (widget.baseOctave + octaveIndex + 1) * 12 + naturalPitchClass[letter];
  }

  void _press(int midi) {
    widget.onKey(midi);
    setState(() => _pressed = midi);
    Future.delayed(const Duration(milliseconds: 140), () {
      if (mounted && _pressed == midi) setState(() => _pressed = null);
    });
  }

  Color? _bg(int midi, ThemeData theme) {
    if (_pressed == midi) return theme.colorScheme.primary;
    if (widget.green.contains(midi)) return Colors.green;
    if (widget.red.contains(midi)) return Colors.red;
    if (widget.selected.contains(midi)) return theme.colorScheme.tertiary;
    return null; // colore di base
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelNotation =
        widget.notation == Notation.both ? Notation.solfege : widget.notation;
    final whiteLabels =
        List.generate(7, (i) => MusicNote(i, 4).name(labelNotation));

    final whiteCount = 7 * widget.octaves;

    return LayoutBuilder(
      builder: (context, constraints) {
        final whiteW = constraints.maxWidth / whiteCount;
        final h = constraints.maxHeight;
        final blackW = whiteW * 0.62;
        final blackH = h * 0.6;

        return Stack(
          children: [
            // Tasti bianchi.
            Row(
              children: List.generate(whiteCount, (i) {
                final midi = _whiteMidi(i);
                final keyColor = _bg(midi, theme);
                final bg = keyColor ?? Colors.white;
                final colored = keyColor != null;
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
                        onTap: widget.enabled ? () => _press(midi) : null,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: theme.colorScheme.outlineVariant),
                            borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(8)),
                          ),
                          alignment: Alignment.bottomCenter,
                          padding: const EdgeInsets.only(bottom: 6),
                          child: FittedBox(
                            child: Text(
                              whiteLabels[i % 7],
                              style: TextStyle(
                                color:
                                    colored ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            // Tasti neri (sopra, selezionabili) per ogni ottava.
            for (var o = 0; o < widget.octaves; o++)
              for (var k = 0; k < _blackAfter.length; k++)
                Positioned(
                  left: (o * 7 + _blackAfter[k] + 1) * whiteW - blackW / 2,
                  top: 0,
                  width: blackW,
                  height: blackH,
                  child: Builder(builder: (context) {
                    final midi =
                        (widget.baseOctave + o + 1) * 12 + _blackPc[k];
                    return Material(
                      color: _bg(midi, theme) ?? Colors.black87,
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(5)),
                      child: InkWell(
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(5)),
                        onTap: widget.enabled ? () => _press(midi) : null,
                        child: const SizedBox.expand(),
                      ),
                    );
                  }),
                ),
          ],
        );
      },
    );
  }
}
