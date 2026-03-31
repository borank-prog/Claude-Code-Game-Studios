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
      final progress = _achievementProgress(def);
      if (progress >= def.target) {
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

  /// Returns progress ratio (0.0-1.0) for display
  double achievementRatio(AchievementDef def) {
    if (def.target <= 0) return 1.0;
    return (_achievementProgress(def) / def.target).clamp(0.0, 1.0);
  }

  /// Returns the current progress value
  int achievementProgressValue(AchievementDef def) {
    return _achievementProgress(def);
  }

  bool isAchievementUnlocked(String id) =>
      unlockedAchievements.contains(id) || claimedAchievements.contains(id);

  bool isAchievementClaimed(String id) => claimedAchievements.contains(id);

  Future<String> claimAchievement(String id) async {
    if (claimedAchievements.contains(id)) {
      return tt('Bu odulu zaten aldin.', 'Already claimed this reward.');
    }
    if (!unlockedAchievements.contains(id)) {
      return tt('Basarim henuz acilmadi.', 'Achievement not unlocked yet.');
    }
    final def = AchievementData.getById(id);
    if (def == null) {
      return tt('Gecersiz basarim.', 'Invalid achievement.');
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
    _addNews(
      tt('Odul Alindi', 'Reward Claimed'),
      tt(
        '${def.titleTr}: +\$${def.rewardCash}${def.rewardGold > 0 ? ' +${def.rewardGold} Altin' : ''}',
        '${def.titleEn}: +\$${def.rewardCash}${def.rewardGold > 0 ? ' +${def.rewardGold} Gold' : ''}',
      ),
    );
    await _save();
    _syncOnlineSoon();
    notifyListeners();
    return tt(
      'Odul alindi! +\$${def.rewardCash}${def.rewardGold > 0 ? ' +${def.rewardGold} Altin' : ''}',
      'Reward claimed! +\$${def.rewardCash}${def.rewardGold > 0 ? ' +${def.rewardGold} Gold' : ''}',
    );
  }

  int get unclaimedAchievementCount => unlockedAchievements.length;
}
