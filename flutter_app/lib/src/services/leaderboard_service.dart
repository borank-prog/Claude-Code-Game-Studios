import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/leaderboard_entry.dart';

class LeaderboardService {
  final _db = FirebaseFirestore.instance;
  static const List<String> _seedGangs = [
    'Kuzey Kurtları',
    'Gece Baronları',
    'Demir Yumruk',
    'Kızıl Kartel',
  ];

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
      final col = _db.collection('users');
      final byUid = <String, Map<String, dynamic>>{};

      void absorb(QuerySnapshot<Map<String, dynamic>> snap) {
        for (final doc in snap.docs) {
          final data = doc.data();
          byUid[doc.id] = <String, dynamic>{
            'uid': doc.id,
            'name': (data['name'] ?? data['displayName'] ?? 'Anonim')
                .toString(),
            'power': (data['power'] as num?)?.toInt() ?? 0,
            'cash': (data['cash'] as num?)?.toInt() ?? 0,
            'wins': (data['wins'] as num?)?.toInt() ?? 0,
            'gangWins': (data['gangWins'] as num?)?.toInt() ?? 0,
            'gangName': data['gangName'],
            'online': data['online'] == true,
          };
        }
      }

      try {
        final ranked = await col
            .orderBy(field, descending: true)
            .limit(queryLimit)
            .get()
            .timeout(const Duration(seconds: 10));
        absorb(ranked);
      } catch (_) {
        // Missing field/index fallback continues below.
      }

      if (byUid.length < queryLimit) {
        try {
          final active = await col
              .orderBy('updatedAt', descending: true)
              .limit(queryLimit < 150 ? 150 : (queryLimit * 2))
              .get()
              .timeout(const Duration(seconds: 10));
          absorb(active);
        } catch (_) {}
      }

      if (byUid.length < queryLimit) {
        try {
          final any = await col
              .limit(queryLimit < 250 ? 250 : (queryLimit * 3))
              .get()
              .timeout(const Duration(seconds: 10));
          absorb(any);
        } catch (_) {}
      }

      final normalized = byUid.values.toList(growable: false);
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
    // Tüm kategorilerde gerçek sırayı hesapla (bot sıralaması dahil)
    try {
      final top = await fetchTop(category: category, limit: 200);
      final idx = top.indexWhere((entry) => entry.uid == uid);
      if (idx >= 0) return idx + 1;
      // Listeye girmemiş — listenin sonundan bir sonraki sıra
      return top.length + 1;
    } catch (_) {
      return 99;
    }
  }

  /// Bot istatistiklerini saat+dakika bazlı rastgele üret.
  /// Böylece her yenilemede botlar hafif farklı görünür (canlı oyuncu hissi).
  Map<String, dynamic> _botRow(int i) {
    final seed = DateTime.now().hour * 1000 + DateTime.now().minute ~/ 5;
    final rng = Random(seed + i * 97);
    // Botların taban gücü düşük tutuldu (50-400 arası) — gerçek oyuncular kolayca üste geçsin
    final basePower = 50 + (i * 18);
    final power = max(30, basePower + rng.nextInt(20) - 10);
    final baseWins = 2 + i;
    final wins = max(0, baseWins + rng.nextInt(4) - 1);
    final baseCash = 500 + (i * 300);
    final cash = max(0, baseCash + rng.nextInt(500) - 200);
    // %60 ihtimalle online
    final isOnline = rng.nextInt(5) < 3;
    return {
      'uid': 'bot_${(i + 1).toString().padLeft(2, '0')}',
      'name': _seedNames[i],
      'power': power,
      'cash': cash,
      'wins': wins,
      'gangWins': 1 + (i ~/ 4),
      'gangName': _seedGangs[i ~/ 5],
      'online': isOnline,
    };
  }

  List<LeaderboardEntry> _seedTop(
    LeaderboardCategory category, {
    required int limit,
  }) {
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < _seedNames.length; i++) {
      rows.add(_botRow(i));
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
      out.add(_botRow(i));
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
