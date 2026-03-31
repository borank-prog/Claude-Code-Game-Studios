import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/leaderboard_entry.dart';

class LeaderboardService {
  final _db = FirebaseFirestore.instance;
  static const List<String> _seedNames = [
    'Kurt_Memo',
    'Tetikci_Orhan',
    'Baron_Ali',
    'Racon_Selim',
    'Gece_Kargasi',
    'Sokak_Vurgun',
    'Golge',
    'Kasirga_Han',
    'Kral_Panzer',
    'Don_Marco',
    'Mafya_Cem',
    'Demir_Yusuf',
    'Silahsor_Apo',
    'Karanlik_Tolga',
    'Bicakci_Erdem',
    'Bela_Burak',
    'Baba_Rasim',
    'Serseri_Cenk',
    'Reis_Tuna',
    'Vurguncu_Levent',
  ];

  Future<List<LeaderboardEntry>> fetchTop({
    required LeaderboardCategory category,
    int limit = 100,
  }) async {
    final field = switch (category) {
      LeaderboardCategory.score => 'power',
      LeaderboardCategory.power => 'power',
      LeaderboardCategory.cash => 'cash',
      LeaderboardCategory.wins => 'wins',
    };
    final queryLimit = category == LeaderboardCategory.score
        ? (limit < 200 ? 200 : limit)
        : limit;

    try {
      final snap = await _db
          .collection('users')
          .orderBy(field, descending: true)
          .limit(queryLimit)
          .get()
          .timeout(const Duration(seconds: 10));

      final normalized = snap.docs.map((doc) {
        final data = doc.data();
        return <String, dynamic>{
          'uid': doc.id,
          'name': (data['name'] ?? data['displayName'] ?? 'Anonim').toString(),
          'power': (data['power'] as num?)?.toInt() ?? 0,
          'cash': (data['cash'] as num?)?.toInt() ?? 0,
          'wins': (data['wins'] as num?)?.toInt() ?? 0,
          'gangWins': (data['gangWins'] as num?)?.toInt() ?? 0,
          'gangName': data['gangName'],
        };
      }).toList();

      final merged = _topUpWithSeed(
        category: category,
        rows: normalized,
        limit: limit,
      );
      return merged.asMap().entries.map((e) {
        return LeaderboardEntry.fromFirestore(e.key + 1, e.value);
      }).toList();
    } catch (_) {
      return _seedTop(category, limit: limit);
    }
  }

  Future<int> fetchMyRank(String uid, LeaderboardCategory category) async {
    if (category == LeaderboardCategory.score) {
      try {
        final top = await fetchTop(category: category, limit: 200);
        final idx = top.indexWhere((entry) => entry.uid == uid);
        if (idx >= 0) return idx + 1;
        return 201;
      } catch (_) {
        return 11;
      }
    }

    try {
      final me = await _db.collection('users').doc(uid).get();
      final field = switch (category) {
        LeaderboardCategory.power => 'power',
        LeaderboardCategory.cash => 'cash',
        LeaderboardCategory.wins => 'wins',
        LeaderboardCategory.score => 'power',
      };
      final myVal = (me.data()?[field] as num?)?.toInt() ?? 0;

      final above = await _db
          .collection('users')
          .where(field, isGreaterThan: myVal)
          .count()
          .get()
          .timeout(const Duration(seconds: 8));

      return (above.count ?? 0) + 1;
    } catch (_) {
      return 11;
    }
  }

  List<LeaderboardEntry> _seedTop(
    LeaderboardCategory category, {
    required int limit,
  }) {
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < _seedNames.length; i++) {
      final power = 180 + (i * 55);
      rows.add({
        'uid': 'bot_${(i + 1).toString().padLeft(2, '0')}',
        'name': _seedNames[i],
        'power': power,
        'cash': 2600 + (i * 850),
        'wins': 5 + i,
        'gangWins': 1 + (i ~/ 3),
        'gangName': i < 10 ? 'Kuzey Kurtları' : 'Gece Baronları',
      });
    }

    int valueOf(Map<String, dynamic> row) {
      return switch (category) {
        LeaderboardCategory.score => _scoreOf(row),
        LeaderboardCategory.power => row['power'] as int,
        LeaderboardCategory.cash => row['cash'] as int,
        LeaderboardCategory.wins => row['wins'] as int,
      };
    }

    rows.sort((a, b) => valueOf(b).compareTo(valueOf(a)));
    return rows.take(limit).toList().asMap().entries.map((e) {
      return LeaderboardEntry.fromFirestore(e.key + 1, e.value);
    }).toList();
  }

  List<Map<String, dynamic>> _topUpWithSeed({
    required LeaderboardCategory category,
    required List<Map<String, dynamic>> rows,
    required int limit,
  }) {
    final out = List<Map<String, dynamic>>.from(rows);
    final existingIds = out
        .map((r) => (r['uid']?.toString() ?? '').trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    for (var i = 0; i < _seedNames.length; i++) {
      if (out.length >= limit) break;
      final uid = 'bot_${(i + 1).toString().padLeft(2, '0')}';
      if (existingIds.contains(uid)) continue;
      final power = 180 + (i * 55);
      out.add({
        'uid': uid,
        'name': _seedNames[i],
        'power': power,
        'cash': 2600 + (i * 850),
        'wins': 5 + i,
        'gangWins': 1 + (i ~/ 3),
        'gangName': i < 10 ? 'Kuzey Kurtları' : 'Gece Baronları',
      });
      existingIds.add(uid);
    }

    int valueOf(Map<String, dynamic> row) {
      return switch (category) {
        LeaderboardCategory.score => _scoreOf(row),
        LeaderboardCategory.power => (row['power'] as num?)?.toInt() ?? 0,
        LeaderboardCategory.cash => (row['cash'] as num?)?.toInt() ?? 0,
        LeaderboardCategory.wins => (row['wins'] as num?)?.toInt() ?? 0,
      };
    }

    out.sort((a, b) => valueOf(b).compareTo(valueOf(a)));
    return out.take(limit).toList();
  }

  int _scoreOf(Map<String, dynamic> row) {
    final power = (row['power'] as num?)?.toInt() ?? 0;
    final cash = (row['cash'] as num?)?.toInt() ?? 0;
    final wins = (row['wins'] as num?)?.toInt() ?? 0;
    final gangWins = (row['gangWins'] as num?)?.toInt() ?? 0;
    return (power * 12) + (wins * 900) + (gangWins * 1200) + (cash ~/ 2000);
  }
}
