import 'dart:math';

import '../data/gang_model.dart';
import '../data/player_model.dart';

class SoloCombatResult {
  const SoloCombatResult({
    required this.executed,
    required this.win,
    required this.report,
    required this.stolenCash,
    required this.penaltyCash,
    required this.attackerDamage,
    required this.defenderDamage,
    required this.attackCost,
  });

  final bool executed;
  final bool win;
  final String report;
  final int stolenCash;
  final int penaltyCash;
  final int attackerDamage;
  final int defenderDamage;
  final int attackCost;
}

class GangCombatResult {
  const GangCombatResult({
    required this.win,
    required this.report,
    required this.respectGained,
  });

  final bool win;
  final String report;
  final int respectGained;
}

class CombatService {
  final Random _random = Random();
  final int _attackCost = 20;

  SoloCombatResult executeSoloAttack({
    required Player attacker,
    required Player defender,
  }) {
    if (attacker.isHospitalized) {
      return const SoloCombatResult(
        executed: false,
        win: false,
        report: '⛔ Patron, hastaneliksin! Önce yaralarını sar.',
        stolenCash: 0,
        penaltyCash: 0,
        attackerDamage: 0,
        defenderDamage: 0,
        attackCost: 0,
      );
    }

    if (!attacker.hasEnoughEnergyForAttack) {
      return const SoloCombatResult(
        executed: false,
        win: false,
        report:
            '⛔ Çok yorgunsun, saldıracak kondisyonun yok (Enerji yetersiz).',
        stolenCash: 0,
        penaltyCash: 0,
        attackerDamage: 0,
        defenderDamage: 0,
        attackCost: 0,
      );
    }

    if (defender.isHospitalized) {
      return const SoloCombatResult(
        executed: false,
        win: false,
        report: '⛔ Savunan hastanelik, onu şu an ezemezsin.',
        stolenCash: 0,
        penaltyCash: 0,
        attackerDamage: 0,
        defenderDamage: 0,
        attackCost: 0,
      );
    }

    if (defender.hasShield) {
      return const SoloCombatResult(
        executed: false,
        win: false,
        report: '🛡️ Hedef VIP Koruma Kalkanı altında. Saldırı engellendi.',
        stolenCash: 0,
        penaltyCash: 0,
        attackerDamage: 0,
        defenderDamage: 0,
        attackCost: 0,
      );
    }

    attacker.currentEnerji = max(0, attacker.currentEnerji - _attackCost);

    final attackerScore = attacker.power + _random.nextInt(50);
    final defenderScore = defender.power + _random.nextInt(50);

    if (attackerScore > defenderScore) {
      final attackerDamage = _random.nextInt(10) + 5;
      final defenderDamage = _random.nextInt(20) + 20;

      attacker.currentTP = max(0, attacker.currentTP - attackerDamage);
      defender.currentTP = max(0, defender.currentTP - defenderDamage);

      // Scale stolen cash based on power gap: weaker target = less reward
      final powerGap = (attacker.power - defender.power).clamp(-500, 500);
      final baseSteal = _random.nextInt(100) + 50;
      final gapBonus = (powerGap < 0 ? (-powerGap * 0.4) : (powerGap * -0.15)).toInt();
      final stolenCash = max(10, baseSteal + gapBonus);
      attacker.cash += stolenCash;
      defender.cash = max(0, defender.cash - stolenCash);

      if (!defender.isOnline) {
        defender.offlineLogs.add(
          '⚠️ KARTEL RAPORU: Sen yokken ${attacker.name} sana saldırdı. '
          '$defenderDamage TP hasarı aldın ve \$$stolenCash paran çalındı!',
        );
      }

      return SoloCombatResult(
        executed: true,
        win: true,
        report:
            'ZAFER! ${defender.name} ezildi. '
            'Sen -$attackerDamage TP, rakip -$defenderDamage TP. '
            'Ganimet: \$$stolenCash.',
        stolenCash: stolenCash,
        penaltyCash: 0,
        attackerDamage: attackerDamage,
        defenderDamage: defenderDamage,
        attackCost: _attackCost,
      );
    }

    const penalty = 25;
    final attackerDamage = _random.nextInt(30) + 30;
    final defenderDamage = _random.nextInt(15) + 5;

    attacker.currentTP = max(0, attacker.currentTP - attackerDamage);
    defender.currentTP = max(0, defender.currentTP - defenderDamage);
    attacker.cash = max(0, attacker.cash - penalty);

    if (!defender.isOnline) {
      defender.offlineLogs.add(
        '🛡️ SAVUNMA ZAFERİ: Sen yokken ${attacker.name} saldırdı '
        'ama püskürttün. $defenderDamage TP hasarı aldın.',
      );
    }

    return SoloCombatResult(
      executed: true,
      win: false,
      report:
          'BOZGUN! ${defender.name} savundu. '
          'Sen -$attackerDamage TP, rakip -$defenderDamage TP. '
          'Masraf: \$$penalty.',
      stolenCash: 0,
      penaltyCash: penalty,
      attackerDamage: attackerDamage,
      defenderDamage: defenderDamage,
      attackCost: _attackCost,
    );
  }

  GangCombatResult gangAttack({
    required Gang attackingGang,
    required Gang defendingGang,
  }) {
    final attackScore = attackingGang.totalGangPower + _random.nextInt(200);
    final defendScore = defendingGang.totalGangPower + _random.nextInt(200);

    if (attackScore > defendScore) {
      attackingGang.respectPoints += 100;
      return GangCombatResult(
        win: true,
        report:
            '${attackingGang.name} Sokakların Hakimi! ${defendingGang.name} geri çekildi.',
        respectGained: 100,
      );
    }

    return GangCombatResult(
      win: false,
      report: '${defendingGang.name} bölgeyi savundu. Ağır kayıplar verdiniz.',
      respectGained: 0,
    );
  }
}
