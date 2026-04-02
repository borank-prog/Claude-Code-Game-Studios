import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/trade_offer.dart';

class TradeService {
  final _db = FirebaseFirestore.instance;

  String _normalizeGangName(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9çğıöşü]+'), '')
        .trim();
  }

  bool _isMyGang(Map<String, dynamic> g, String? myGangId) {
    if (myGangId == null || myGangId.isEmpty) return false;
    return (g['id']?.toString() ?? '').trim() == myGangId.trim();
  }

  Map<String, dynamic> _pickPreferredGang(
    Map<String, dynamic> a,
    Map<String, dynamic> b, {
    String? myGangId,
  }) {
    if (_isMyGang(a, myGangId)) return a;
    if (_isMyGang(b, myGangId)) return b;
    final aPower = (a['totalPower'] as num?)?.toInt() ?? 0;
    final bPower = (b['totalPower'] as num?)?.toInt() ?? 0;
    return bPower > aPower ? b : a;
  }

  List<Map<String, dynamic>> _dedupeGangRows(
    List<Map<String, dynamic>> rows, {
    String? myGangId,
  }) {
    final source = rows.map((r) => Map<String, dynamic>.from(r)).toList(growable: false);

    // 1) Aynı owner'a ait birden fazla kayıt varsa tek kayda düşür.
    final byOwner = <String, Map<String, dynamic>>{};
    final ownerPass = <Map<String, dynamic>>[];
    for (final g in source) {
      final ownerId = (g['ownerId'] as String? ?? '').trim();
      if (ownerId.isEmpty) {
        ownerPass.add(g);
        continue;
      }
      final existing = byOwner[ownerId];
      byOwner[ownerId] =
          existing == null ? g : _pickPreferredGang(existing, g, myGangId: myGangId);
    }
    ownerPass.addAll(byOwner.values);

    // 2) Aynı ada sahip kayıtları tekilleştir (özellikle eski ATA kopyaları için).
    final byName = <String, Map<String, dynamic>>{};
    final result = <Map<String, dynamic>>[];
    for (final g in ownerPass) {
      final nameKey = _normalizeGangName((g['name'] as String? ?? ''));
      if (nameKey.isEmpty) {
        result.add(g);
        continue;
      }
      final existing = byName[nameKey];
      byName[nameKey] =
          existing == null ? g : _pickPreferredGang(existing, g, myGangId: myGangId);
    }
    result.addAll(byName.values);
    return result;
  }

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
      final deduped = _dedupeGangRows(merged, myGangId: myGangId);
      deduped.sort(
        (a, b) => ((b['totalPower'] as num?) ?? 0)
            .compareTo((a['totalPower'] as num?) ?? 0),
      );
      return deduped;
    }

    return seedGangs;
  }
}
