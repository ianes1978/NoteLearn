import 'package:flutter/material.dart';
import '../models/music_note.dart';

/// Disegna un pentagramma con la chiave indicata e (opzionalmente) una nota,
/// inclusi i tagli addizionali quando la nota esce dalle 5 linee.
class StaffPainter extends CustomPainter {
  final Clef clef;
  final MusicNote? note;
  final Color lineColor;
  final Color noteColor;

  StaffPainter({
    required this.clef,
    required this.note,
    required this.lineColor,
    required this.noteColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Spaziatura tra le linee: lascia spazio sopra/sotto per i tagli.
    final lineSpacing = size.height / 11;
    final centerY = size.height / 2;
    final halfStep = lineSpacing / 2;

    final left = size.width * 0.06;
    final right = size.width * 0.94;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    double yForPosition(int pos) => centerY - pos * halfStep;

    // Le 5 linee del pentagramma: posizioni -4, -2, 0, +2, +4.
    for (var pos = -4; pos <= 4; pos += 2) {
      final y = yForPosition(pos);
      canvas.drawLine(Offset(left, y), Offset(right, y), linePaint);
    }

    _drawClef(canvas, left, centerY, lineSpacing);

    final note = this.note;
    if (note != null) {
      _drawNote(canvas, note, size, lineSpacing, yForPosition, linePaint);
    }
  }

  void _drawClef(Canvas canvas, double left, double centerY, double lineSpacing) {
    // Il glifo della chiave viene dimensionato per coprire il pentagramma.
    final tp = TextPainter(
      text: TextSpan(
        text: clef.glyph,
        style: TextStyle(
          fontSize: lineSpacing * 7.5,
          color: lineColor,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final x = left + lineSpacing * 0.4;
    tp.paint(canvas, Offset(x, centerY - tp.height / 2));
  }

  void _drawNote(
    Canvas canvas,
    MusicNote note,
    Size size,
    double lineSpacing,
    double Function(int) yForPosition,
    Paint linePaint,
  ) {
    final pos = note.staffPosition(clef);
    final cx = size.width * 0.62;
    final cy = yForPosition(pos);

    // Tagli addizionali sopra (pos >= 6) e sotto (pos <= -6).
    final ledgerPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.6;
    final ledgerHalfWidth = lineSpacing * 0.85;

    if (pos >= 6) {
      final maxLine = pos.isEven ? pos : pos - 1;
      for (var l = 6; l <= maxLine; l += 2) {
        final y = yForPosition(l);
        canvas.drawLine(
          Offset(cx - ledgerHalfWidth, y),
          Offset(cx + ledgerHalfWidth, y),
          ledgerPaint,
        );
      }
    } else if (pos <= -6) {
      final minLine = pos.isEven ? pos : pos + 1;
      for (var l = -6; l >= minLine; l -= 2) {
        final y = yForPosition(l);
        canvas.drawLine(
          Offset(cx - ledgerHalfWidth, y),
          Offset(cx + ledgerHalfWidth, y),
          ledgerPaint,
        );
      }
    }

    // Testa della nota (ovale leggermente inclinato).
    final notePaint = Paint()
      ..color = noteColor
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(-0.32);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: lineSpacing * 1.35,
      height: lineSpacing * 1.02,
    );
    canvas.drawOval(rect, notePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant StaffPainter oldDelegate) {
    return oldDelegate.clef != clef ||
        oldDelegate.note != note ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.noteColor != noteColor;
  }
}
