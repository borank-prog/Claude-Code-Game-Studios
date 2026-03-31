import 'package:cloud_firestore/cloud_firestore.dart';

import 'attack_result.dart';
import 'attack_type.dart';

class AttackLog {
  final String id;
  final String attackerId;
  final String targetId;
  final String attackerName;
  final String targetName;
  final AttackOutcome outcome;
  final AttackType type;
  final int stolenCash;
  final int xpGained;
  final DateTime timestamp;
  final bool isDefense;

  const AttackLog({
    required this.id,
    required this.attackerId,
    required this.targetId,
    required this.attackerName,
    required this.targetName,
    required this.outcome,
    required this.type,
    required this.stolenCash,
    required this.xpGained,
    required this.timestamp,
    required this.isDefense,
  });

  factory AttackLog.fromFirestore(
    String docId,
    Map<String, dynamic> d,
    String currentUid,
  ) {
    final isDefense = d['targetId'] == currentUid;
    final rawOutcome = d['outcome'] as String? ?? 'draw';

    AttackOutcome outcome;
    if (rawOutcome == 'draw') {
      outcome = AttackOutcome.draw;
    } else if (rawOutcome == 'win') {
      outcome = isDefense ? AttackOutcome.lose : AttackOutcome.win;
    } else {
      outcome = isDefense ? AttackOutcome.win : AttackOutcome.lose;
    }

    return AttackLog(
      id: docId,
      attackerId: d['attackerId'] as String,
      targetId: d['targetId'] as String,
      attackerName: d['attackerName'] as String? ?? 'Bilinmiyor',
      targetName: d['targetName'] as String? ?? 'Bilinmiyor',
      outcome: outcome,
      type: AttackType.values.firstWhere(
        (t) => t.name == d['type'],
        orElse: () => AttackType.quick,
      ),
      stolenCash: (d['stolenCash'] as num?)?.toInt() ?? 0,
      xpGained: (d['xpGained'] as num?)?.toInt() ?? 0,
      timestamp: (d['timestamp'] as Timestamp).toDate(),
      isDefense: isDefense,
    );
  }

  bool get canRevenge =>
      outcome == AttackOutcome.lose &&
      DateTime.now().difference(timestamp).inHours < 24;

  String get opponentId => isDefense ? attackerId : targetId;
  String get opponentName => isDefense ? attackerName : targetName;

  String get typeLabel => switch (type) {
        AttackType.quick => 'Hızlı saldırı',
        AttackType.planned => 'Planlı saldırı',
        AttackType.gang => 'Çete baskını',
      };

  String get directionLabel => isDefense ? 'Savunma' : 'Saldırdın';
}
