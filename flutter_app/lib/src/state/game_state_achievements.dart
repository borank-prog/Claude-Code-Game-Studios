// ignore_for_file: curly_braces_in_flow_control_structures

part of 'game_state.dart';

mixin _GameStateAchievements on _GameStateBase {
  // Achievement progress is tracked by metric keys mapped to achievement IDs.
  // The mapping is defined in checkAchievements().

  /// Called after actions that may unlock achievements.
  @override
  void checkAchievements() {
    final defs = AchievementData.all;
    for (final def in defs) {
      if (unlockedAchievements.contains(def.id)) continue;
      if (claimedAchievements.contains(def.id)) continue;
      if (_isAchievementCompleted(def)) {
        unlockedAchievements.add(def.id);
        _addNews(
          tt('Basarim Acildi!', 'Achievement Unlocked!'),
          tt(def.titleTr, def.titleEn),
        );
      }
    }
  }

  int _achievementProgress(AchievementDef def) {
    switch (def.id) {
      // Combat
      case 'first_blood':
      case 'street_fighter':
      case 'war_machine':
      case 'legend':
        return achievementCounters['battles_won'] ?? 0;
      case 'power_50':
      case 'power_1000':
        return totalPower;

      // Missions
      case 'mission_rookie':
      case 'mission_veteran':
      case 'mission_master':
        return balanceMetrics['mission_success_total'] ?? 0;
      case 'hard_mode':
        return balanceMetrics['mission_success_hard'] ?? 0;
      case 'level_10':
      case 'level_25':
        return level;

      // Economy
      case 'first_million':
        return achievementCounters['total_cash_earned'] ?? 0;
      case 'property_owner':
      case 'real_estate_mogul':
        return ownedBuildings.length;
      case 'collector':
        return ownedItems.length;

      // Social
      case 'gang_member':
        return hasGang ? 1 : 0;
      case 'gang_raider':
        return achievementCounters['gang_raids_joined'] ?? 0;
      case 'streak_master':
        return dailyStreak;

      default:
        return 0;
    }
  }

  bool _isAchievementCompleted(AchievementDef def) {
    return _achievementProgress(def) >= def.target;
  }

  /// Returns progress ratio (0.0-1.0) for display
  double achievementRatio(AchievementDef def) {
    if (def.target <= 0) return 1.0;
    return (_achievementProgress(def) / def.target).clamp(0.0, 1.0);
  }

  /// Returns the current progress value
  int achievementProgressValue(AchievementDef def) {
    return _achievementProgress(def);
  }

  bool isAchievementUnlocked(String id) {
    if (claimedAchievements.contains(id)) return true;
    if (unlockedAchievements.contains(id)) return true;
    final def = AchievementData.getById(id);
    if (def == null) return false;
    return _isAchievementCompleted(def);
  }

  bool isAchievementClaimed(String id) => claimedAchievements.contains(id);

  Future<String> claimAchievement(String id) async {
    if (claimedAchievements.contains(id)) {
      return tt('Bu odulu zaten aldin.', 'Already claimed this reward.');
    }
    final def = AchievementData.getById(id);
    if (def == null) {
      return tt('Gecersiz basarim.', 'Invalid achievement.');
    }
    // Defensive unlock: progress hedefe ulasmissa ama unlock seti gec kaldiysa
    // oyuncunun odulu kilitli kalmasin.
    if (!unlockedAchievements.contains(id) && _isAchievementCompleted(def)) {
      unlockedAchievements.add(id);
    }
    if (!unlockedAchievements.contains(id)) {
      return tt('Basarim henuz acilmadi.', 'Achievement not unlocked yet.');
    }

    unlockedAchievements.remove(id);
    claimedAchievements.add(id);

    if (def.rewardCash > 0) cash += def.rewardCash;
    if (def.rewardGold > 0) gold += def.rewardGold;
    if (def.rewardXp > 0) _grantXp(def.rewardXp);

    _queueEvent('achievement_claim', {
      'achievementId': id,
      'cash': def.rewardCash,
      'gold': def.rewardGold,
      'xp': def.rewardXp,
    });
    final rewardPartsTr = <String>[];
    final rewardPartsEn = <String>[];
    if (def.rewardCash > 0) {
      rewardPartsTr.add('+\$${def.rewardCash}');
      rewardPartsEn.add('+\$${def.rewardCash}');
    }
    if (def.rewardGold > 0) {
      rewardPartsTr.add('+${def.rewardGold} Altin');
      rewardPartsEn.add('+${def.rewardGold} Gold');
    }
    if (def.rewardXp > 0) {
      rewardPartsTr.add('+${def.rewardXp} XP');
      rewardPartsEn.add('+${def.rewardXp} XP');
    }
    final rewardSummaryTr = rewardPartsTr.isEmpty
        ? '-'
        : rewardPartsTr.join(' ');
    final rewardSummaryEn = rewardPartsEn.isEmpty
        ? '-'
        : rewardPartsEn.join(' ');

    _addNews(
      tt('Odul Alindi', 'Reward Claimed'),
      tt(
        '${def.titleTr}: $rewardSummaryTr',
        '${def.titleEn}: $rewardSummaryEn',
      ),
    );
    await _save();
    _syncOnlineSoon();
    notifyListeners();
    return tt(
      'Odul alindi! $rewardSummaryTr',
      'Reward claimed! $rewardSummaryEn',
    );
  }

  int get unclaimedAchievementCount {
    var count = 0;
    for (final def in AchievementData.all) {
      if (claimedAchievements.contains(def.id)) continue;
      if (_isAchievementCompleted(def)) count++;
    }
    return count;
  }
}
