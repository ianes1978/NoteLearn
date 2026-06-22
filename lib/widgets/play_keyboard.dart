import 'package:flutter/material.dart';
import '../models/music_note.dart';

/// Tastiera di pianoforte (un'ottava, tasti bianchi Do…Si) per suonare
/// liberamente. Chiama [onKey] con l'indice di lettera (0=Do … 6=Si).
/// I tasti neri sono decorativi (l'app usa solo note naturali).
class PlayKeyboard extends StatefulWidget {
  final Notation notation;
  final void Function(int letterIndex) onKey;

  /// Tasti da evidenziare (es. la nota da suonare ora).
  final Set<int> highlight;

  const PlayKeyboard({
    super.key,
    required this.notation,
    required this.onKey,
    this.highlight = const {},
  });

  @override
  State<PlayKeyboard> createState() => _PlayKeyboardState();
}

class _PlayKeyboardState extends State<PlayKeyboard> {
  int? _pressed;

  void _press(int i) {
    widget.onKey(i);
    setState(() => _pressed = i);
    Future.delayed(const Duration(milliseconds: 140), () {
      if (mounted && _pressed == i) setState(() => _pressed = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelNotation = widget.notation == Notation.both
        ? Notation.solfege
        : widget.notation;
    final labels =
        List.generate(7, (i) => MusicNote(i, 4).name(labelNotation));
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
                if (_pressed == i) {
                  bg = theme.colorScheme.primary;
                  fg = theme.colorScheme.onPrimary;
                } else if (widget.highlight.contains(i)) {
                  bg = theme.colorScheme.primaryContainer;
                  fg = theme.colorScheme.onPrimaryContainer;
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
                        onTap: () => _press(i),
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
