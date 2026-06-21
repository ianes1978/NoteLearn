import 'package:flutter_test/flutter_test.dart';
import 'package:notelearn/models/music_note.dart';

void main() {
  group('MusicNote nomi', () {
    test('Do/C ha i nomi corretti', () {
      const c = MusicNote(0, 4);
      expect(c.letterName, 'C');
      expect(c.solfegeName, 'Do');
      expect(c.name(Notation.solfege), 'Do');
      expect(c.name(Notation.letters), 'C');
      expect(c.name(Notation.both), 'Do (C)');
    });

    test('Si/B è la settima nota', () {
      const b = MusicNote(6, 4);
      expect(b.letterName, 'B');
      expect(b.solfegeName, 'Si');
    });
  });

  group('Posizione sul pentagramma', () {
    test('chiave di violino: Si4 è la linea centrale (posizione 0)', () {
      expect(const MusicNote(6, 4).staffPosition(Clef.treble), 0);
    });

    test('chiave di violino: Mi4 è la linea inferiore (posizione -4)', () {
      expect(const MusicNote(2, 4).staffPosition(Clef.treble), -4);
    });

    test('chiave di violino: Fa5 è la linea superiore (posizione +4)', () {
      expect(const MusicNote(3, 5).staffPosition(Clef.treble), 4);
    });

    test('chiave di basso: Re3 è la linea centrale (posizione 0)', () {
      expect(const MusicNote(1, 3).staffPosition(Clef.bass), 0);
    });
  });

  group('Generazione note', () {
    test('genera l\'intervallo richiesto', () {
      final notes = notesForClef(Clef.treble, minPosition: -4, maxPosition: 4);
      expect(notes.length, 9);
      expect(notes.first.staffPosition(Clef.treble), -4);
      expect(notes.last.staffPosition(Clef.treble), 4);
    });
  });
}
