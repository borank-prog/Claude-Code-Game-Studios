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

  Future<List<Map<String, dynamic>>> fetchGangLeaderboard() async {
    // Önce gang_leaderboard koleksiyonunu dene
    try {
      final snap = await _db
          .collection('gang_leaderboard')
          .orderBy('totalPower', descending: true)
          .limit(20)
          .get()
          .timeout(const Duration(seconds: 6));
      if (snap.docs.isNotEmpty) {
        return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      }
    } catch (_) {}
    // Yoksa doğrudan gangs koleksiyonundan oku
    try {
      final snap = await _db
          .collection('gangs')
          .orderBy('totalPower', descending: true)
          .limit(20)
          .get()
          .timeout(const Duration(seconds: 6));
      if (snap.docs.isNotEmpty) {
        return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      }
    } catch (_) {}
    return [];
  }
}
