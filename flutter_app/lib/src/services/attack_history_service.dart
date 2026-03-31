import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/attack_log.dart';

class AttackHistoryService {
  final _db = FirebaseFirestore.instance;

  Future<List<AttackLog>> fetchHistory(String uid) async {
    final asAttacker = await _db
        .collection('attacks')
        .where('attackerId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .limit(30)
        .get()
        .timeout(const Duration(seconds: 8));

    final asDefender = await _db
        .collection('attacks')
        .where('targetId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .limit(30)
        .get()
        .timeout(const Duration(seconds: 8));

    final logs = [
      ...asAttacker.docs
          .map((d) => AttackLog.fromFirestore(d.id, d.data(), uid)),
      ...asDefender.docs
          .map((d) => AttackLog.fromFirestore(d.id, d.data(), uid)),
    ];

    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return logs.take(50).toList();
  }

  Stream<List<AttackLog>> watchHistory(String uid) {
    return _db
        .collection('attacks')
        .where('attackerId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AttackLog.fromFirestore(d.id, d.data(), uid))
            .toList());
  }
}
