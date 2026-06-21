import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// Riproduce la nota generando al volo un tono sintetizzato (onda + armoniche),
/// senza bisogno di file audio. Funziona su tutte le piattaforme Flutter.
class NotePlayer {
  final AudioPlayer _player = AudioPlayer();
  static const int _sampleRate = 44100;

  /// Suona la nota alla [frequency] indicata per [duration].
  Future<void> play(double frequency,
      {Duration duration = const Duration(milliseconds: 850)}) async {
    try {
      final bytes = _buildWav(frequency, duration);
      await _player.stop();
      await _player.play(BytesSource(bytes, mimeType: 'audio/wav'));
    } catch (_) {
      // Se l'audio non è disponibile su questa piattaforma, ignora
      // silenziosamente: il resto dell'app continua a funzionare.
    }
  }

  void dispose() {
    _player.dispose();
  }

  /// Costruisce un file WAV PCM 16-bit mono con un suono "tipo organo"
  /// (fondamentale + armoniche) e un inviluppo morbido per evitare i click.
  Uint8List _buildWav(double freq, Duration duration) {
    final totalSamples = (_sampleRate * duration.inMilliseconds / 1000).round();
    final data = Int16List(totalSamples);

    final attack = (_sampleRate * 0.01).round(); // 10 ms
    final release = (_sampleRate * 0.18).round(); // 180 ms

    for (var i = 0; i < totalSamples; i++) {
      final t = i / _sampleRate;
      final twoPiFt = 2 * pi * freq * t;
      // Fondamentale + armoniche per un timbro più ricco e gradevole.
      var sample = sin(twoPiFt) +
          0.5 * sin(2 * twoPiFt) +
          0.25 * sin(3 * twoPiFt);
      sample /= 1.75; // normalizza

      // Inviluppo: dissolvenza in entrata e in uscita.
      var env = 1.0;
      if (i < attack) {
        env = i / attack;
      } else if (i > totalSamples - release) {
        env = (totalSamples - i) / release;
      }

      data[i] = (sample * env * 0.6 * 32767).clamp(-32768, 32767).toInt();
    }

    return _wrapWav(data);
  }

  Uint8List _wrapWav(Int16List samples) {
    const channels = 1;
    const bitsPerSample = 16;
    final byteRate = _sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final dataSize = samples.length * 2;
    final fileSize = 44 + dataSize;

    final bytes = BytesBuilder();
    void writeString(String s) => bytes.add(s.codeUnits);
    void writeUint32(int v) => bytes.add([
          v & 0xff,
          (v >> 8) & 0xff,
          (v >> 16) & 0xff,
          (v >> 24) & 0xff,
        ]);
    void writeUint16(int v) => bytes.add([v & 0xff, (v >> 8) & 0xff]);

    // RIFF header
    writeString('RIFF');
    writeUint32(fileSize - 8);
    writeString('WAVE');
    // fmt chunk
    writeString('fmt ');
    writeUint32(16);
    writeUint16(1); // PCM
    writeUint16(channels);
    writeUint32(_sampleRate);
    writeUint32(byteRate);
    writeUint16(blockAlign);
    writeUint16(bitsPerSample);
    // data chunk
    writeString('data');
    writeUint32(dataSize);
    final byteData = ByteData(dataSize);
    for (var i = 0; i < samples.length; i++) {
      byteData.setInt16(i * 2, samples[i], Endian.little);
    }
    bytes.add(byteData.buffer.asUint8List());

    return bytes.toBytes();
  }
}
