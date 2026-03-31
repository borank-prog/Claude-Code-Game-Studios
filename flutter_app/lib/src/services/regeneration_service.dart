import '../data/player_model.dart';

class RegenerationService {
  final int _tpRegenPerMinute = 1;
  final int _energyRegenPerMinute = 5;

  void applyOfflineRegeneration(Player me) {
    final now = DateTime.now();
    me.lastRegenCheck ??= now;

    final minutesPassed = now.difference(me.lastRegenCheck!).inMinutes;
    if (minutesPassed <= 0) return;

    final energyToRegen = minutesPassed * _energyRegenPerMinute;
    me.currentEnerji += energyToRegen;
    if (me.currentEnerji > me.maxEnerji) {
      me.currentEnerji = me.maxEnerji;
    }

    if (me.currentTP < me.maxTP) {
      final tpToRegen = minutesPassed * _tpRegenPerMinute;
      me.currentTP += tpToRegen;
      if (me.currentTP > me.maxTP) {
        me.currentTP = me.maxTP;
      }
    }

    me.lastRegenCheck = now;

    if (me.currentTP >= me.maxTP) {
      me.hospitalizedUntil = null;
    }
  }
}
