import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/trade_offer.dart';

class TradeService {
  final _db = FirebaseFirestore.instance;

  Future<TradeOffer> createOffer({
    required String fromId,
    required String fromName,
    required String toId,
    required String toName,
    int offerCash = 0,
    int requestCash = 0,
  }) async {
    final ref = _db.collection('trade_offers').doc();
    final offer = TradeOffer(
      id: ref.id,
      fromId: fromId,
      fromName: fromName,
      toId: toId,
      toName: toName,
      offerCash: offerCash,
      requestCash: requestCash,
      createdAt: DateTime.now(),
    );
    await ref.set(offer.toMap()).timeout(const Duration(seconds: 6));
    return offer;
  }

  Future<Map<String, dynamic>> respondToOffer({
    required String offerId,
    required String action, // 'accept' or 'reject'
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable('executeTrade');
    final result = await callable.call<Map<String, dynamic>>({
      'offerId': offerId,
      'action': action,
    });
    return Map<String, dynamic>.from(result.data);
  }

  Future<void> cancelOffer(String offerId) async {
    await _db
        .collection('trade_offers')
        .doc(offerId)
        .update({'status': 'cancelled'})
        .timeout(const Duration(seconds: 6));
  }

  Stream<List<TradeOffer>> watchIncoming(String userId) {
    return _db
        .collection('trade_offers')
        .where('toId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => TradeOffer.fromFirestore(d.id, d.data()))
              .toList(),
        );
  }

  Stream<List<TradeOffer>> watchOutgoing(String userId) {
    return _db
        .collection('trade_offers')
        .where('fromId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => TradeOffer.fromFirestore(d.id, d.data()))
              .toList(),
        );
  }

  Future<List<Map<String, dynamic>>> fetchGangLeaderboard({
    String? myGangId,
  }) async {
    final seedGangs = <Map<String, dynamic>>[
      {
        'id': 'seed_gang_01',
        'name': 'Kuzey Kurtları',
        'totalPower': 4950,
        'memberCount': 5,
        'respectPoints': 120,
        'inviteOnly': false,
        'acceptJoinRequests': false,
      },
      {
        'id': 'seed_gang_02',
        'name': 'Gece Baronları',
        'totalPower': 4200,
        'memberCount': 5,
        'respectPoints': 95,
        'inviteOnly': false,
        'acceptJoinRequests': false,
      },
      {
        'id': 'seed_gang_03',
        'name': 'Demir Yumruk',
        'totalPower': 3500,
        'memberCount': 5,
        'respectPoints': 72,
        'inviteOnly': false,
        'acceptJoinRequests': false,
      },
      {
        'id': 'seed_gang_04',
        'name': 'Kızıl Kartel',
        'totalPower': 2800,
        'memberCount': 5,
        'respectPoints': 58,
        'inviteOnly': false,
        'acceptJoinRequests': false,
      },
    ];

    List<Map<String, dynamic>> realGangs = [];

    // Önce gang_leaderboard koleksiyonunu dene
    try {
      final snap = await _db
          .collection('gang_leaderboard')
          .orderBy('totalPower', descending: true)
          .limit(20)
          .get()
          .timeout(const Duration(seconds: 6));
      if (snap.docs.isNotEmpty) {
        realGangs = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      }
    } catch (_) {}

    // Yoksa doğrudan gangs koleksiyonundan oku (sıralama olmadan — index gerekmez)
    if (realGangs.isEmpty) {
      try {
        final snap = await _db
            .collection('gangs')
            .limit(50)
            .get()
            .timeout(const Duration(seconds: 6));
        realGangs = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      } catch (_) {}
    }

    // Kullanıcının kendi çetesi Firestore'da varsa ve listede yoksa ekle
    if (myGangId != null && myGangId.isNotEmpty) {
      final alreadyIn = realGangs.any((g) => g['id'] == myGangId);
      if (!alreadyIn) {
        try {
          final myGangSnap =
              await _db.collection('gangs').doc(myGangId).get().timeout(
                    const Duration(seconds: 6),
                  );
          if (myGangSnap.exists) {
            realGangs.add({'id': myGangSnap.id, ...myGangSnap.data()!});
          }
        } catch (_) {}
      }
    }

    // Gerçek çeteler varsa seed'lerle merge et
    // ID ve isim bazlı dedupe — seed'ler sadece gerçek listede karşılığı yoksa eklenir
    if (realGangs.isNotEmpty) {
      final realIds = realGangs.map((g) => g['id'] as String).toSet();
      final realNames = realGangs
          .map((g) => (g['name'] as String? ?? '').toLowerCase())
          .toSet();
      final merged = [
        ...realGangs,
        ...seedGangs.where(
          (s) =>
              !realIds.contains(s['id']) &&
              !realNames.contains((s['name'] as String? ?? '').toLowerCase()),
        ),
      ];
      merged.sort(
        (a, b) => ((b['totalPower'] as num?) ?? 0)
            .compareTo((a['totalPower'] as num?) ?? 0),
      );
      return merged;
    }

    return seedGangs;
  }
}
