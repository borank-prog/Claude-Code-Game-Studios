import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/game_models.dart';
import '../data/static_data.dart';
import '../state/game_state.dart';
import '../widgets/format.dart';
import '../widgets/glass_panel.dart';

class CityScreen extends StatelessWidget {
  const CityScreen({super.key});

  Future<void> _showActionLockedPopup(
    BuildContext context,
    GameState state,
  ) async {
    if (!context.mounted) return;
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
          state.actionLockMessage,
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

  Future<void> _showCenterNotice(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool success,
  }) async {
    final color = success ? const Color(0xFF34D399) : const Color(0xFFF87171);
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (_) => Center(
        child: Container(
          width: 300,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1A2E),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 22,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(
                  success ? Icons.check_rounded : Icons.error_outline_rounded,
                  color: color,
                  size: 38,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).maybePop();
  }

  Future<void> _showMissionResultSheet(
    BuildContext context,
    GameState state,
    MissionDef mission,
    MissionResult res,
  ) async {
    // Jail/Hospital penalties are handled by HomeShell center popups only.
    if (res.sentToHospital || res.sentToJail) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CityMissionResultSheet(
        state: state,
        mission: mission,
        res: res,
        onRepeat: () async {
          if (state.isActionLocked) {
            await _showActionLockedPopup(context, state);
            return;
          }
          Navigator.of(ctx).pop();
          final next = await state.completeMission(mission);
          if (!context.mounted) return;
          await _showMissionResultSheet(context, state, mission, next);
        },
        onPaySkip: () async {
          if (res.sentToJail) {
            await state.payJailWithGold();
          } else {
            await state.payHospitalWithGold();
          }
          if (!ctx.mounted) return;
          Navigator.of(ctx).pop();
        },
        onEnergyRush: () async {
          final msg = await state.buyEnergyRush();
          if (!ctx.mounted || !context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  Widget _difficultySection(
    BuildContext context, {
    required GameState state,
    required String difficulty,
    required Color titleColor,
    required List<MissionDef> missions,
  }) {
    final unlocked = state.isMissionDifficultyUnlocked(difficulty);
    final unlockLevel = state.missionDifficultyUnlockLevel(difficulty);
    final title = state.difficultyName(difficulty);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x1814213B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x447F8EA8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          if (!unlocked)
            Text(
              state.tt(
                'Seviye $unlockLevel olduğunda açılır.',
                'Unlocks at level $unlockLevel.',
              ),
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            )
          else if (missions.isEmpty)
            Text(
              state.tt(
                'Bu zorlukta şu an görev yok.',
                'No missions available in this tier right now.',
              ),
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            )
          else
            ...missions.map(
              (m) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0x2214213B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x447F8EA8)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.missionName(m),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${state.tt('Enerji', 'Energy')}: ${m.staminaCost}  •  \$${m.rewardMin}-${m.rewardMax}',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () async {
                        if (state.isActionLocked) {
                          await _showActionLockedPopup(context, state);
                          return;
                        }
                        final res = await state.completeMission(m);
                        if (!context.mounted) return;
                        await _showMissionResultSheet(context, state, m, res);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: titleColor,
                      ),
                      child: Text(state.tt('BAŞLA', 'START')),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, state, _) {
        final totalHourly = StaticData.buildings
            .where((b) => (state.ownedBuildings[b.id] ?? 0) > 0)
            .fold<int>(0, (sum, b) => sum + b.hourlyIncome);

        final easyMissions = state.missionsForDifficulty('easy');
        final mediumMissions = state.missionsForDifficulty('medium');
        final hardMissions = state.missionsForDifficulty('hard');

        const targetCityMissionCount = 5;
        List<MissionDef> pickGroup(
          List<MissionDef> source,
          int count, {
          int shiftBase = 0,
        }) {
          if (source.isEmpty || count <= 0) return const <MissionDef>[];
          final out = <MissionDef>[];
          final seenIds = <String>{};
          for (var i = 0; i < source.length && out.length < count; i++) {
            final idx = (state.level ~/ 6 + shiftBase + i) % source.length;
            final mission = source[idx];
            if (!seenIds.add(mission.id)) continue;
            out.add(mission);
          }
          return out;
        }

        var easyQuota = easyMissions.isNotEmpty ? 2 : 0;
        var mediumQuota = mediumMissions.isNotEmpty ? 2 : 0;
        var hardQuota = hardMissions.isNotEmpty ? 1 : 0;
        var allocated = easyQuota + mediumQuota + hardQuota;
        while (allocated < targetCityMissionCount) {
          if (easyQuota < easyMissions.length) {
            easyQuota++;
            allocated++;
            continue;
          }
          if (mediumQuota < mediumMissions.length) {
            mediumQuota++;
            allocated++;
            continue;
          }
          if (hardQuota < hardMissions.length) {
            hardQuota++;
            allocated++;
            continue;
          }
          break;
        }

        final easyCityMissions = pickGroup(easyMissions, easyQuota);
        final mediumCityMissions = pickGroup(
          mediumMissions,
          mediumQuota,
          shiftBase: 1,
        );
        final hardCityMissions = pickGroup(
          hardMissions,
          hardQuota,
          shiftBase: 2,
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
          children: [
            GlassPanel(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${state.tt('Saatlik Gelir', 'Hourly Income')}: \$${compactNumber(totalHourly)}',
                      style: const TextStyle(
                        color: Color(0xFF34D399),
                        fontWeight: FontWeight.w700,
                        fontSize: 28,
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: () {
                      if (state.isActionLocked) {
                        _showActionLockedPopup(context, state);
                        return;
                      }
                      final amount = state.collectAllBuildingIncome();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            amount > 0
                                ? state.tt(
                                    '\$$amount toplandı.',
                                    '\$$amount collected.',
                                  )
                                : state.tt(
                                    'Henüz toplanacak gelir yok.',
                                    'No income to collect yet.',
                                  ),
                          ),
                        ),
                      );
                    },
                    child: Text(state.tt('Tümünü Topla', 'Collect All')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.tt('ŞEHİR GÖREVLERİ', 'CITY MISSIONS'),
                    style: const TextStyle(
                      color: Color(0xFFFBBF24),
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _difficultySection(
                    context,
                    state: state,
                    difficulty: 'easy',
                    titleColor: const Color(0xFF34D399),
                    missions: easyCityMissions,
                  ),
                  _difficultySection(
                    context,
                    state: state,
                    difficulty: 'medium',
                    titleColor: const Color(0xFFF59E0B),
                    missions: mediumCityMissions,
                  ),
                  _difficultySection(
                    context,
                    state: state,
                    difficulty: 'hard',
                    titleColor: const Color(0xFFEF4444),
                    missions: hardCityMissions,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...StaticData.buildings.map((b) {
              final owned = (state.ownedBuildings[b.id] ?? 0) > 0;
              final costText = b.costGold > 0
                  ? '${b.costGold} ${state.tt('Altın', 'Gold')}'
                  : '\$${compactNumber(b.costCash)}';
              return GlassPanel(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.buildingName(b),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '+\$${compactNumber(b.hourlyIncome)} / ${state.tt('saat', 'hour')}',
                            style: const TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!owned)
                      FilledButton(
                        onPressed: () async {
                          if (state.isActionLocked) {
                            await _showActionLockedPopup(context, state);
                            return;
                          }
                          final ok = await state.buyBuilding(b.id);
                          if (!context.mounted) return;
                          await _showCenterNotice(
                            context,
                            title: ok
                                ? state.tt('Satın alındı', 'Purchased')
                                : state.tt('Yetersiz bakiye', 'Insufficient'),
                            subtitle: ok
                                ? state.tt(
                                    '${state.buildingName(b)} satın alındı.',
                                    '${state.buildingName(b)} purchased.',
                                  )
                                : state.tt(
                                    'Bu mekanı almak için yeterli paran yok.',
                                    'You do not have enough balance.',
                                  ),
                            success: ok,
                          );
                        },
                        child: Text(
                          'Al\n$costText',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11),
                        ),
                      )
                    else
                      Text(
                        state.tt('Sahip', 'Owned'),
                        style: const TextStyle(
                          color: Color(0xFFFBBF24),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _CityMissionResultSheet extends StatelessWidget {
  const _CityMissionResultSheet({
    required this.state,
    required this.mission,
    required this.res,
    required this.onRepeat,
    required this.onPaySkip,
    required this.onEnergyRush,
  });

  final GameState state;
  final MissionDef mission;
  final MissionResult res;
  final VoidCallback onRepeat;
  final VoidCallback onPaySkip;
  final VoidCallback onEnergyRush;

  @override
  Widget build(BuildContext context) {
    final success = res.success;
    final sentPenalty = res.sentToJail || res.sentToHospital;
    final accentColor = success
        ? const Color(0xFF34D399)
        : const Color(0xFFEF4444);
    final icon = success
        ? Icons.check_circle_rounded
        : sentPenalty
        ? Icons.gavel_rounded
        : Icons.cancel_rounded;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0B1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF2B3A5A),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.12),
                  border: Border.all(color: accentColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.3),
                      blurRadius: 22,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(icon, color: accentColor, size: 44),
              ),
              const SizedBox(height: 16),
              Text(
                success
                    ? state.tt('Operasyon Başarılı', 'Operation Success')
                    : sentPenalty
                    ? state.tt('Yakalandın!', 'Busted!')
                    : state.tt('Başarısız', 'Failed'),
                style: TextStyle(
                  color: accentColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                state.missionName(mission),
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1630),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1E2D45)),
                ),
                child: Column(
                  children: [
                    if (res.cashEarned > 0) ...[
                      _resultRow(
                        '💰 ${state.tt('Nakit', 'Cash')}',
                        '+\$${res.cashEarned}',
                        const Color(0xFF34D399),
                      ),
                      if (res.bonusCash > 0)
                        _resultRow(
                          '   ${state.tt('(Taban', '(Base')} \$${res.baseCash} + ${state.tt('Bonus', 'Bonus')} \$${res.bonusCash})',
                          '',
                          const Color(0xFF4B5563),
                          small: true,
                        ),
                    ],
                    if (res.xpEarned > 0)
                      _resultRow(
                        '⭐ XP',
                        '+${res.xpEarned}',
                        const Color(0xFF60A5FA),
                      ),
                    _resultRow(
                      '⚔️ ${state.tt('Güç', 'Power')}',
                      '${res.powerBefore} → ${res.powerAfter}',
                      const Color(0xFFFBBF24),
                    ),
                    if (res.sentToJail)
                      _resultRow(
                        '🔒 ${state.tt('Durum', 'Status')}',
                        state.tt('Hapishane (30 dk)', 'Jail (30 min)'),
                        const Color(0xFFEF4444),
                      ),
                    if (res.sentToHospital)
                      _resultRow(
                        '🏥 ${state.tt('Durum', 'Status')}',
                        state.tt('Hastane (30 dk)', 'Hospital (30 min)'),
                        const Color(0xFFEF4444),
                      ),
                  ],
                ),
              ),
              if (res.nextAction.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  res.nextAction,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              if (sentPenalty) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onPaySkip,
                    icon: const Icon(Icons.monetization_on_outlined, size: 18),
                    label: Text(
                      res.sentToJail
                          ? '${state.jailSkipGoldCost} ${state.tt('Altın Öde ve Çık', 'Pay Gold & Exit')}'
                          : '${state.hospitalSkipGoldCost} ${state.tt('Altın Öde ve Çık', 'Pay Gold & Exit')}',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (!sentPenalty &&
                  state.currentEnerji < mission.staminaCost) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onEnergyRush,
                    icon: const Icon(Icons.bolt, size: 18),
                    label: Text(
                      '${state.energyRushGoldCost} ${state.tt('Altın Adrenalin', 'Gold Adrenaline')}',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (!sentPenalty &&
                  state.currentEnerji >= mission.staminaCost) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: onRepeat,
                    child: Text(
                      state.tt('Aynı Görevi Tekrarla', 'Repeat Mission'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(state.tt('Kapat', 'Close')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultRow(
    String label,
    String value,
    Color color, {
    bool small = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: small ? 2 : 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: small ? 11 : 14,
                fontWeight: small ? FontWeight.w500 : FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: small ? 11 : 14,
              fontWeight: small ? FontWeight.w500 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
