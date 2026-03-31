import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/attack_result.dart';
import '../models/attack_type.dart';

class PvpService {
  final _db = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instance;
  static const int _attackWindowSize = 5;

  Future<String?> canAttack({
    required String attackerId,
    required String targetId,
  }) async {
    if (attackerId == targetId) return 'Kendine saldıramazsın';

    final users = _db.collection('users');
    final attacker = await users
        .doc(attackerId)
        .get()
        .timeout(const Duration(seconds: 6));
    final attackerData = attacker.data();
    if (attackerData == null) return 'Saldıran oyuncu bulunamadı';

    final attackerStatus = attackerData['status'] as String? ?? 'active';
    if (attackerStatus == 'hospital' || attackerStatus == 'prison') {
      return "Şu an $attackerStatus durumundasın, saldıramazsın";
    }

    final target = await users
        .doc(targetId)
        .get()
        .timeout(const Duration(seconds: 6));
    final targetData = target.data();
    if (targetData == null) return 'Hedef bulunamadı';

    final status = targetData['status'] as String? ?? 'active';
    if (status == 'hospital' || status == 'prison') {
      return "Hedef şu an $status'de, saldırılamaz";
    }
    final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final shieldUntilEpoch =
        (targetData['shieldUntilEpoch'] as num?)?.toInt() ?? 0;
    if (shieldUntilEpoch > nowEpoch) {
      final waitSec = shieldUntilEpoch - nowEpoch;
      final waitMin = (waitSec / 60).ceil();
      return 'Hedef koruma kalkanında. Yaklaşık $waitMin dakika bekle';
    }

    final attackerPower = (attackerData['power'] as num?)?.toInt() ?? 0;
    final powerWindowBlock = await _checkPowerWindow(
      attackerId: attackerId,
      targetId: targetId,
      attackerPower: attackerPower,
    );
    if (powerWindowBlock != null) return powerWindowBlock;

    final cooldownKey = '${attackerId}_$targetId';
    final coolDoc = await _db
        .collection('attack_cooldowns')
        .doc(cooldownKey)
        .get();
    if (coolDoc.exists) {
      final lastAttack = (coolDoc['lastAttack'] as Timestamp).toDate();
      final diff = DateTime.now().difference(lastAttack);
      if (diff.inMinutes < 5) {
        return 'Tekrar saldırmak için ${5 - diff.inMinutes} dakika bekle';
      }
    }

    return null;
  }

  Future<String?> _checkPowerWindow({
    required String attackerId,
    required String targetId,
    required int attackerPower,
  }) async {
    final users = _db.collection('users');

    final stronger = await users
        .where('power', isGreaterThan: attackerPower)
        .orderBy('power')
        .limit(_attackWindowSize)
        .get()
        .timeout(const Duration(seconds: 6));
    final weaker = await users
        .where('power', isLessThan: attackerPower)
        .orderBy('power', descending: true)
        .limit(_attackWindowSize)
        .get()
        .timeout(const Duration(seconds: 6));
    final equal = await users
        .where('power', isEqualTo: attackerPower)
        .limit(25)
        .get()
        .timeout(const Duration(seconds: 6));

    final allowedTargetIds = <String>{
      ...stronger.docs.map((d) => d.id),
      ...weaker.docs.map((d) => d.id),
      ...equal.docs.map((d) => d.id),
    }..remove(attackerId);

    if (allowedTargetIds.isEmpty) {
      return 'Şu an saldırılabilir rakip yok';
    }
    if (!allowedTargetIds.contains(targetId)) {
      return 'Sadece üstündeki 5 ve altındaki 5 oyuncuya saldırabilirsin';
    }
    return null;
  }

  Future<AttackResult> executeAttack({
    required String attackerId,
    required String targetId,
    required String attackerName,
    required String targetName,
    required AttackType type,
    required int attackerPower,
    required int targetPower,
    required int equipmentBonus,
    required int attackCost,
  }) async {
    // Signature stays stable for existing callers.
    final _ = attackerId + attackerPower.toString() + targetPower.toString();
    try {
      final response = await _functions
          .httpsCallable('executePvpAttack')
          .call(<String, dynamic>{
            'targetId': targetId,
            'attackerName': attackerName,
            'targetName': targetName,
            'type': type.name,
            'equipmentBonus': equipmentBonus,
            'attackCost': attackCost,
          });

      final data = Map<String, dynamic>.from(
        (response.data as Map?) ?? const <String, dynamic>{},
      );
      final outcomeName =
          (data['outcome'] as String?) ?? AttackOutcome.draw.name;
      final outcome = AttackOutcome.values.firstWhere(
        (o) => o.name == outcomeName,
        orElse: () => AttackOutcome.draw,
      );

      return AttackResult(
        outcome: outcome,
        stolenCash: (data['stolenCash'] as num?)?.toInt() ?? 0,
        xpGained: (data['xpGained'] as num?)?.toInt() ?? 0,
        message: (data['message'] as String?) ?? 'Saldırı tamamlandı.',
        attackCost: (data['attackCost'] as num?)?.toInt(),
        remainingEnergy: (data['remainingEnergy'] as num?)?.toInt(),
        attackerWeaponName: data['attackerWeaponName'] as String?,
        targetWeaponName: data['targetWeaponName'] as String?,
        weaponPowerPct: (data['weaponPowerPct'] as num?)?.toInt(),
        weaponSpeedPct: (data['weaponSpeedPct'] as num?)?.toInt(),
        weaponTotalPct: (data['weaponTotalPct'] as num?)?.toInt(),
        attackerKnifeName: data['attackerKnifeName'] as String?,
        targetKnifeName: data['targetKnifeName'] as String?,
        attackerArmorName: data['attackerArmorName'] as String?,
        targetArmorName: data['targetArmorName'] as String?,
        attackerVehicleName: data['attackerVehicleName'] as String?,
        targetVehicleName: data['targetVehicleName'] as String?,
        knifePct: (data['knifePct'] as num?)?.toInt(),
        armorPct: (data['armorPct'] as num?)?.toInt(),
        vehiclePct: (data['vehiclePct'] as num?)?.toInt(),
        loadoutTotalPct: (data['loadoutTotalPct'] as num?)?.toInt(),
      );
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Saldırı işlemi başarısız.');
    } catch (_) {
      throw Exception('Sunucuya ulaşılamadı, tekrar dene.');
    }
  }
}
