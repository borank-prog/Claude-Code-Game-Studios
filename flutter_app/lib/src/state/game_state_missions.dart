// ignore_for_file: curly_braces_in_flow_control_structures

part of 'game_state.dart';

mixin _GameStateMissions on _GameStateBase {
  Future<String> claimDailyTask(String taskId) async {
    _ensureDailyState();
    if (!_GameStateBase._dailyTargets.containsKey(taskId)) {
      return tt('Geçersiz görev.', 'Invalid task.');
    }
    if (dailyClaimed[taskId] == true) {
      return tt('Bu ödül zaten alındı.', 'Reward already claimed.');
    }
    final target = _GameStateBase._dailyTargets[taskId]!;
    final progress = dailyProgress[taskId] ?? 0;
    if (progress < target) {
      return tt('Görev henüz tamamlanmadı.', 'Task is not complete yet.');
    }

    final rewardCash = _GameStateBase._dailyRewardCash[taskId] ?? 0;
    cash += rewardCash;
    dailyClaimed[taskId] = true;
    _queueEvent('daily_task_claim', {
      'taskId': taskId,
      'rewardCash': rewardCash,
    });
    _addNews(
      tt('Günlük Ödül', 'Daily Reward'),
      tt(
        '+\$$rewardCash günlük görev ödülü aldın.',
        'You claimed +\$$rewardCash daily reward.',
      ),
    );
    await _save();
    notifyListeners();
    return tt('Ödül alındı: +\$$rewardCash', 'Reward claimed: +\$$rewardCash');
  }

  Future<String> claimDailyLoginReward() async {
    _ensureDailyState();
    if (dailyLoginClaimed) {
      return tt(
        'Bugünün giriş ödülü zaten alındı.',
        'Today login reward already claimed.',
      );
    }

    final cashReward = 300 + (dailyStreak * 200);
    final goldReward = dailyStreak % 3 == 0 ? 5 : 0;
    cash += cashReward;
    if (goldReward > 0) gold += goldReward;
    dailyLoginClaimed = true;
    _queueEvent('daily_login_claim', {
      'streak': dailyStreak,
      'cash': cashReward,
      'gold': goldReward,
    });
    _addNews(
      tt('Giriş Ödülü', 'Login Reward'),
      tt(
        'Seri $dailyStreak: +\$$cashReward${goldReward > 0 ? ' + $goldReward Altın' : ''}',
        'Streak $dailyStreak: +\$$cashReward${goldReward > 0 ? ' + $goldReward Gold' : ''}',
      ),
    );
    await _save();
    notifyListeners();
    return tt(
      'Giriş ödülü: +\$$cashReward${goldReward > 0 ? ' ve +$goldReward Altın' : ''}',
      'Login reward: +\$$cashReward${goldReward > 0 ? ' and +$goldReward Gold' : ''}',
    );
  }

  Future<MissionResult> completeMission(MissionDef mission) async {
    final powerBefore = totalPower;
    _applyOfflineRegeneration();
    if (jailSecondsLeft > 0) {
      return MissionResult(
        success: false,
        message: tt(
          'Hapistesin. Önce çıkmalısın.',
          'You are in jail. Get out first.',
        ),
        powerBefore: powerBefore,
        powerAfter: totalPower,
        nextAction: tt(
          'Hapisten çıkmak için Altın öde veya bekle.',
          'Pay gold or wait to exit jail.',
        ),
        sentToJail: true,
      );
    }
    if (isHospitalized) {
      return MissionResult(
        success: false,
        message: tt(
          'Hastanedesin. İyileşmeyi bekle.',
          'You are in hospital. Wait until recovery.',
        ),
        powerBefore: powerBefore,
        powerAfter: totalPower,
        nextAction: tt(
          'VIP Tedavi ile anında çıkabilirsin.',
          'Use VIP heal to recover instantly.',
        ),
        sentToHospital: true,
      );
    }
    if (currentEnerji < mission.staminaCost) {
      return MissionResult(
        success: false,
        message: tt('Yeterli enerjin yok.', 'Not enough energy.'),
        powerBefore: powerBefore,
        powerAfter: totalPower,
        nextAction: tt(
          'Enerji için bekle veya Adrenalin al.',
          'Wait for energy or buy Adrenaline.',
        ),
      );
    }

    currentEnerji = max(0, currentEnerji - mission.staminaCost);
    _syncLegacyEnergyFields();
    _metricAdd('mission_attempts_total', 1);
    _metricAdd('mission_attempts_${mission.difficulty}', 1);
    _metricAdd('mission_energy_spent_total', mission.staminaCost);
    final successChance = (mission.successRate + avatar.missionSuccessBonus)
        .clamp(0.05, 0.98);
    final success = _rng.nextDouble() <= successChance;

    if (success) {
      _metricAdd('mission_success_total', 1);
      _metricAdd('mission_success_${mission.difficulty}', 1);
      final reward =
          mission.rewardMin +
          _rng.nextInt(max(1, mission.rewardMax - mission.rewardMin + 1));
      final finalReward =
          (reward * avatar.missionCashMult * vehicleMissionCashMult).round();
      final bonusCash = max(0, finalReward - reward);
      const territoryBonusCash = 0;
      cash += finalReward;
      _grantXp(mission.xp);
      _metricAdd('mission_cash_earned_total', finalReward);
      _metricAdd('mission_xp_earned_total', mission.xp);
      _trackDaily('missions_completed', 1);
      _trackDaily('cash_earned', finalReward);
      trackAchievement('total_cash_earned', finalReward);
      _queueEvent('mission_success', {
        'missionId': mission.id,
        'cash': finalReward,
        'xp': mission.xp,
      });
      _addNews(
        tt('Görev Başarılı', 'Mission Success'),
        tt(
          '${missionName(mission)} tamamlandı: +\$$finalReward, +${mission.xp} XP',
          '${missionName(mission)} completed: +\$$finalReward, +${mission.xp} XP',
        ),
      );
      await _save();
      _syncOnlineSoon();
      notifyListeners();
      final powerAfter = totalPower;
      return MissionResult(
        success: true,
        message: tt('Görev başarılı.', 'Mission successful.'),
        cashEarned: finalReward,
        xpEarned: mission.xp,
        baseCash: reward,
        bonusCash: bonusCash,
        territoryBonusCash: territoryBonusCash,
        powerBefore: powerBefore,
        powerAfter: powerAfter,
        nextAction: currentEnerji >= mission.staminaCost
            ? tt(
                'Enerjin yeterli, bir görev daha deneyebilirsin.',
                'Energy is enough, try one more mission.',
              )
            : tt(
                'Enerjin düştü. Şehir veya market ekranına göz at.',
                'Energy is low. Check city or market next.',
              ),
      );
    }

    final missionId = mission.id.toLowerCase();
    final isRobberyMission =
        missionId.contains('market') ||
        missionId.contains('kuyumcu') ||
        missionId.contains('banka') ||
        missionId.contains('depo') ||
        missionId.contains('soygun') ||
        missionId.contains('vurgun') ||
        missionId.contains('baskin');
    final failureToJail = isRobberyMission || mission.difficulty != 'hard';
    _metricAdd('mission_fail_total', 1);
    _metricAdd('mission_fail_${mission.difficulty}', 1);
    final failCashPenalty = switch (mission.difficulty) {
      'easy' => 90,
      'medium' => 220,
      'hard' => 500,
      _ => 120,
    };
    cash = max(0, cash - failCashPenalty);
    _metricAdd('mission_cash_lost_total', failCashPenalty);
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (failureToJail) {
      final failXp = max(2, (mission.xp * _GameStateBase._missionFailXpRatio).round());
      _grantXp(failXp);
      _metricAdd('mission_xp_earned_total', failXp);
      jailUntilEpoch = now + _GameStateBase._penaltyDurationSec;
      _metricAdd('jail_entries_total', 1);
      _addNews(
        tt('Kodese Tıkıldın', 'Thrown in Jail'),
        tt(
          '${missionName(mission)} ters gitti. \$$failCashPenalty kaybettin.',
          '${missionName(mission)} went wrong. You lost \$$failCashPenalty.',
        ),
      );
      _queueEvent('mission_fail_jail', {'missionId': mission.id});
      await _save();
      _syncOnlineSoon();
      notifyListeners();
      return MissionResult(
        success: false,
        message: tt(
          'Yakalandın! Hapistesin.',
          'You got caught! You are in jail.',
        ),
        xpEarned: failXp,
        powerBefore: powerBefore,
        powerAfter: totalPower,
        nextAction: tt(
          'Hemen çıkmak için $jailSkipGoldCost Altın öde veya $penaltyDurationMinutes dakika bekle.',
          'Pay $jailSkipGoldCost Gold to leave now or wait $penaltyDurationMinutes minutes.',
        ),
        sentToJail: true,
      );
    }

    final failXp = max(2, (mission.xp * 0.2).round());
    _grantXp(failXp);
    _metricAdd('mission_xp_earned_total', failXp);
    hospitalUntilEpoch = max(
      hospitalUntilEpoch,
      now + _GameStateBase._penaltyDurationSec,
    );
    _metricAdd('hospital_entries_total', 1);
    currentTP = max(0, currentTP - 45);
    _addNews(
      tt('Hastanelik Oldun', 'Hospitalized'),
      tt(
        '${missionName(mission)} sırasında ağır yaralandın. \$$failCashPenalty kaybettin.',
        'You were badly injured during ${missionName(mission)}. You lost \$$failCashPenalty.',
      ),
    );
    _queueEvent('mission_fail_hospital', {'missionId': mission.id});
    await _save();
    _syncOnlineSoon();
    notifyListeners();
    return MissionResult(
      success: false,
      message: tt(
        'Bozguna uğradın, hastaneye kaldırıldın.',
        'You were defeated and taken to hospital.',
      ),
      xpEarned: failXp,
      powerBefore: powerBefore,
      powerAfter: totalPower,
      nextAction: tt(
        'Hemen çıkmak için $hospitalSkipGoldCost Altın öde veya $penaltyDurationMinutes dakika bekle.',
        'Pay $hospitalSkipGoldCost Gold to leave now or wait $penaltyDurationMinutes minutes.',
      ),
      sentToHospital: true,
    );
  }

  Future<void> payHospitalWithGold() async {
    final sec = hospitalSecondsLeft;
    if (sec <= 0) return;
    final cost = hospitalSkipGoldCost;
    if (gold < cost) return;
    gold -= cost;
    _metricAdd('hospital_skip_gold_spent_total', cost);
    hospitalUntilEpoch = 0;
    if (currentTP <= 0) {
      currentTP = 35;
    }
    _queueEvent('hospital_skip', {'cost': cost});
    await _save();
    _syncOnlineSoon();
    notifyListeners();
  }

  Future<void> payJailWithGold() async {
    final sec = jailSecondsLeft;
    if (sec <= 0) return;
    final cost = jailSkipGoldCost;
    if (gold < cost) return;
    gold -= cost;
    _metricAdd('jail_skip_gold_spent_total', cost);
    jailUntilEpoch = 0;
    _queueEvent('jail_skip', {'cost': cost});
    await _save();
    _syncOnlineSoon();
    notifyListeners();
  }
}
