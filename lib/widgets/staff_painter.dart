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

/// Disegna un UNICO pentagramma con TUTTE le note in fila, ciascuna con la sua
/// etichetta (Do Re Mi… oppure C D E…) scritta sotto. Usato nella schermata
/// Aiuto per vedere tutte le note sullo stesso pentagramma.
class AllNotesStaffPainter extends CustomPainter {
  final Clef clef;
  final List<MusicNote> notes;
  final Notation notation;
  final Color lineColor;
  final Color noteColor;
  final Color labelColor;
  final double lineSpacing;

  AllNotesStaffPainter({
    required this.clef,
    required this.notes,
    required this.notation,
    required this.lineColor,
    required this.noteColor,
    required this.labelColor,
    required this.lineSpacing,
  });

  /// Larghezza orizzontale occupata da ciascuna nota.
  double get noteSpacing => lineSpacing * 2.6;

  /// Larghezza riservata alla chiave a sinistra.
  double get clefWidth => lineSpacing * 4.0;

  /// Dimensioni totali necessarie per disegnare il pentagramma completo.
  Size get preferredSize {
    final width = clefWidth + notes.length * noteSpacing + lineSpacing;
    // Margine sopra (note + tagli alti) + 6 mezzi-passi sopra/sotto il centro
    // + spazio per le etichette in basso.
    final height = lineSpacing * 9.8;
    return Size(width, height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final halfStep = lineSpacing / 2;
    final topMargin = lineSpacing * 1.5;
    // Il centro del pentagramma (3ª linea); lascia spazio sopra per i tagli alti.
    final centerY = topMargin + 3 * lineSpacing;

    double yForPosition(int pos) => centerY - pos * halfStep;

    final left = clefWidth;
    final right = size.width - lineSpacing * 0.5;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    // Le 5 linee del pentagramma: posizioni -4, -2, 0, +2, +4.
    for (var pos = -4; pos <= 4; pos += 2) {
      final y = yForPosition(pos);
      canvas.drawLine(Offset(left, y), Offset(right, y), linePaint);
    }

    _drawClef(canvas, centerY);

    // Linea di base per le etichette: sotto la nota più bassa possibile.
    final labelTop = yForPosition(-6) + lineSpacing * 0.9;

    for (var i = 0; i < notes.length; i++) {
      final note = notes[i];
      final cx = clefWidth + noteSpacing * (i + 0.5);
      _drawNote(canvas, note, cx, yForPosition, linePaint);
      _drawLabel(canvas, note.name(notation), cx, labelTop);
    }
  }

  void _drawClef(Canvas canvas, double centerY) {
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
    final x = lineSpacing * 0.4;
    tp.paint(canvas, Offset(x, centerY - tp.height / 2));
  }

  void _drawNote(
    Canvas canvas,
    MusicNote note,
    double cx,
    double Function(int) yForPosition,
    Paint linePaint,
  ) {
    final pos = note.staffPosition(clef);
    final cy = yForPosition(pos);

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

  void _drawLabel(Canvas canvas, String text, double cx, double top) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: lineSpacing * 0.9,
          color: labelColor,
          fontWeight: FontWeight.bold,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, top));
  }

  @override
  bool shouldRepaint(covariant AllNotesStaffPainter oldDelegate) {
    return oldDelegate.clef != clef ||
        oldDelegate.notes != notes ||
        oldDelegate.notation != notation ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.noteColor != noteColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.lineSpacing != lineSpacing;
  }
}
