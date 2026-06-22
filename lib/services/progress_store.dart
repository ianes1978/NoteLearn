import 'package:shared_preferences/shared_preferences.dart';

/// Definizione di un traguardo (badge) sbloccabile.
class Achievement {
  final String id;
  final String emoji;
  final String title;
  final String description;

  /// Condizione di sblocco in base ai progressi accumulati.
  final bool Function(Progress p) achieved;

  const Achievement({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
    required this.achieved,
  });
}

/// Elenco dei badge disponibili nell'app.
const List<Achievement> kAchievements = [
  Achievement(
    id: 'streak5',
    emoji: '🔥',
    title: 'In serie!',
    description: '5 risposte giuste di fila',
    achieved: _streak5,
  ),
  Achievement(
    id: 'streak10',
    emoji: '⚡',
    title: 'Inarrestabile',
    description: '10 risposte giuste di fila',
    achieved: _streak10,
  ),
  Achievement(
    id: 'streak20',
    emoji: '🏆',
    title: 'Campione',
    description: '20 risposte giuste di fila',
    achieved: _streak20,
  ),
  Achievement(
    id: 'answers50',
    emoji: '🎯',
    title: 'Allenamento',
    description: '50 risposte giuste in totale',
    achieved: _answers50,
  ),
  Achievement(
    id: 'answers200',
    emoji: '🎓',
    title: 'Esperto',
    description: '200 risposte giuste in totale',
    achieved: _answers200,
  ),
  Achievement(
    id: 'days3',
    emoji: '📅',
    title: 'Costante',
    description: 'Giochi da 3 giorni di fila',
    achieved: _days3,
  ),
  Achievement(
    id: 'timed20',
    emoji: '⏱️',
    title: 'Velocista',
    description: '20 note in 60 secondi',
    achieved: _timed20,
  ),
];

bool _streak5(Progress p) => p.bestStreak >= 5;
bool _streak10(Progress p) => p.bestStreak >= 10;
bool _streak20(Progress p) => p.bestStreak >= 20;
bool _answers50(Progress p) => p.totalCorrect >= 50;
bool _answers200(Progress p) => p.totalCorrect >= 200;
bool _days3(Progress p) => p.dailyStreak >= 3;
bool _timed20(Progress p) => p.bestTimedScore >= 20;

/// Stato dei progressi del giocatore (in memoria).
class Progress {
  int bestStreak;
  int bestTimedScore;
  int totalCorrect;
  int dailyStreak;
  String lastPlayedDay; // formato yyyy-mm-dd, '' se mai giocato
  Set<String> unlockedBadges;

  Progress({
    this.bestStreak = 0,
    this.bestTimedScore = 0,
    this.totalCorrect = 0,
    this.dailyStreak = 0,
    this.lastPlayedDay = '',
    Set<String>? unlockedBadges,
  }) : unlockedBadges = unlockedBadges ?? <String>{};
}

/// Salva e carica i progressi usando SharedPreferences.
class ProgressStore {
  static const _kBestStreak = 'bestStreak';
  static const _kBestTimed = 'bestTimedScore';
  static const _kTotalCorrect = 'totalCorrect';
  static const _kDailyStreak = 'dailyStreak';
  static const _kLastDay = 'lastPlayedDay';
  static const _kBadges = 'unlockedBadges';

  /// Carica i progressi salvati.
  Future<Progress> load() async {
    final prefs = await SharedPreferences.getInstance();
    return Progress(
      bestStreak: prefs.getInt(_kBestStreak) ?? 0,
      bestTimedScore: prefs.getInt(_kBestTimed) ?? 0,
      totalCorrect: prefs.getInt(_kTotalCorrect) ?? 0,
      dailyStreak: prefs.getInt(_kDailyStreak) ?? 0,
      lastPlayedDay: prefs.getString(_kLastDay) ?? '',
      unlockedBadges: (prefs.getStringList(_kBadges) ?? const []).toSet(),
    );
  }

  Future<void> _save(Progress p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kBestStreak, p.bestStreak);
    await prefs.setInt(_kBestTimed, p.bestTimedScore);
    await prefs.setInt(_kTotalCorrect, p.totalCorrect);
    await prefs.setInt(_kDailyStreak, p.dailyStreak);
    await prefs.setString(_kLastDay, p.lastPlayedDay);
    await prefs.setStringList(_kBadges, p.unlockedBadges.toList());
  }

  static String _today() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  /// Aggiorna la streak giornaliera in base a oggi. Restituisce i progressi
  /// aggiornati (da chiamare quando si avvia una partita).
  Future<Progress> registerPlayedToday() async {
    final p = await load();
    final today = _today();
    if (p.lastPlayedDay == today) {
      return p; // già registrato oggi
    }
    final yesterday = _dayBefore(today);
    if (p.lastPlayedDay == yesterday) {
      p.dailyStreak += 1; // giorno consecutivo
    } else {
      p.dailyStreak = 1; // ricomincia
    }
    p.lastPlayedDay = today;
    await _save(p);
    return p;
  }

  static String _dayBefore(String day) {
    final parts = day.split('-').map(int.parse).toList();
    final d = DateTime(parts[0], parts[1], parts[2])
        .subtract(const Duration(days: 1));
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$dd';
  }

  /// Registra una risposta corretta e l'eventuale nuovo record di serie.
  /// Restituisce i badge appena sbloccati.
  Future<List<Achievement>> recordCorrect(int currentStreak) async {
    final p = await load();
    p.totalCorrect += 1;
    if (currentStreak > p.bestStreak) p.bestStreak = currentStreak;
    final newly = _applyBadges(p);
    await _save(p);
    return newly;
  }

  /// Registra il punteggio di una partita a tempo (aggiorna il record).
  /// Restituisce i badge appena sbloccati.
  Future<List<Achievement>> recordTimedScore(int score) async {
    final p = await load();
    if (score > p.bestTimedScore) p.bestTimedScore = score;
    final newly = _applyBadges(p);
    await _save(p);
    return newly;
  }

  /// Sblocca i badge raggiunti e restituisce solo quelli nuovi.
  List<Achievement> _applyBadges(Progress p) {
    final newly = <Achievement>[];
    for (final b in kAchievements) {
      if (b.achieved(p) && !p.unlockedBadges.contains(b.id)) {
        p.unlockedBadges.add(b.id);
        newly.add(b);
      }
    }
    return newly;
  }
}
