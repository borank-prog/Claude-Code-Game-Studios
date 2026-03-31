enum AttackOutcome { win, lose, draw }

class AttackResult {
  final AttackOutcome outcome;
  final int stolenCash;
  final int xpGained;
  final String message;
  final int? attackCost;
  final int? remainingEnergy;
  final String? attackerWeaponName;
  final String? targetWeaponName;
  final int? weaponPowerPct;
  final int? weaponSpeedPct;
  final int? weaponTotalPct;
  final String? attackerKnifeName;
  final String? targetKnifeName;
  final String? attackerArmorName;
  final String? targetArmorName;
  final String? attackerVehicleName;
  final String? targetVehicleName;
  final int? knifePct;
  final int? armorPct;
  final int? vehiclePct;
  final int? loadoutTotalPct;

  const AttackResult({
    required this.outcome,
    required this.stolenCash,
    required this.xpGained,
    required this.message,
    this.attackCost,
    this.remainingEnergy,
    this.attackerWeaponName,
    this.targetWeaponName,
    this.weaponPowerPct,
    this.weaponSpeedPct,
    this.weaponTotalPct,
    this.attackerKnifeName,
    this.targetKnifeName,
    this.attackerArmorName,
    this.targetArmorName,
    this.attackerVehicleName,
    this.targetVehicleName,
    this.knifePct,
    this.armorPct,
    this.vehiclePct,
    this.loadoutTotalPct,
  });
}
