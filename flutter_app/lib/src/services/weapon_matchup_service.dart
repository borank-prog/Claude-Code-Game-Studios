import '../data/game_models.dart';
import '../data/static_data.dart';

enum WeaponArchetype {
  unarmed,
  melee,
  pistol,
  smg,
  shotgun,
  rifle,
  sniper,
  explosive,
}

enum ArmorArchetype { none, leather, steel, heavy }

enum VehicleArchetype { none, sedan, armored, sport }

class CombatLoadout {
  const CombatLoadout({
    required this.weaponId,
    required this.knifeId,
    required this.armorId,
    required this.vehicleId,
  });

  final String weaponId;
  final String knifeId;
  final String armorId;
  final String vehicleId;

  String get primaryWeaponId => weaponId.isNotEmpty ? weaponId : knifeId;
}

class WeaponMatchupEffect {
  const WeaponMatchupEffect({
    required this.attackerArchetype,
    required this.targetArchetype,
    required this.powerPct,
    required this.speedPct,
    required this.totalPct,
  });

  final WeaponArchetype attackerArchetype;
  final WeaponArchetype targetArchetype;
  final int powerPct;
  final int speedPct;
  final int totalPct;
}

class LoadoutMatchupEffect {
  const LoadoutMatchupEffect({
    required this.weaponPowerPct,
    required this.weaponSpeedPct,
    required this.weaponTotalPct,
    required this.knifePct,
    required this.armorPct,
    required this.vehiclePct,
    required this.totalPct,
  });

  final int weaponPowerPct;
  final int weaponSpeedPct;
  final int weaponTotalPct;
  final int knifePct;
  final int armorPct;
  final int vehiclePct;
  final int totalPct;
}

class WeaponMatchupService {
  static const Map<WeaponArchetype, int> _speedTier = {
    WeaponArchetype.unarmed: 5,
    WeaponArchetype.melee: 8,
    WeaponArchetype.pistol: 7,
    WeaponArchetype.smg: 9,
    WeaponArchetype.shotgun: 4,
    WeaponArchetype.rifle: 6,
    WeaponArchetype.sniper: 3,
    WeaponArchetype.explosive: 2,
  };

  static const Map<WeaponArchetype, Map<WeaponArchetype, int>> _advantage = {
    WeaponArchetype.unarmed: {
      WeaponArchetype.sniper: 6,
      WeaponArchetype.explosive: 8,
      WeaponArchetype.shotgun: -10,
      WeaponArchetype.smg: -8,
    },
    WeaponArchetype.melee: {
      WeaponArchetype.pistol: 8,
      WeaponArchetype.rifle: 6,
      WeaponArchetype.sniper: 10,
      WeaponArchetype.shotgun: -8,
      WeaponArchetype.smg: -10,
      WeaponArchetype.explosive: 12,
    },
    WeaponArchetype.pistol: {
      WeaponArchetype.melee: -6,
      WeaponArchetype.smg: -5,
      WeaponArchetype.rifle: 5,
      WeaponArchetype.shotgun: 3,
      WeaponArchetype.sniper: 8,
      WeaponArchetype.explosive: 9,
    },
    WeaponArchetype.smg: {
      WeaponArchetype.melee: 7,
      WeaponArchetype.pistol: 5,
      WeaponArchetype.shotgun: -7,
      WeaponArchetype.rifle: -4,
      WeaponArchetype.sniper: 9,
      WeaponArchetype.explosive: 11,
    },
    WeaponArchetype.shotgun: {
      WeaponArchetype.melee: 9,
      WeaponArchetype.smg: 6,
      WeaponArchetype.pistol: -4,
      WeaponArchetype.rifle: -6,
      WeaponArchetype.sniper: 8,
      WeaponArchetype.explosive: 10,
    },
    WeaponArchetype.rifle: {
      WeaponArchetype.pistol: -5,
      WeaponArchetype.shotgun: 6,
      WeaponArchetype.smg: 4,
      WeaponArchetype.melee: -7,
      WeaponArchetype.sniper: -3,
      WeaponArchetype.explosive: 8,
    },
    WeaponArchetype.sniper: {
      WeaponArchetype.rifle: 4,
      WeaponArchetype.shotgun: -8,
      WeaponArchetype.smg: -9,
      WeaponArchetype.pistol: -6,
      WeaponArchetype.melee: -10,
      WeaponArchetype.explosive: 6,
    },
    WeaponArchetype.explosive: {
      WeaponArchetype.shotgun: 2,
      WeaponArchetype.rifle: -8,
      WeaponArchetype.sniper: -7,
      WeaponArchetype.smg: -10,
      WeaponArchetype.pistol: -9,
      WeaponArchetype.melee: -12,
    },
  };

  static const Map<String, int> _knifeTier = {
    'musta': 1,
    'caki': 2,
    'sopa': 3,
    'pala': 4,
  };

  static const Map<ArmorArchetype, int> _armorResist = {
    ArmorArchetype.none: 0,
    ArmorArchetype.leather: 3,
    ArmorArchetype.steel: 7,
    ArmorArchetype.heavy: 12,
  };

  static const Map<VehicleArchetype, int> _vehicleMobility = {
    VehicleArchetype.none: 0,
    VehicleArchetype.sedan: 3,
    VehicleArchetype.armored: 1,
    VehicleArchetype.sport: 5,
  };

  static const Map<VehicleArchetype, int> _vehicleCover = {
    VehicleArchetype.none: 0,
    VehicleArchetype.sedan: 2,
    VehicleArchetype.armored: 5,
    VehicleArchetype.sport: 1,
  };

  static const Map<WeaponArchetype, int> _weaponPenetration = {
    WeaponArchetype.unarmed: 0,
    WeaponArchetype.melee: 2,
    WeaponArchetype.pistol: 4,
    WeaponArchetype.smg: 5,
    WeaponArchetype.shotgun: 6,
    WeaponArchetype.rifle: 7,
    WeaponArchetype.sniper: 9,
    WeaponArchetype.explosive: 10,
  };

  static WeaponMatchupEffect evaluate({
    required String attackerWeaponId,
    required String targetWeaponId,
  }) {
    final atkType = archetypeFromWeaponId(attackerWeaponId);
    final defType = archetypeFromWeaponId(targetWeaponId);

    final powerPct = _advantage[atkType]?[defType] ?? 0;
    final atkSpeed = _speedTier[atkType] ?? 5;
    final defSpeed = _speedTier[defType] ?? 5;
    final speedPct = ((atkSpeed - defSpeed) * 2).clamp(-8, 8);
    final totalPct = (powerPct + speedPct).clamp(-20, 20);

    return WeaponMatchupEffect(
      attackerArchetype: atkType,
      targetArchetype: defType,
      powerPct: powerPct,
      speedPct: speedPct,
      totalPct: totalPct,
    );
  }

  static LoadoutMatchupEffect evaluateLoadout({
    required CombatLoadout attacker,
    required CombatLoadout target,
  }) {
    final weaponEffect = evaluate(
      attackerWeaponId: attacker.primaryWeaponId,
      targetWeaponId: target.primaryWeaponId,
    );

    final knifePct = _knifeEdge(attacker.knifeId, target.knifeId);
    final armorPct = _armorEdge(attacker: attacker, target: target);
    final vehiclePct = _vehicleEdge(attacker.vehicleId, target.vehicleId);

    final totalPct = (weaponEffect.totalPct + knifePct + armorPct + vehiclePct)
        .clamp(-35, 35);

    return LoadoutMatchupEffect(
      weaponPowerPct: weaponEffect.powerPct,
      weaponSpeedPct: weaponEffect.speedPct,
      weaponTotalPct: weaponEffect.totalPct,
      knifePct: knifePct,
      armorPct: armorPct,
      vehiclePct: vehiclePct,
      totalPct: totalPct,
    );
  }

  static int _knifeEdge(String attackerKnifeId, String targetKnifeId) {
    final atk = _knifeTier[attackerKnifeId] ?? 0;
    final def = _knifeTier[targetKnifeId] ?? 0;
    return ((atk - def) * 2).clamp(-8, 8);
  }

  static int _armorEdge({
    required CombatLoadout attacker,
    required CombatLoadout target,
  }) {
    final attackerType = archetypeFromWeaponId(attacker.primaryWeaponId);
    final attackerPen =
        (_weaponPenetration[attackerType] ?? 0) +
        (_knifeTier[attacker.knifeId] ?? 0);

    final targetArmorType = armorArchetypeFromId(target.armorId);
    final targetVehicleType = vehicleArchetypeFromId(target.vehicleId);
    final defenderMitigation =
        (_armorResist[targetArmorType] ?? 0) +
        (_vehicleCover[targetVehicleType] ?? 0);

    return (attackerPen - defenderMitigation).clamp(-12, 12);
  }

  static int _vehicleEdge(String attackerVehicleId, String targetVehicleId) {
    final atk =
        _vehicleMobility[vehicleArchetypeFromId(attackerVehicleId)] ?? 0;
    final def = _vehicleMobility[vehicleArchetypeFromId(targetVehicleId)] ?? 0;
    return ((atk - def) * 2).clamp(-8, 8);
  }

  static String defaultWeaponIdForPower(int power) {
    if (power >= 10000) return 'roketatar';
    if (power >= 5000) return 'c4_patlayici';
    if (power >= 900) return 'keskin_nisanci';
    if (power >= 650) return 'ak47';
    if (power >= 420) return 'pompali';
    if (power >= 260) return 'uzi';
    if (power >= 140) return 'tabanca_9mm';
    if (power >= 70) return 'pala';
    if (power >= 30) return 'sopa';
    if (power >= 14) return 'caki';
    return 'musta';
  }

  static String defaultKnifeIdForPower(int power) {
    if (power >= 140) return 'pala';
    if (power >= 80) return 'sopa';
    if (power >= 40) return 'caki';
    return 'musta';
  }

  static String defaultArmorIdForPower(int power) {
    if (power >= 3000) return 'juggernaut';
    if (power >= 240) return 'celik_yelek';
    if (power >= 20) return 'deri_ceket';
    return '';
  }

  static String defaultVehicleIdForPower(int power) {
    if (power >= 180) return 'klasik_araba_sv1';
    return '';
  }

  static WeaponArchetype archetypeFromWeaponId(String weaponId) {
    final id = weaponId.trim().toLowerCase();
    if (id.isEmpty) return WeaponArchetype.unarmed;

    switch (id) {
      case 'musta':
      case 'caki':
      case 'sopa':
      case 'pala':
        return WeaponArchetype.melee;
      case 'tabanca_9mm':
      case 'altin_deagle':
      case 'altipatlar':
        return WeaponArchetype.pistol;
      case 'uzi':
        return WeaponArchetype.smg;
      case 'pompali':
        return WeaponArchetype.shotgun;
      case 'ak47':
        return WeaponArchetype.rifle;
      case 'keskin_nisanci':
        return WeaponArchetype.sniper;
      case 'el_bombasi':
      case 'c4_patlayici':
      case 'roketatar':
        return WeaponArchetype.explosive;
      default:
        return WeaponArchetype.unarmed;
    }
  }

  static ArmorArchetype armorArchetypeFromId(String armorId) {
    switch (armorId.trim().toLowerCase()) {
      case 'deri_ceket':
        return ArmorArchetype.leather;
      case 'celik_yelek':
        return ArmorArchetype.steel;
      case 'juggernaut':
        return ArmorArchetype.heavy;
      default:
        return ArmorArchetype.none;
    }
  }

  static VehicleArchetype vehicleArchetypeFromId(String vehicleId) {
    switch (vehicleId.trim().toLowerCase()) {
      case 'klasik_araba_sv1':
        return VehicleArchetype.sedan;
      default:
        return VehicleArchetype.none;
    }
  }

  static ItemDef? itemById(String itemId) {
    for (final item in StaticData.shopItems) {
      if (item.id == itemId) return item;
    }
    return null;
  }
}
