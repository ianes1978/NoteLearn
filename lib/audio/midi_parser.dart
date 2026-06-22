import 'dart:typed_data';

/// Una nota estratta dal MIDI: istante in tick e numero di nota MIDI.
class MidiNoteEvent {
  final int tick;
  final int noteNumber;
  const MidiNoteEvent(this.tick, this.noteNumber);
}

/// Risultato del parsing di un file MIDI (Standard MIDI File).
class ParsedMidi {
  /// Risoluzione: tick per semiminima (se positivo) oppure, per i file SMPTE,
  /// tick assoluti al secondo (vedi [_smpteTicksPerSecond]).
  final int division;
  final List<MidiNoteEvent> notes;
  final int? smpteTicksPerSecond;

  ParsedMidi({
    required this.division,
    required this.notes,
    this.smpteTicksPerSecond,
  });

  /// Converte un istante in tick in secondi, dato il tempo in BPM scelto.
  double secondsForTick(int tick, double bpm) {
    if (smpteTicksPerSecond != null && smpteTicksPerSecond! > 0) {
      return tick / smpteTicksPerSecond!;
    }
    final ticksPerQuarter = division > 0 ? division : 480;
    return tick / ticksPerQuarter * (60.0 / bpm);
  }
}

/// Parser minimale di file MIDI standard (SMF formati 0 e 1).
/// Estrae gli eventi Note-On (velocity > 0) di tutte le tracce.
class MidiParseException implements Exception {
  final String message;
  MidiParseException(this.message);
  @override
  String toString() => 'MidiParseException: $message';
}

ParsedMidi parseMidi(Uint8List bytes) {
  var pos = 0;

  int readUint32() {
    final v = (bytes[pos] << 24) |
        (bytes[pos + 1] << 16) |
        (bytes[pos + 2] << 8) |
        bytes[pos + 3];
    pos += 4;
    return v;
  }

  int readUint16() {
    final v = (bytes[pos] << 8) | bytes[pos + 1];
    pos += 2;
    return v;
  }

  String readChunkId() {
    final s = String.fromCharCodes(bytes.sublist(pos, pos + 4));
    pos += 4;
    return s;
  }

  if (bytes.length < 14) {
    throw MidiParseException('File troppo corto.');
  }
  if (readChunkId() != 'MThd') {
    throw MidiParseException('Intestazione MThd mancante.');
  }
  final headerLen = readUint32();
  readUint16(); // format (ignorato)
  final ntracks = readUint16();
  final division = readUint16();
  // Salta eventuali byte extra dell'header.
  pos += headerLen - 6;

  int? smpteTicksPerSecond;
  var effectiveDivision = division;
  if ((division & 0x8000) != 0) {
    // Formato SMPTE: byte alto = -frames, byte basso = tick per frame.
    final framesByte = (division >> 8) & 0xff;
    final frames = 256 - framesByte; // complemento a due (es. 0xE8 -> 24)
    final ticksPerFrame = division & 0xff;
    smpteTicksPerSecond = frames * ticksPerFrame;
    effectiveDivision = 0;
  }

  final notes = <MidiNoteEvent>[];

  for (var t = 0; t < ntracks; t++) {
    if (pos + 8 > bytes.length) break;
    final id = readChunkId();
    final len = readUint32();
    final end = pos + len;
    if (id != 'MTrk') {
      pos = end; // salta chunk sconosciuti
      continue;
    }
    var tick = 0;
    var runningStatus = 0;

    int readVarLen() {
      var value = 0;
      while (true) {
        final b = bytes[pos++];
        value = (value << 7) | (b & 0x7f);
        if ((b & 0x80) == 0) break;
      }
      return value;
    }

    while (pos < end) {
      tick += readVarLen();
      var status = bytes[pos];
      if (status < 0x80) {
        // Running status: riusa lo stato precedente, non consuma il byte.
        status = runningStatus;
      } else {
        pos++;
        runningStatus = status;
      }

      final hi = status & 0xf0;
      if (status == 0xff) {
        // Meta event: type + lunghezza + dati.
        pos++; // type
        final mlen = readVarLen();
        pos += mlen;
      } else if (status == 0xf0 || status == 0xf7) {
        final slen = readVarLen();
        pos += slen;
      } else if (hi == 0x90) {
        // Note On.
        final note = bytes[pos++];
        final vel = bytes[pos++];
        if (vel > 0) notes.add(MidiNoteEvent(tick, note));
      } else if (hi == 0x80 || hi == 0xa0 || hi == 0xb0 || hi == 0xe0) {
        pos += 2; // due byte dati
      } else if (hi == 0xc0 || hi == 0xd0) {
        pos += 1; // un byte dato
      } else {
        // Stato non riconosciuto: interrompe la traccia per sicurezza.
        break;
      }
    }
    pos = end;
  }

  notes.sort((a, b) => a.tick.compareTo(b.tick));

  // Riduci a una linea monofonica: per ogni istante tieni la nota più acuta.
  final mono = <MidiNoteEvent>[];
  for (final n in notes) {
    if (mono.isNotEmpty && mono.last.tick == n.tick) {
      if (n.noteNumber > mono.last.noteNumber) mono[mono.length - 1] = n;
    } else {
      mono.add(n);
    }
  }

  return ParsedMidi(
    division: effectiveDivision,
    notes: mono,
    smpteTicksPerSecond: smpteTicksPerSecond,
  );
}
