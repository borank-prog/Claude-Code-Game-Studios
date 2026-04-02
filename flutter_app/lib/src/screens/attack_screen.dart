import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/game_state.dart';
import '../services/weapon_matchup_service.dart';
import '../services/attack_history_service.dart';
import '../models/attack_result.dart';
import '../models/attack_type.dart';
import '../widgets/game_background.dart';
import 'attack_confirm_sheet.dart';

class AttackScreen extends StatefulWidget {
  const AttackScreen({super.key});

  @override
  State<AttackScreen> createState() => _AttackScreenState();
}

class _AttackScreenState extends State<AttackScreen>
    with SingleTickerProviderStateMixin {
  static const List<String> _seedGangs = [
    'Kuzey Kurtları',
    'Gece Baronları',
    'Demir Yumruk',
    'Kızıl Kartel',
  ];

  final Map<String, _RivalVm> _rivalsById = <String, _RivalVm>{};
  final Random _simRandom = Random();
  final _historySvc = AttackHistoryService();
  String _battleReport = '';
  bool _busy = false;
  Timer? _botArenaTimer;
  late AnimationController _flashController;
  Color _flashColor = Colors.transparent;
  String? _lastAttackTargetId;

  // Cache to avoid rebuilding rivals on every GameState notification
  int _lastRowsLength = -1;
  String _lastMyName = '';
  List<_RivalVm> _cachedRivals = const [];

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _botArenaTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _simulateBotArena();
    });
  }

  @override
  void dispose() {
    _botArenaTimer?.cancel();
    _flashController.dispose();
    super.dispose();
  }

  void _triggerFlash(Color color, String targetId) {
    _flashColor = color;
    _lastAttackTargetId = targetId;
    _flashController.forward(from: 0);
  }

  Future<void> _showActionLockedPopup(GameState state) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111a2e),
        title: Text(
          state.actionLockTitle,
          style: const TextStyle(
            color: Color(0xFFEF4444),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '${state.actionLockMessage}\n\n${state.tt('Kalan Süre', 'Time Left')}: ${_clock(state.actionLockSecondsLeft)}',
          style: const TextStyle(color: Color(0xFFD1D5DB)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(state.tt('Tamam', 'OK')),
          ),
        ],
      ),
    );
  }

  String _clock(int sec) {
    final s = sec.clamp(0, 999999);
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  List<_RivalVm> _fallbackRivals() {
    const names = <String>[
      'Kurt_Memo',
      'Tetikci_Orhan',
      'Baron_Ali',
      'Racon_Selim',
      'Gece_Kargasi',
      'Sokak_Vurgun',
      'Golge',
      'Kasirga_Han',
      'Kral_Panzer',
      'Don_Marco',
      'Mafya_Cem',
      'Demir_Yusuf',
      'Silahsor_Apo',
      'Karanlik_Tolga',
      'Bicakci_Erdem',
      'Bela_Burak',
      'Baba_Rasim',
      'Serseri_Cenk',
      'Reis_Tuna',
      'Vurguncu_Levent',
    ];

    final rng = Random();
    final rivals = <_RivalVm>[];
    for (var i = 0; i < names.length; i++) {
      final basePower = 180 + (i * 55);
      final variance = rng.nextInt(basePower ~/ 5 + 1) - basePower ~/ 10;
      final power = max(50, basePower + variance);
      final level = max(2, (power / 70).round());
      final baseCash = 2600 + (i * 850);
      final cash = max(100, baseCash + rng.nextInt(1000) - 500);
      final currentTP = rng.nextBool() ? 100 : (40 + rng.nextInt(61));
      final isOnline = rng.nextInt(3) != 0;
      rivals.add(
        _RivalVm(
          id: 'bot_${(i + 1).toString().padLeft(2, '0')}',
          name: names[i],
          power: power,
          cash: cash,
          level: level,
          gangName: _seedGangs[i ~/ 5],
          currentTP: currentTP,
          isOnline: isOnline,
          combatWeaponId: WeaponMatchupService.defaultWeaponIdForPower(power),
          knifeId: WeaponMatchupService.defaultKnifeIdForPower(power),
          armorId: WeaponMatchupService.defaultArmorIdForPower(power),
          vehicleId: WeaponMatchupService.defaultVehicleIdForPower(power),
        ),
      );
    }
    return rivals;
  }

  String _resolvedGangName(String rawGangName, int index) {
    final cleaned = rawGangName.trim();
    if (cleaned.isNotEmpty) return cleaned;
    return _seedGangs[index % _seedGangs.length];
  }

  List<_RivalVm> _buildRivals(GameState state) {
    final myNameLower = state.displayPlayerName.toLowerCase().trim();
    final rows = state.leaderboardRows;
    if (rows.length == _lastRowsLength &&
        myNameLower == _lastMyName &&
        _cachedRivals.isNotEmpty) {
      return _cachedRivals;
    }
    _lastRowsLength = rows.length;
    _lastMyName = myNameLower;

    final incoming = <_RivalVm>[];

    if (rows.isNotEmpty) {
      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        final name = (row['displayName']?.toString() ?? '').trim();
        if (name.isEmpty || name.toLowerCase() == myNameLower) {
          continue;
        }
        final id = (row['uid']?.toString() ?? '').trim().isEmpty
            ? 'lb_$i'
            : row['uid'].toString();
        final power = (row['power'] as num?)?.toInt() ?? 120 + (i * 70);
        // Legacy rows may miss "level"; keep fallback conservative so power
        // does not create unrealistically high visual level values.
        final level =
            (row['level'] as num?)?.toInt() ?? max(1, min(90, power ~/ 250));
        final cash = (row['cash'] as num?)?.toInt() ?? (350 + (power ~/ 2));
        final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final rawStatus = (row['status'] ?? 'active')
            .toString()
            .trim()
            .toLowerCase();
        final statusUntilEpoch =
            (row['statusUntilEpoch'] as num?)?.toInt() ?? 0;
        final status =
            (statusUntilEpoch > nowEpoch &&
                (rawStatus == 'hospital' || rawStatus == 'prison'))
            ? rawStatus
            : 'active';
        final currentTP = (row['currentTp'] as num?)?.toInt() ?? 100;
        final shield = (row['shieldUntilEpoch'] as num?)?.toInt() ?? 0;
        final combatWeaponId =
            (row['combatWeaponId']?.toString() ??
                    row['equippedWeaponId']?.toString() ??
                    row['equippedKnifeId']?.toString() ??
                    '')
                .trim();
        final knifeId = (row['equippedKnifeId']?.toString() ?? '').trim();
        final armorId = (row['equippedArmorId']?.toString() ?? '').trim();
        final vehicleId = (row['equippedVehicleId']?.toString() ?? '').trim();
        incoming.add(
          _RivalVm(
            id: id,
            name: name,
            power: max(1, power),
            cash: max(0, cash),
            level: max(1, level),
            gangName: _resolvedGangName(row['gangName']?.toString() ?? '', i),
            currentTP: currentTP.clamp(0, 100),
            status: status,
            statusUntilEpoch: statusUntilEpoch,
            shieldUntilEpoch: shield,
            isOnline: row['online'] == true,
            combatWeaponId: combatWeaponId.isEmpty
                ? WeaponMatchupService.defaultWeaponIdForPower(power)
                : combatWeaponId,
            knifeId: knifeId.isEmpty
                ? WeaponMatchupService.defaultKnifeIdForPower(power)
                : knifeId,
            armorId: armorId.isEmpty
                ? WeaponMatchupService.defaultArmorIdForPower(power)
                : armorId,
            vehicleId: vehicleId.isEmpty
                ? WeaponMatchupService.defaultVehicleIdForPower(power)
                : vehicleId,
          ),
        );
      }
    }

    final fallback = _fallbackRivals();
    if (incoming.isEmpty) {
      incoming.addAll(fallback);
    } else if (incoming.length < 20) {
      final existingIds = incoming.map((r) => r.id).toSet();
      for (final bot in fallback) {
        if (existingIds.contains(bot.id)) continue;
        incoming.add(bot);
        if (incoming.length >= 20) break;
      }
    }

    for (final rival in incoming) {
      final local = _rivalsById[rival.id];
      if (local == null) {
        _rivalsById[rival.id] = rival;
      } else {
        _rivalsById[rival.id] = rival.copyWith(
          power: local.power,
          level: local.level,
          currentTP: local.currentTP,
          cash: local.cash,
          combatWeaponId: rival.combatWeaponId,
          knifeId: rival.knifeId,
          armorId: rival.armorId,
          vehicleId: rival.vehicleId,
        );
      }
    }

    final validIds = incoming.map((e) => e.id).toSet();
    _rivalsById.removeWhere((key, _) => !validIds.contains(key));
    _cachedRivals = _rivalsById.values.toList(growable: false);
    return _cachedRivals;
  }

  void _simulateBotArena() {
    if (!mounted || _busy || _rivalsById.length < 2) return;
    final state = context.read<GameState>();

    // Only simulate bots — real players are excluded from the arena simulation.
    final bots = _rivalsById.values
        .where((r) => r.id.startsWith('bot_'))
        .toList(growable: false);
    if (bots.length < 2) return;

    // Passive economy tick so bots keep progressing like live players.
    for (final rival in bots) {
      final passiveIncome = 35 + _simRandom.nextInt(120);
      _rivalsById[rival.id] = rival.copyWith(cash: rival.cash + passiveIncome);
    }

    final down = bots.where((r) => r.currentTP <= 0).toList(growable: false);
    if (down.isNotEmpty && _simRandom.nextDouble() < 0.35) {
      final recovered = down[_simRandom.nextInt(down.length)];
      _rivalsById[recovered.id] = recovered.copyWith(
        currentTP: 70 + _simRandom.nextInt(31),
        power: max(1, recovered.power - _simRandom.nextInt(2)),
      );
      setState(() {
        _battleReport = state.tt(
          '🩹 ${recovered.name} hastaneden çıktı.',
          '🩹 ${recovered.name} recovered and is back.',
        );
      });
      return;
    }

    final active = bots.where((r) => r.currentTP > 0).toList(growable: false);
    if (active.length < 2) return;

    final attacker = active[_simRandom.nextInt(active.length)];
    final crossGang = active
        .where((r) => r.id != attacker.id && r.gangName != attacker.gangName)
        .toList(growable: false);
    final sameGang = active
        .where((r) => r.id != attacker.id && r.gangName == attacker.gangName)
        .toList(growable: false);
    final preferCrossGang =
        crossGang.isNotEmpty && _simRandom.nextDouble() < 0.8;
    final defenderPool = preferCrossGang
        ? crossGang
        : (sameGang.isNotEmpty
              ? sameGang
              : active
                    .where((r) => r.id != attacker.id)
                    .toList(growable: false));
    if (defenderPool.isEmpty) return;
    final defender = defenderPool[_simRandom.nextInt(defenderPool.length)];

    final powerGap = (attacker.power - defender.power).abs();
    final gapPenalty = powerGap > 260 ? (powerGap ~/ 12) : 0;
    final attackerMatchup = WeaponMatchupService.evaluateLoadout(
      attacker: CombatLoadout(
        weaponId: attacker.combatWeaponId,
        knifeId: attacker.knifeId,
        armorId: attacker.armorId,
        vehicleId: attacker.vehicleId,
      ),
      target: CombatLoadout(
        weaponId: defender.combatWeaponId,
        knifeId: defender.knifeId,
        armorId: defender.armorId,
        vehicleId: defender.vehicleId,
      ),
    );
    final defenderMatchup = WeaponMatchupService.evaluateLoadout(
      attacker: CombatLoadout(
        weaponId: defender.combatWeaponId,
        knifeId: defender.knifeId,
        armorId: defender.armorId,
        vehicleId: defender.vehicleId,
      ),
      target: CombatLoadout(
        weaponId: attacker.combatWeaponId,
        knifeId: attacker.knifeId,
        armorId: attacker.armorId,
        vehicleId: attacker.vehicleId,
      ),
    );

    final attackerScore =
        _applyPercent(
          max(1, attacker.power - gapPenalty),
          attackerMatchup.totalPct,
        ) +
        _simRandom.nextInt(180);
    final defenderScore =
        _applyPercent(defender.power, defenderMatchup.totalPct) +
        _simRandom.nextInt(180);
    final attackerWins = attackerScore >= defenderScore;

    final winner = attackerWins ? attacker : defender;
    final loser = attackerWins ? defender : attacker;
    final sameGangFight = attacker.gangName == defender.gangName;
    final baseDamage = sameGangFight ? 8 : 18;
    final damage = baseDamage + _simRandom.nextInt(24);
    final stolen = sameGangFight
        ? 0
        : (loser.cash <= 0 ? 0 : min(loser.cash, 90 + _simRandom.nextInt(260)));

    final winnerPowerGain = 1 + _simRandom.nextInt(sameGangFight ? 2 : 3);
    final loserPowerDrop = _simRandom.nextInt(2);

    final updatedWinner = winner.copyWith(
      cash: winner.cash + stolen,
      power: winner.power + winnerPowerGain,
    );
    final newLoserHp = max(0, loser.currentTP - damage);
    final updatedLoser = loser.copyWith(
      cash: max(0, loser.cash - stolen),
      currentTP: newLoserHp,
      power: max(1, loser.power - loserPowerDrop),
    );

    _rivalsById[updatedWinner.id] = updatedWinner;
    _rivalsById[updatedLoser.id] = updatedLoser;

    setState(() {
      if (sameGangFight) {
        _battleReport = state.tt(
          '🥊 ${updatedWinner.name} antrenmanda ${updatedLoser.name} karşısında üstün geldi.',
          '🥊 ${updatedWinner.name} outperformed ${updatedLoser.name} in training.',
        );
        return;
      }
      _battleReport = newLoserHp <= 0
          ? state.tt(
              '⚠️ ${updatedWinner.gangName} çetesi: ${updatedWinner.name}, ${updatedLoser.name} oyuncusunu hastanelik etti. (+\$$stolen) [Ekipman etkisi %${_signed(attackerMatchup.totalPct)}]',
              '⚠️ ${updatedWinner.gangName}: ${updatedWinner.name} sent ${updatedLoser.name} to hospital. (+\$$stolen) [Loadout edge ${_signed(attackerMatchup.totalPct)}%]',
            )
          : state.tt(
              '${updatedWinner.gangName} çetesi üstün: ${updatedWinner.name} vs ${updatedLoser.name}. (+\$$stolen) [Ekipman etkisi %${_signed(attackerMatchup.totalPct)}]',
              '${updatedWinner.gangName} dominated: ${updatedWinner.name} vs ${updatedLoser.name}. (+\$$stolen) [Loadout edge ${_signed(attackerMatchup.totalPct)}%]',
            );
    });
  }

  void _openAttackSheet(GameState state, _RivalVm target) {
    if (_busy) return;
    if (state.isActionLocked) {
      _showActionLockedPopup(state);
      return;
    }
    if (!state.hasEnoughEnergyForAttack) {
      setState(() {
        _battleReport = state.tt(
          'Saldırı için enerji yetersiz.',
          'Not enough energy for attack.',
        );
      });
      return;
    }
    final current = _rivalsById[target.id] ?? target;
    if (current.id.startsWith('bot_')) {
      _runLocalBotAttack(state, current);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AttackConfirmSheet(
        attackerId: state.userId.isEmpty ? 'local_player' : state.userId,
        targetId: current.id,
        targetName: current.name,
        attackerPower: state.totalPower,
        targetPower: current.power,
        attackerName: state.displayPlayerName,
      ),
    );
  }

  void _runLocalBotAttack(GameState state, _RivalVm target) {
    if (_busy) return;
    if (state.isActionLocked) {
      _showActionLockedPopup(state);
      return;
    }
    if (!state.hasEnoughEnergyForAttack) {
      setState(() {
        _battleReport = state.tt(
          'Saldırı için enerji yetersiz.',
          'Not enough energy for attack.',
        );
      });
      return;
    }
    if (target.currentTP <= 0 || target.isDetained) {
      setState(() {
        _battleReport = state.tt(
          '${target.name} şu an işlem dışı.',
          '${target.name} is currently unavailable.',
        );
      });
      return;
    }

    setState(() => _busy = true);
    // Attack flash animation
    _triggerFlash(Colors.red, target.id);
    Future<void>.delayed(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      final attackCost = state.attackEnergyCost;
      final spent = await state.spendAttackEnergy(attackCost: attackCost);
      if (!spent) {
        if (mounted) {
          setState(() {
            _busy = false;
            _battleReport = state.tt(
              'Saldırı için enerji yetersiz.',
              'Not enough energy for attack.',
            );
          });
        }
        return;
      }
      final current = _rivalsById[target.id] ?? target;
      final attackerWeaponId = state.equippedCombatWeaponId.isEmpty
          ? WeaponMatchupService.defaultWeaponIdForPower(state.totalPower)
          : state.equippedCombatWeaponId;
      final attackerKnifeId = state.equippedKnifeId.isEmpty
          ? WeaponMatchupService.defaultKnifeIdForPower(state.totalPower)
          : state.equippedKnifeId;
      final attackerArmorId = state.equippedArmorId.isEmpty
          ? WeaponMatchupService.defaultArmorIdForPower(state.totalPower)
          : state.equippedArmorId;
      final attackerVehicleId = state.equippedVehicleId.isEmpty
          ? WeaponMatchupService.defaultVehicleIdForPower(state.totalPower)
          : state.equippedVehicleId;
      final targetWeaponId = current.combatWeaponId.isEmpty
          ? WeaponMatchupService.defaultWeaponIdForPower(current.power)
          : current.combatWeaponId;
      final targetKnifeId = current.knifeId.isEmpty
          ? WeaponMatchupService.defaultKnifeIdForPower(current.power)
          : current.knifeId;
      final targetArmorId = current.armorId.isEmpty
          ? WeaponMatchupService.defaultArmorIdForPower(current.power)
          : current.armorId;
      final targetVehicleId = current.vehicleId.isEmpty
          ? WeaponMatchupService.defaultVehicleIdForPower(current.power)
          : current.vehicleId;
      final attackerWeapon = WeaponMatchupService.itemById(attackerWeaponId);
      final targetWeapon = WeaponMatchupService.itemById(targetWeaponId);
      final attackerKnife = WeaponMatchupService.itemById(attackerKnifeId);
      final targetKnife = WeaponMatchupService.itemById(targetKnifeId);
      final attackerArmor = WeaponMatchupService.itemById(attackerArmorId);
      final targetArmor = WeaponMatchupService.itemById(targetArmorId);
      final attackerVehicle = WeaponMatchupService.itemById(attackerVehicleId);
      final targetVehicle = WeaponMatchupService.itemById(targetVehicleId);
      final attackerWeaponName = attackerWeapon == null
          ? state.tt('Yumruk', 'Fists')
          : state.itemName(attackerWeapon);
      final targetWeaponName = targetWeapon == null
          ? state.tt('Yumruk', 'Fists')
          : state.itemName(targetWeapon);
      final attackerKnifeName = attackerKnife == null
          ? state.tt('Yok', 'None')
          : state.itemName(attackerKnife);
      final targetKnifeName = targetKnife == null
          ? state.tt('Yok', 'None')
          : state.itemName(targetKnife);
      final attackerArmorName = attackerArmor == null
          ? state.tt('Yok', 'None')
          : state.itemName(attackerArmor);
      final targetArmorName = targetArmor == null
          ? state.tt('Yok', 'None')
          : state.itemName(targetArmor);
      final attackerVehicleName = attackerVehicle == null
          ? state.tt('Yok', 'None')
          : state.itemName(attackerVehicle);
      final targetVehicleName = targetVehicle == null
          ? state.tt('Yok', 'None')
          : state.itemName(targetVehicle);
      final attackerMatchup = WeaponMatchupService.evaluateLoadout(
        attacker: CombatLoadout(
          weaponId: attackerWeaponId,
          knifeId: attackerKnifeId,
          armorId: attackerArmorId,
          vehicleId: attackerVehicleId,
        ),
        target: CombatLoadout(
          weaponId: targetWeaponId,
          knifeId: targetKnifeId,
          armorId: targetArmorId,
          vehicleId: targetVehicleId,
        ),
      );
      final defenderMatchup = WeaponMatchupService.evaluateLoadout(
        attacker: CombatLoadout(
          weaponId: targetWeaponId,
          knifeId: targetKnifeId,
          armorId: targetArmorId,
          vehicleId: targetVehicleId,
        ),
        target: CombatLoadout(
          weaponId: attackerWeaponId,
          knifeId: attackerKnifeId,
          armorId: attackerArmorId,
          vehicleId: attackerVehicleId,
        ),
      );
      final attackerRoll = _simRandom.nextInt(160);
      final defenderRoll = _simRandom.nextInt(160);
      final atkScore =
          _applyPercent(state.totalPower, attackerMatchup.totalPct) +
          attackerRoll;
      final defScore =
          _applyPercent(current.power, defenderMatchup.totalPct) + defenderRoll;
      final won = atkScore >= defScore;
      _AttackStepReport report;

      if (won) {
        final damage = 16 + _simRandom.nextInt(30);
        final loot = current.cash <= 0
            ? 0
            : min(current.cash, 80 + _simRandom.nextInt(280));
        final newHp = max(0, current.currentTP - damage);
        _rivalsById[current.id] = current.copyWith(
          currentTP: newHp,
          cash: max(0, current.cash - loot),
        );
        _triggerFlash(const Color(0xFF34D399), target.id);
        _battleReport = newHp <= 0
            ? state.tt(
                '🏥 ${target.name} yere serildi. (+\$$loot)',
                '🏥 ${target.name} got knocked out. (+\$$loot)',
              )
            : state.tt(
                '${target.name} karşısında baskın başarılı. (+\$$loot)',
                'Successful hit on ${target.name}. (+\$$loot)',
              );
        report = _AttackStepReport(
          targetName: target.name,
          attackerBasePower: state.totalPower,
          defenderBasePower: current.power,
          attackerRoll: attackerRoll,
          defenderRoll: defenderRoll,
          attackerTotal: atkScore,
          defenderTotal: defScore,
          won: true,
          damage: damage,
          loot: loot,
          targetHpBefore: current.currentTP,
          targetHpAfter: newHp,
          attackerWeaponName: attackerWeaponName,
          targetWeaponName: targetWeaponName,
          attackerKnifeName: attackerKnifeName,
          targetKnifeName: targetKnifeName,
          attackerArmorName: attackerArmorName,
          targetArmorName: targetArmorName,
          attackerVehicleName: attackerVehicleName,
          targetVehicleName: targetVehicleName,
          weaponPowerPct: attackerMatchup.weaponPowerPct,
          weaponSpeedPct: attackerMatchup.weaponSpeedPct,
          weaponTotalPct: attackerMatchup.weaponTotalPct,
          knifePct: attackerMatchup.knifePct,
          armorPct: attackerMatchup.armorPct,
          vehiclePct: attackerMatchup.vehiclePct,
          loadoutTotalPct: attackerMatchup.totalPct,
          happenedAt: DateTime.now(),
        );
        // Track in game state
        state.applySoloAttackWin(
          cashGained: loot,
          report: _battleReport,
          attackCost: 0,
        );
        // Firestore'a kaydet
        if (state.userId.isNotEmpty) {
          _historySvc.saveAttack(
            attackerId: state.userId,
            attackerName: state.displayPlayerName,
            targetId: current.id,
            targetName: current.name,
            outcome: AttackOutcome.win,
            type: AttackType.quick,
            stolenCash: loot,
            xpGained: 14,
          );
        }
      } else {
        _triggerFlash(const Color(0xFFEF4444), target.id);
        _battleReport = state.tt(
          '${target.name} saldırıyı püskürttü.',
          '${target.name} defended the attack.',
        );
        report = _AttackStepReport(
          targetName: target.name,
          attackerBasePower: state.totalPower,
          defenderBasePower: current.power,
          attackerRoll: attackerRoll,
          defenderRoll: defenderRoll,
          attackerTotal: atkScore,
          defenderTotal: defScore,
          won: false,
          damage: 0,
          loot: 0,
          targetHpBefore: current.currentTP,
          targetHpAfter: current.currentTP,
          attackerWeaponName: attackerWeaponName,
          targetWeaponName: targetWeaponName,
          attackerKnifeName: attackerKnifeName,
          targetKnifeName: targetKnifeName,
          attackerArmorName: attackerArmorName,
          targetArmorName: targetArmorName,
          attackerVehicleName: attackerVehicleName,
          targetVehicleName: targetVehicleName,
          weaponPowerPct: attackerMatchup.weaponPowerPct,
          weaponSpeedPct: attackerMatchup.weaponSpeedPct,
          weaponTotalPct: attackerMatchup.weaponTotalPct,
          knifePct: attackerMatchup.knifePct,
          armorPct: attackerMatchup.armorPct,
          vehiclePct: attackerMatchup.vehiclePct,
          loadoutTotalPct: attackerMatchup.totalPct,
          happenedAt: DateTime.now(),
        );
        // Firestore'a kaydet
        if (state.userId.isNotEmpty) {
          _historySvc.saveAttack(
            attackerId: state.userId,
            attackerName: state.displayPlayerName,
            targetId: current.id,
            targetName: current.name,
            outcome: AttackOutcome.lose,
            type: AttackType.quick,
            stolenCash: 0,
            xpGained: 0,
          );
        }
      }

      setState(() => _busy = false);
      _showAttackReportSheet(state, report);
    });
  }

  void _showAttackReportSheet(GameState state, _AttackStepReport report) {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _AttackReportSheet(report: report, isEnglish: state.isEnglish),
    );
  }

  int _applyPercent(int value, int pct) {
    return max(1, ((value * (100 + pct)) / 100).round());
  }

  String _signed(int value) {
    return value > 0 ? '+$value' : '$value';
  }

  _AttackWindow _buildAttackWindow(GameState state, List<_RivalVm> rivals) {
    if (rivals.isEmpty) {
      return const _AttackWindow(above: <_RivalVm>[], below: <_RivalVm>[]);
    }

    final sorted = [...rivals]..sort((a, b) => b.power.compareTo(a.power));
    final myPower = max(1, state.totalPower);

    var myIndex = sorted.indexWhere((r) => myPower >= r.power);
    if (myIndex < 0) myIndex = sorted.length;

    final aboveStart = max(0, myIndex - 5);
    final above = sorted.sublist(aboveStart, myIndex).reversed.toList();

    final belowEnd = min(sorted.length, myIndex + 5);
    final below = sorted.sublist(myIndex, belowEnd);

    return _AttackWindow(above: above, below: below);
  }

  Widget _buildSectionTitle(GameState state, String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8, left: 4, right: 4),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFFBBF24),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Spacer(),
          Text(
            state.tt('Maks. 5', 'Max 5'),
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoTargetCard(GameState state, String message) {
    return Card(
      color: const Color(0xFF1A1E28),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[800]!),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(
          message,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildRivalCard(GameState state, _RivalVm target) {
    final isTargetHospitalized = target.currentTP <= 0;
    final isTargetDetained = target.isDetained;
    final hasEnergy = state.hasEnoughEnergyForAttack;
    final canAttack =
        !isTargetHospitalized &&
        !isTargetDetained &&
        !_busy &&
        hasEnergy &&
        !state.isActionLocked;
    final isFlashing = _lastAttackTargetId == target.id;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: isFlashing && _flashController.isAnimating
            ? [
                BoxShadow(
                  color: _flashColor.withValues(alpha: 0.25),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ]
            : null,
      ),
      child: Card(
        color: isTargetHospitalized ? Colors.black45 : const Color(0xFF1E222D),
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[800]!),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: isTargetHospitalized
                    ? Colors.red[900]
                    : Colors.amber[800],
                child: Icon(
                  (isTargetHospitalized || isTargetDetained)
                      ? Icons.local_hospital
                      : Icons.person,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: target.isOnline
                                ? const Color(0xFF34D399)
                                : Colors.white30,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(
                          '${state.tt('Sv.', 'Lv.')} ${target.level} | ${target.name}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${state.tt('Güç', 'Power')}: ${target.power}',
                      style: const TextStyle(
                        color: Colors.purpleAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${state.tt('Can', 'HP')}: ${target.currentTP}/100',
                      style: TextStyle(
                        color: target.currentTP > 20
                            ? Colors.redAccent
                            : Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (target.gangName.isNotEmpty)
                      Text(
                        '${state.tt('Çete', 'Gang')}: ${target.gangName}',
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canAttack
                          ? Colors.red[700]
                          : Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: canAttack
                        ? () => _openAttackSheet(state, target)
                        : null,
                    child: Text(
                      isTargetHospitalized
                          ? state.tt('HASTANEDE', 'IN HOSPITAL')
                          : isTargetDetained
                          ? state.tt('CEZALI', 'DETAINED')
                          : state.isActionLocked
                          ? state.actionLockTitle
                          : !hasEnergy
                          ? state.tt('ENERJİ YOK', 'NO ENERGY')
                          : (_busy ? '...' : state.tt('SALDIR', 'ATTACK')),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!isTargetHospitalized)
                    Text(
                      '-${state.attackEnergyCost} ${state.tt('Enerji', 'Energy')}',
                      style: TextStyle(
                        color: hasEnergy ? Colors.blueAccent : Colors.redAccent,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHudStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, state, _) {
        final rivals = _buildRivals(state);
        final window = _buildAttackWindow(state, rivals);

        return Scaffold(
          backgroundColor: const Color(0xFF12141C),
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(
              state.tt('SOKAKLAR (PvP)', 'STREETS (PvP)'),
              style: const TextStyle(
                color: Color(0xFFFBBF24),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: GameBackground(
            child: Column(
              children: [
                Container(
                  color: Colors.black87,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildHudStat(
                            state.tt('Nakit', 'Cash'),
                            '\$${state.cash}',
                            Colors.green,
                          ),
                          _buildHudStat(
                            state.tt('Güç', 'Power'),
                            '${state.totalPower}',
                            Colors.purpleAccent,
                          ),
                          _buildHudStat(
                            state.tt('Can', 'HP'),
                            '${state.currentTP}/${state.maxTP}',
                            state.currentTP > 20
                                ? Colors.redAccent
                                : Colors.red,
                          ),
                          _buildHudStat(
                            state.tt('Enerji', 'Energy'),
                            '${state.currentEnerji}/${state.maxEnerji}',
                            Colors.blueAccent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _battleReport.isEmpty
                            ? state.tt(
                                'Saldırı bekleniyor...',
                                'Waiting for attack...',
                              )
                            : _battleReport,
                        style: const TextStyle(
                          color: Color(0xFFD1D5DB),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const Divider(
                  color: Color(0xFFFBBF24),
                  height: 1,
                  thickness: 2,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                    children: [
                      _buildSectionTitle(
                        state,
                        state.tt('Üstündeki 5', 'Top 5 Above'),
                        window.above.length,
                      ),
                      if (window.above.isEmpty)
                        _buildNoTargetCard(
                          state,
                          state.tt(
                            'Üzerinde saldırabileceğin oyuncu yok.',
                            'No stronger target available.',
                          ),
                        ),
                      ...window.above.map(
                        (target) => _buildRivalCard(state, target),
                      ),
                      const SizedBox(height: 8),
                      _buildSectionTitle(
                        state,
                        state.tt('Altındaki 5', 'Bottom 5 Below'),
                        window.below.length,
                      ),
                      if (window.below.isEmpty)
                        _buildNoTargetCard(
                          state,
                          state.tt(
                            'Altında saldırabileceğin oyuncu yok.',
                            'No weaker target available.',
                          ),
                        ),
                      ...window.below.map(
                        (target) => _buildRivalCard(state, target),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AttackWindow {
  const _AttackWindow({required this.above, required this.below});

  final List<_RivalVm> above;
  final List<_RivalVm> below;
}

class _AttackStepReport {
  const _AttackStepReport({
    required this.targetName,
    required this.attackerBasePower,
    required this.defenderBasePower,
    required this.attackerRoll,
    required this.defenderRoll,
    required this.attackerTotal,
    required this.defenderTotal,
    required this.won,
    required this.damage,
    required this.loot,
    required this.targetHpBefore,
    required this.targetHpAfter,
    required this.attackerWeaponName,
    required this.targetWeaponName,
    required this.attackerKnifeName,
    required this.targetKnifeName,
    required this.attackerArmorName,
    required this.targetArmorName,
    required this.attackerVehicleName,
    required this.targetVehicleName,
    required this.weaponPowerPct,
    required this.weaponSpeedPct,
    required this.weaponTotalPct,
    required this.knifePct,
    required this.armorPct,
    required this.vehiclePct,
    required this.loadoutTotalPct,
    required this.happenedAt,
  });

  final String targetName;
  final int attackerBasePower;
  final int defenderBasePower;
  final int attackerRoll;
  final int defenderRoll;
  final int attackerTotal;
  final int defenderTotal;
  final bool won;
  final int damage;
  final int loot;
  final int targetHpBefore;
  final int targetHpAfter;
  final String attackerWeaponName;
  final String targetWeaponName;
  final String attackerKnifeName;
  final String targetKnifeName;
  final String attackerArmorName;
  final String targetArmorName;
  final String attackerVehicleName;
  final String targetVehicleName;
  final int weaponPowerPct;
  final int weaponSpeedPct;
  final int weaponTotalPct;
  final int knifePct;
  final int armorPct;
  final int vehiclePct;
  final int loadoutTotalPct;
  final DateTime happenedAt;
}

class _AttackReportSheet extends StatelessWidget {
  const _AttackReportSheet({required this.report, required this.isEnglish});

  final _AttackStepReport report;
  final bool isEnglish;

  String _t(String tr, String en) => isEnglish ? en : tr;

  @override
  Widget build(BuildContext context) {
    final color = report.won
        ? const Color(0xFF34D399)
        : const Color(0xFFEF4444);
    final hh = report.happenedAt.hour.toString().padLeft(2, '0');
    final mm = report.happenedAt.minute.toString().padLeft(2, '0');
    final ss = report.happenedAt.second.toString().padLeft(2, '0');

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                report.won ? Icons.verified_rounded : Icons.gpp_bad_rounded,
                color: color,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                _t('Saldırı Raporu', 'Attack Report'),
                style: TextStyle(
                  color: color,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_t('Hedef', 'Target')}: ${report.targetName}  •  $hh:$mm:$ss',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          _ReportRow(
            label: _t('Saldırı Gücü', 'Attack Power'),
            value:
                '${report.attackerBasePower} + ${report.attackerRoll} = ${report.attackerTotal}',
          ),
          _ReportRow(
            label: _t('Savunma Gücü', 'Defense Power'),
            value:
                '${report.defenderBasePower} + ${report.defenderRoll} = ${report.defenderTotal}',
          ),
          _ReportRow(
            label: _t('Silah Eşleşmesi', 'Weapon Matchup'),
            value:
                '${_t('Sen', 'You')}: ${report.attackerWeaponName}\n${_t('Rakip', 'Rival')}: ${report.targetWeaponName}',
            multilineValue: true,
          ),
          _ReportRow(
            label: _t('Yakın Dövüş', 'Melee Matchup'),
            value:
                '${_t('Sen', 'You')}: ${report.attackerKnifeName}\n${_t('Rakip', 'Rival')}: ${report.targetKnifeName}',
            multilineValue: true,
          ),
          _ReportRow(
            label: _t('Zırh Eşleşmesi', 'Armor Matchup'),
            value:
                '${_t('Sen', 'You')}: ${report.attackerArmorName}\n${_t('Rakip', 'Rival')}: ${report.targetArmorName}',
            multilineValue: true,
          ),
          _ReportRow(
            label: _t('Araç Eşleşmesi', 'Vehicle Matchup'),
            value:
                '${_t('Sen', 'You')}: ${report.attackerVehicleName}\n${_t('Rakip', 'Rival')}: ${report.targetVehicleName}',
            multilineValue: true,
          ),
          _ReportRow(
            label: _t('Silah Güç Etkisi', 'Weapon Power Effect'),
            value:
                '%${report.weaponPowerPct > 0 ? '+' : ''}${report.weaponPowerPct}',
            valueColor: report.weaponPowerPct >= 0
                ? const Color(0xFF34D399)
                : const Color(0xFFEF4444),
          ),
          _ReportRow(
            label: _t('Silah Hız Etkisi', 'Weapon Speed Effect'),
            value:
                '%${report.weaponSpeedPct > 0 ? '+' : ''}${report.weaponSpeedPct}',
            valueColor: report.weaponSpeedPct >= 0
                ? const Color(0xFF34D399)
                : const Color(0xFFEF4444),
          ),
          _ReportRow(
            label: _t('Yakın Dövüş Etkisi', 'Melee Effect'),
            value: '%${report.knifePct > 0 ? '+' : ''}${report.knifePct}',
            valueColor: report.knifePct >= 0
                ? const Color(0xFF34D399)
                : const Color(0xFFEF4444),
          ),
          _ReportRow(
            label: _t('Zırh Etkisi', 'Armor Effect'),
            value: '%${report.armorPct > 0 ? '+' : ''}${report.armorPct}',
            valueColor: report.armorPct >= 0
                ? const Color(0xFF34D399)
                : const Color(0xFFEF4444),
          ),
          _ReportRow(
            label: _t('Araç Etkisi', 'Vehicle Effect'),
            value: '%${report.vehiclePct > 0 ? '+' : ''}${report.vehiclePct}',
            valueColor: report.vehiclePct >= 0
                ? const Color(0xFF34D399)
                : const Color(0xFFEF4444),
          ),
          _ReportRow(
            label: _t('Çatışma Sonucu', 'Engagement Result'),
            value: report.won
                ? _t('Üstünlük sende', 'You dominated')
                : _t('Hedef saldırıyı kırdı', 'Target held the line'),
            valueColor: color,
          ),
          _ReportRow(
            label: _t('Toplam Ekipman Avantajı', 'Total Loadout Edge'),
            value:
                '%${report.loadoutTotalPct > 0 ? '+' : ''}${report.loadoutTotalPct}',
            valueColor: report.loadoutTotalPct >= 0
                ? const Color(0xFF34D399)
                : const Color(0xFFEF4444),
          ),
          _ReportRow(
            label: _t('Verilen Hasar', 'Damage Dealt'),
            value: '${report.damage}',
          ),
          _ReportRow(
            label: _t('Kazanılan Nakit', 'Looted Cash'),
            value: '+\$${report.loot}',
            valueColor: const Color(0xFF34D399),
          ),
          _ReportRow(
            label: _t('Hedef TP', 'Target HP'),
            value: '${report.targetHpBefore} -> ${report.targetHpAfter}',
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(
                _t('Tamam', 'Close'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.multilineValue = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool multilineValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: multilineValue
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: multilineValue ? 3 : 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: multilineValue ? 11 : 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RivalVm {
  const _RivalVm({
    required this.id,
    required this.name,
    required this.power,
    required this.cash,
    required this.level,
    required this.currentTP,
    this.gangName = '',
    this.status = 'active',
    this.statusUntilEpoch = 0,
    this.shieldUntilEpoch = 0,
    this.isOnline = false,
    this.combatWeaponId = '',
    this.knifeId = '',
    this.armorId = '',
    this.vehicleId = '',
  });

  final String id;
  final String name;
  final int power;
  final int cash;
  final int level;
  final String gangName;
  final int currentTP;
  final String status;
  final int statusUntilEpoch;
  final int shieldUntilEpoch;
  final bool isOnline;
  final String combatWeaponId;
  final String knifeId;
  final String armorId;
  final String vehicleId;
  bool get isDetained =>
      (status == 'hospital' || status == 'prison') &&
      statusUntilEpoch > (DateTime.now().millisecondsSinceEpoch ~/ 1000);

  _RivalVm copyWith({
    String? id,
    String? name,
    int? power,
    int? cash,
    int? level,
    String? gangName,
    int? currentTP,
    String? status,
    int? statusUntilEpoch,
    int? shieldUntilEpoch,
    bool? isOnline,
    String? combatWeaponId,
    String? knifeId,
    String? armorId,
    String? vehicleId,
  }) {
    return _RivalVm(
      id: id ?? this.id,
      name: name ?? this.name,
      power: power ?? this.power,
      cash: cash ?? this.cash,
      level: level ?? this.level,
      gangName: gangName ?? this.gangName,
      currentTP: currentTP ?? this.currentTP,
      status: status ?? this.status,
      statusUntilEpoch: statusUntilEpoch ?? this.statusUntilEpoch,
      shieldUntilEpoch: shieldUntilEpoch ?? this.shieldUntilEpoch,
      isOnline: isOnline ?? this.isOnline,
      combatWeaponId: combatWeaponId ?? this.combatWeaponId,
      knifeId: knifeId ?? this.knifeId,
      armorId: armorId ?? this.armorId,
      vehicleId: vehicleId ?? this.vehicleId,
    );
  }
}
