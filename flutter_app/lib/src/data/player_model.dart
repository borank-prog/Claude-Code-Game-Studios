class Player {
  Player({
    required this.id,
    required this.name,
    this.playerRank = 1,
    this.power = 10,
    this.cash = 1000,
    this.gold = 0,
    this.maxTP = 100,
    this.currentTP = 100,
    this.maxEnerji = 100,
    this.currentEnerji = 100,
    this.shieldUntilEpoch = 0,
    this.isOnline = false,
    List<String>? offlineLogs,
    this.lastRegenCheck,
    this.hospitalizedUntil,
    this.gangId,
  }) : offlineLogs = offlineLogs ?? [];

  final String id;
  final String name;
  int playerRank;
  int power;
  int cash;
  int gold;
  int maxTP;
  int currentTP;
  int maxEnerji;
  int currentEnerji;
  int shieldUntilEpoch;
  bool isOnline;
  List<String> offlineLogs;
  DateTime? lastRegenCheck;
  DateTime? hospitalizedUntil;
  String? gangId;

  bool get isHospitalized {
    if (currentTP <= 0) return true;
    if (hospitalizedUntil == null) return false;
    return hospitalizedUntil!.isAfter(DateTime.now());
  }

  bool get hasEnoughEnergyForAttack => currentEnerji >= 20;

  bool get hasShield =>
      shieldUntilEpoch > DateTime.now().millisecondsSinceEpoch ~/ 1000;
}
