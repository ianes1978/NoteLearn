import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../audio/midi_parser.dart';
import '../audio/note_player.dart';
import '../models/music_note.dart';
import '../widgets/piano_keyboard.dart';

/// Stato di una nota nel gioco.
enum _NoteStatus { pending, hit, missed }

class _GameNote {
  final double time; // secondi (incluso il lead-in)
  final MusicNote note;
  _NoteStatus status = _NoteStatus.pending;
  _GameNote(this.time, this.note);
}

/// Fasi della schermata.
enum _Phase { setup, playing, gameOver, finished }

/// Quanto tempo (in secondi) una nota impiega ad attraversare lo schermo fino
/// alla zona di gioco.
const double _travelSeconds = 3.0;

/// Tolleranza (in secondi) per colpire una nota.
const double _hitWindow = 0.45;

const int _maxLives = 4;
const int _startLives = 3;
const int _comboPerLife = 10;

/// Modalità MIDI: carica un file MIDI, le note scorrono da destra a sinistra
/// e vanno suonate quando raggiungono la zona a sinistra. Tre vite, +1 vita
/// ogni 10 note di fila (fino a 4).
class MidiGameScreen extends StatefulWidget {
  final Notation notation;
  const MidiGameScreen({super.key, required this.notation});

  @override
  State<MidiGameScreen> createState() => _MidiGameScreenState();
}

class _MidiGameScreenState extends State<MidiGameScreen>
    with SingleTickerProviderStateMixin {
  final NotePlayer _audio = NotePlayer();
  Ticker? _ticker;

  _Phase _phase = _Phase.setup;

  ParsedMidi? _parsed;
  String _fileName = '';
  double _bpm = 90;
  bool _loading = false;
  String? _error;

  late Clef _clef;
  List<_GameNote> _notes = [];
  double _elapsed = 0;
  double _songEnd = 0;

  int _lives = _startLives;
  int _score = 0;
  int _combo = 0;
  int _comboForLife = 0;
  bool _showKeyLabels = true;

  @override
  void dispose() {
    _ticker?.dispose();
    _audio.dispose();
    super.dispose();
  }

  // ---- Caricamento file ----

  Future<void> _pickFile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mid', 'midi'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _loading = false);
        return;
      }
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('Impossibile leggere il file.');
      }
      final parsed = parseMidi(bytes);
      if (parsed.notes.isEmpty) {
        throw Exception('Nessuna nota trovata nel file MIDI.');
      }
      setState(() {
        _parsed = parsed;
        _fileName = file.name;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Errore: $e';
      });
    }
  }

  // ---- Avvio gioco ----

  void _buildNotes() {
    final parsed = _parsed!;
    // Sceglie la chiave in base all'altezza media.
    final avg = parsed.notes
            .map((n) => n.noteNumber)
            .reduce((a, b) => a + b) /
        parsed.notes.length;
    _clef = avg < 60 ? Clef.bass : Clef.treble;

    _notes = parsed.notes
        .map((e) => _GameNote(
              parsed.secondsForTick(e.tick, _bpm) + _travelSeconds,
              MusicNote.fromMidi(e.noteNumber),
            ))
        .toList();
    _songEnd = _notes.isEmpty ? 0 : _notes.last.time;
  }

  void _startGame() {
    _buildNotes();
    setState(() {
      _phase = _Phase.playing;
      _elapsed = 0;
      _lives = _startLives;
      _score = 0;
      _combo = 0;
      _comboForLife = 0;
    });
    _ticker ??= createTicker(_onTick);
    _ticker!
      ..stop()
      ..start();
  }

  void _onTick(Duration d) {
    if (_phase != _Phase.playing) return;
    final t = d.inMicroseconds / 1e6;
    _checkMisses(t);
    if (_phase != _Phase.playing) return;
    if (t > _songEnd + _hitWindow + 0.6) {
      _ticker?.stop();
      setState(() => _phase = _Phase.finished);
      return;
    }
    setState(() => _elapsed = t);
  }

  void _checkMisses(double t) {
    for (final n in _notes) {
      if (n.status == _NoteStatus.pending && t > n.time + _hitWindow) {
        n.status = _NoteStatus.missed;
        _registerMiss();
        if (_phase != _Phase.playing) return;
      }
    }
  }

  void _registerMiss() {
    _combo = 0;
    _comboForLife = 0;
    _lives--;
    if (_lives <= 0) {
      _lives = 0;
      _ticker?.stop();
      setState(() => _phase = _Phase.gameOver);
    }
  }

  void _onPlay(int midi) {
    // Suona sempre il tasto premuto (feedback).
    _audio.play(MusicNote.fromMidi(midi).frequency);
    final pitchClass = midi % 12;
    if (_phase != _Phase.playing) return;

    // Cerca la nota in finestra più vicina al momento attuale.
    _GameNote? best;
    double bestDist = double.infinity;
    for (final n in _notes) {
      if (n.status != _NoteStatus.pending) continue;
      final dist = (n.time - _elapsed).abs();
      if (dist <= _hitWindow && dist < bestDist) {
        best = n;
        bestDist = dist;
      }
    }
    if (best == null) return; // nessuna nota: nota libera, nessuna penalità
    if (best.note.pitchClass == pitchClass) {
      setState(() {
        best!.status = _NoteStatus.hit;
        _score++;
        _combo++;
        _comboForLife++;
        if (_comboForLife >= _comboPerLife) {
          _comboForLife = 0;
          if (_lives < _maxLives) _lives++;
        }
      });
    }
    // Tasto sbagliato: nessuna penalità (la nota può ancora essere colpita).
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MIDI'),
        actions: [
          if (_phase == _Phase.playing)
            IconButton(
              tooltip: _showKeyLabels
                  ? 'Nascondi i nomi sui tasti'
                  : 'Mostra i nomi sui tasti',
              icon: Icon(_showKeyLabels ? Icons.label : Icons.label_off),
              onPressed: () =>
                  setState(() => _showKeyLabels = !_showKeyLabels),
            ),
        ],
      ),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.setup => _buildSetup(),
          _Phase.playing => _buildGame(),
          _Phase.gameOver => _buildResult(won: false),
          _Phase.finished => _buildResult(won: true),
        },
      ),
    );
  }

  Widget _buildSetup() {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.queue_music,
                  size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text('Modalità MIDI',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Carica un file MIDI: le note scorreranno verso la zona di '
                'gioco a sinistra. Suonale al momento giusto! Hai 3 vite, '
                '+1 ogni 10 note di fila (max 4).',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _loading ? null : _pickFile,
                icon: const Icon(Icons.upload_file),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_loading ? 'Caricamento…' : 'Scegli file MIDI'),
                ),
              ),
              if (_fileName.isNotEmpty && _error == null) ...[
                const SizedBox(height: 12),
                Text('✓ $_fileName · ${_parsed?.notes.length ?? 0} note',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.primary)),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 24),
              Text('Tempo: ${_bpm.round()} BPM',
                  style: theme.textTheme.titleSmall),
              Slider(
                value: _bpm,
                min: 40,
                max: 200,
                divisions: 160,
                label: '${_bpm.round()}',
                onChanged: (v) => setState(() => _bpm = v),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: (_parsed != null && (_parsed!.notes.isNotEmpty))
                    ? _startGame
                    : null,
                icon: const Icon(Icons.play_arrow),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Inizia', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGame() {
    final theme = Theme.of(context);
    return Column(
      children: [
        _Hud(lives: _lives, score: _score, combo: _combo),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: CustomPaint(
                  painter: _FallingNotesPainter(
                    clef: _clef,
                    notes: _notes,
                    elapsed: _elapsed,
                    notation: widget.notation,
                    lineColor: theme.colorScheme.onSurface,
                    pendingColor: theme.colorScheme.primary,
                    hitColor: Colors.green,
                    missColor: Colors.red,
                    zoneColor: theme.colorScheme.primary.withValues(alpha: 0.18),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 150,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: PianoKeyboard(
              notation: widget.notation,
              onKey: _onPlay,
              showLabels: _showKeyLabels,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResult({required bool won}) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(won ? '🎉 Brano completato!' : '💔 Game over',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('$_score',
                style: theme.textTheme.displayMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const Text('note indovinate'),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _startGame,
              icon: const Icon(Icons.replay),
              label: const Text('Rigioca'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => setState(() => _phase = _Phase.setup),
              child: const Text('Carica un altro brano'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hud extends StatelessWidget {
  final int lives;
  final int score;
  final int combo;
  const _Hud({required this.lives, required this.score, required this.combo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              for (var i = 0; i < _maxLives; i++)
                Icon(
                  i < lives ? Icons.favorite : Icons.favorite_border,
                  color: Colors.red,
                  size: 22,
                ),
            ],
          ),
          Row(
            children: [
              if (combo >= 2) ...[
                Text('🔥 $combo',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: Colors.orange)),
                const SizedBox(width: 12),
              ],
              Text('$score', style: theme.textTheme.titleLarge),
            ],
          ),
        ],
      ),
    );
  }
}

/// Disegna il pentagramma fisso con la zona di gioco e le note che scorrono.
class _FallingNotesPainter extends CustomPainter {
  final Clef clef;
  final List<_GameNote> notes;
  final double elapsed;
  final Notation notation;
  final Color lineColor;
  final Color pendingColor;
  final Color hitColor;
  final Color missColor;
  final Color zoneColor;

  _FallingNotesPainter({
    required this.clef,
    required this.notes,
    required this.elapsed,
    required this.notation,
    required this.lineColor,
    required this.pendingColor,
    required this.hitColor,
    required this.missColor,
    required this.zoneColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final lineSpacing = size.height / 11;
    final centerY = size.height / 2;
    final halfStep = lineSpacing / 2;
    final hitX = size.width * 0.18;
    final pxPerSec = (size.width - hitX) / _travelSeconds;

    double yForPos(int pos) => centerY - pos * halfStep;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    // Zona di gioco (banda verticale a sinistra).
    final zonePaint = Paint()..color = zoneColor;
    canvas.drawRect(
      Rect.fromLTWH(hitX - lineSpacing, 0, lineSpacing * 2, size.height),
      zonePaint,
    );
    canvas.drawLine(
      Offset(hitX, 0),
      Offset(hitX, size.height),
      Paint()
        ..color = pendingColor
        ..strokeWidth = 2.5,
    );

    // Linee del pentagramma.
    for (var pos = -4; pos <= 4; pos += 2) {
      final y = yForPos(pos);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
    _drawClef(canvas, centerY, lineSpacing);

    // Note in scorrimento.
    for (final n in notes) {
      final x = hitX + (n.time - elapsed) * pxPerSec;
      if (x < -lineSpacing * 2 || x > size.width + lineSpacing * 2) continue;
      final pos = n.note.staffPosition(clef);
      final cy = yForPos(pos);
      final color = switch (n.status) {
        _NoteStatus.pending => pendingColor,
        _NoteStatus.hit => hitColor,
        _NoteStatus.missed => missColor,
      };
      _drawLedgers(canvas, x, pos, lineSpacing, yForPos);
      final notePaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.save();
      canvas.translate(x, cy);
      canvas.rotate(-0.32);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: lineSpacing * 1.35,
          height: lineSpacing * 1.02,
        ),
        notePaint,
      );
      canvas.restore();
      _drawLabel(canvas, n.note.name(_labelNotation), x, size.height,
          lineSpacing, color);
    }
  }

  Notation get _labelNotation =>
      notation == Notation.both ? Notation.solfege : notation;

  void _drawLedgers(Canvas canvas, double cx, int pos, double lineSpacing,
      double Function(int) yForPos) {
    final ledgerPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.6;
    final hw = lineSpacing * 0.85;
    if (pos >= 6) {
      final maxLine = pos.isEven ? pos : pos - 1;
      for (var l = 6; l <= maxLine; l += 2) {
        final y = yForPos(l);
        canvas.drawLine(Offset(cx - hw, y), Offset(cx + hw, y), ledgerPaint);
      }
    } else if (pos <= -6) {
      final minLine = pos.isEven ? pos : pos + 1;
      for (var l = -6; l >= minLine; l -= 2) {
        final y = yForPos(l);
        canvas.drawLine(Offset(cx - hw, y), Offset(cx + hw, y), ledgerPaint);
      }
    }
  }

  void _drawClef(Canvas canvas, double centerY, double lineSpacing) {
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
    tp.paint(canvas, Offset(2, centerY - tp.height / 2));
  }

  void _drawLabel(Canvas canvas, String text, double cx, double height,
      double lineSpacing, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: lineSpacing * 0.9,
          color: color,
          fontWeight: FontWeight.bold,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, height - lineSpacing * 1.4));
  }

  @override
  bool shouldRepaint(covariant _FallingNotesPainter oldDelegate) => true;
}
