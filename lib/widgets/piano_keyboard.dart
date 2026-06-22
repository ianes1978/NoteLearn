import 'package:flutter/material.dart';
import '../models/music_note.dart';

/// Tastiera di pianoforte di un'ottava (7 tasti bianchi + 5 neri).
/// Chiama [onKey] con la classe di altezza (0=Do, 1=Do♯, … 11=Si).
/// Gli insiemi [green]/[red]/[selected] evidenziano i tasti (per classe di
/// altezza); [enabled] abilita o disabilita il tocco.
class PianoKeyboard extends StatefulWidget {
  final Notation notation;
  final void Function(int pitchClass) onKey;
  final Set<int> green;
  final Set<int> red;
  final Set<int> selected;
  final bool enabled;

  /// Numero di ottave mostrate (1 = una sola, 2 = tastiera grande).
  final int octaves;

  const PianoKeyboard({
    super.key,
    required this.notation,
    required this.onKey,
    this.green = const {},
    this.red = const {},
    this.selected = const {},
    this.enabled = true,
    this.octaves = 1,
  });

  @override
  State<PianoKeyboard> createState() => _PianoKeyboardState();
}

class _PianoKeyboardState extends State<PianoKeyboard> {
  int? _pressed; // classe di altezza premuta (flash)

  // Tasti bianchi: lettere 0..6 -> classi di altezza.
  static const _whitePc = naturalPitchClass; // [0,2,4,5,7,9,11]
  // Tasti neri: dopo i tasti bianchi 0,1,3,4,5 (Do,Re,Fa,Sol,La).
  static const _blackAfter = [0, 1, 3, 4, 5];
  static const _blackPc = [1, 3, 6, 8, 10];

  void _press(int pc) {
    widget.onKey(pc);
    setState(() => _pressed = pc);
    Future.delayed(const Duration(milliseconds: 140), () {
      if (mounted && _pressed == pc) setState(() => _pressed = null);
    });
  }

  Color? _bg(int pc, ThemeData theme) {
    if (_pressed == pc) return theme.colorScheme.primary;
    if (widget.green.contains(pc)) return Colors.green;
    if (widget.red.contains(pc)) return Colors.red;
    if (widget.selected.contains(pc)) return theme.colorScheme.tertiary;
    return null; // colore di base
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelNotation = widget.notation == Notation.both
        ? Notation.solfege
        : widget.notation;
    final whiteLabels =
        List.generate(7, (i) => MusicNote(i, 4).name(labelNotation));

    final octaves = widget.octaves;
    final whiteCount = 7 * octaves;

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
                final pc = _whitePc[i % 7];
                final keyColor = _bg(pc, theme);
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
                        onTap: widget.enabled ? () => _press(pc) : null,
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
            for (var o = 0; o < octaves; o++)
              for (var k = 0; k < _blackAfter.length; k++)
                Positioned(
                  left: (o * 7 + _blackAfter[k] + 1) * whiteW - blackW / 2,
                  top: 0,
                  width: blackW,
                  height: blackH,
                  child: Material(
                    color: _bg(_blackPc[k], theme) ?? Colors.black87,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(5)),
                    child: InkWell(
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(5)),
                      onTap:
                          widget.enabled ? () => _press(_blackPc[k]) : null,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}
