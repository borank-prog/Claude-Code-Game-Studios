import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/attack_result.dart';
import '../models/gang_raid.dart';

class GangRaidService {
  final _db = FirebaseFirestore.instance;
  final _rng = Random();

  Future<GangRaid> createRaid({
    required String leaderId,
    required String targetId,
  }) async {
    final ref = _db.collection('gang_raids').doc();
    final raid = GangRaid(
      id: ref.id,
      leaderId: leaderId,
      targetId: targetId,
      members: [leaderId],
      status: RaidStatus.waiting,
      createdAt: DateTime.now(),
    );
    await ref.set(raid.toMap()).timeout(const Duration(seconds: 6));
    return raid;
  }

  Future<void> joinRaid({
    required String raidId,
    required String userId,
  }) async {
    final ref = _db.collection('gang_raids').doc(raidId);
    await ref.update({
      'members': FieldValue.arrayUnion([userId]),
    }).timeout(const Duration(seconds: 6));
  }

  Future<AttackResult> startRaid({
    required GangRaid raid,
    required int totalAttackerPower,
    required int targetPower,
  }) async {
    if (!raid.canStart) throw Exception('En az 2 kişi gerekli');

    final bonus = (raid.members.length - 1) * 10;
    final boostedPower =
        totalAttackerPower + (totalAttackerPower * bonus ~/ 100);

    final atkRoll = _rng.nextInt(boostedPower ~/ 5 + 1);
    final defRoll = _rng.nextInt(targetPower ~/ 5 + 1);
    final atkTotal = boostedPower + atkRoll;
    final defTotal = targetPower + defRoll;

    final outcome = atkTotal > defTotal * 1.05
        ? AttackOutcome.win
        : atkTotal < defTotal * 0.95
            ? AttackOutcome.lose
            : AttackOutcome.draw;

    final batch = _db.batch();
    int stolenCash = 0;
    int xpGained = 0;
    String message = '';

    if (outcome == AttackOutcome.win) {
      final targetSnap =
          await _db.collection('users').doc(raid.targetId).get();
      final targetCash = (targetSnap['cash'] as num?)?.toInt() ?? 0;
      final totalStolen = (targetCash * 0.15).toInt().clamp(100, 100000);
      stolenCash = totalStolen ~/ raid.members.length;
      xpGained = 50;

      for (final uid in raid.members) {
        batch.update(_db.collection('users').doc(uid), {
          'cash': FieldValue.increment(stolenCash),
          'xp': FieldValue.increment(xpGained),
        });
      }
      batch.update(_db.collection('users').doc(raid.targetId), {
        'cash': FieldValue.increment(-totalStolen),
        'status': 'prison',
        'statusUntil': Timestamp.fromDate(
          DateTime.now().add(const Duration(minutes: 45)),
        ),
      });
      message = 'Çete baskını başarılı! Kişi başı $stolenCash \$ kazandınız.';
    } else if (outcome == AttackOutcome.lose) {
      batch.update(_db.collection('users').doc(raid.leaderId), {
        'status': 'hospital',
        'statusUntil': Timestamp.fromDate(
          DateTime.now().add(const Duration(minutes: 45)),
        ),
      });
      message = 'Baskın başarısız! Lider hastaneye kaldırıldı.';
    } else {
      message = 'Berabere! Hedef kaçmayı başardı.';
    }

    batch.update(_db.collection('gang_raids').doc(raid.id), {
      'status': RaidStatus.completed.name,
    });

    await batch.commit().timeout(const Duration(seconds: 8));

    return AttackResult(
      outcome: outcome,
      stolenCash: stolenCash,
      xpGained: xpGained,
      message: message,
    );
  }

  Stream<GangRaid?> watchRaid(String raidId) {
    return _db.collection('gang_raids').doc(raidId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return GangRaid.fromFirestore(snap.id, snap.data()!);
    });
  }
}
