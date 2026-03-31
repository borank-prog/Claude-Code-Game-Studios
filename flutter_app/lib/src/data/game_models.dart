class AvatarClass {
  const AvatarClass({
    required this.id,
    required this.name,
    required this.portraitAsset,
    required this.cardAsset,
    required this.powerMult,
    required this.missionSuccessBonus,
    required this.missionCashMult,
  });

  final String id;
  final String name;
  final String portraitAsset;
  final String cardAsset;
  final double powerMult;
  final double missionSuccessBonus;
  final double missionCashMult;
}

class ItemDef {
  const ItemDef({
    required this.id,
    required this.name,
    required this.type,
    required this.powerBonus,
    required this.costCash,
    required this.costGold,
    required this.reqLevel,
    required this.iconAsset,
  });

  final String id;
  final String name;
  final String type;
  final int powerBonus;
  final int costCash;
  final int costGold;
  final int reqLevel;
  final String iconAsset;
}

class MissionDef {
  const MissionDef({
    required this.id,
    required this.name,
    required this.difficulty,
    required this.staminaCost,
    required this.rewardMin,
    required this.rewardMax,
    required this.xp,
    required this.successRate,
  });

  final String id;
  final String name;
  final String difficulty;
  final int staminaCost;
  final int rewardMin;
  final int rewardMax;
  final int xp;
  final double successRate;
}

class BuildingDef {
  const BuildingDef({
    required this.id,
    required this.name,
    required this.costCash,
    required this.costGold,
    required this.hourlyIncome,
  });

  final String id;
  final String name;
  final int costCash;
  final int costGold;
  final int hourlyIncome;
}

class MissionResult {
  const MissionResult({
    required this.success,
    required this.message,
    this.cashEarned = 0,
    this.xpEarned = 0,
    this.baseCash = 0,
    this.bonusCash = 0,
    this.territoryBonusCash = 0,
    this.powerBefore = 0,
    this.powerAfter = 0,
    this.nextAction = '',
    this.sentToJail = false,
    this.sentToHospital = false,
  });

  final bool success;
  final String message;
  final int cashEarned;
  final int xpEarned;
  final int baseCash;
  final int bonusCash;
  final int territoryBonusCash;
  final int powerBefore;
  final int powerAfter;
  final String nextAction;
  final bool sentToJail;
  final bool sentToHospital;
}
