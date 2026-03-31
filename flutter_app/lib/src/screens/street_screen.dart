import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/game_models.dart';
import 'attack_screen.dart';
import '../state/game_state.dart';
import '../widgets/format.dart';
import '../widgets/glass_panel.dart';

class StreetScreen extends StatefulWidget {
  const StreetScreen({super.key});

  @override
  State<StreetScreen> createState() => _StreetScreenState();
}

class _StreetScreenState extends State<StreetScreen> {
  String difficulty = 'easy';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, state, _) {
        final missions = state.missionsForDifficulty(difficulty);
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
          children: [
            GlassPanel(
              child: Column(
                children: [
                  Text(
                    state.tt('GÖREVLER', 'MISSIONS'),
                    style: const TextStyle(
                      color: Color(0xFFFBBF24),
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _tab(state.tt('Kolay', 'Easy'), 'easy')),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _tab(state.tt('Orta', 'Medium'), 'medium'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: _tab(state.tt('Zor', 'Hard'), 'hard')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    difficulty == 'easy'
                        ? state.tt('Risk: Düşük', 'Risk: Low')
                        : difficulty == 'medium'
                        ? state.tt('Risk: Orta', 'Risk: Medium')
                        : state.tt('Risk: Çok Yüksek', 'Risk: Very High'),
                    style: TextStyle(
                      color: difficulty == 'hard'
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF34D399),
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AttackScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.local_fire_department_outlined),
                      label: Text(state.tt('Sokak Çatışması', 'Street Combat')),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _buildDailyPanel(state),
            if (state.jailSecondsLeft > 0)
              _statusCard(
                title: state.tt('Hapiste', 'In Jail'),
                left: state.tt(
                  'Cezanın bitmesine: ${secondsToClock(state.jailSecondsLeft)}',
                  'Time left: ${secondsToClock(state.jailSecondsLeft)}',
                ),
                buttonLabel:
                    '${state.jailSkipGoldCost} ${state.tt('Altın Öde ve Çık', 'Pay Gold and Exit')}',
                onTap: state.payJailWithGold,
              ),
            if (state.hospitalSecondsLeft > 0)
              _statusCard(
                title: state.tt('Hastane', 'Hospital'),
                left: state.tt(
                  'İyileşme süresi: ${secondsToClock(state.hospitalSecondsLeft)}',
                  'Recovery time: ${secondsToClock(state.hospitalSecondsLeft)}',
                ),
                buttonLabel:
                    '${state.hospitalSkipGoldCost} ${state.tt('Altın Öde ve Çık', 'Pay Gold and Exit')}',
                onTap: state.payHospitalWithGold,
                secondaryLabel:
                    '${state.vipHealGoldCost} ${state.tt('Altın VIP Tedavi', 'Gold VIP Heal')}',
                onSecondaryTap: () async {
                  final msg = await state.buyVipHeal();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(msg)));
                },
              ),
            if (state.currentEnerji < state.attackEnergyCost)
              _statusCard(
                title: state.tt('Enerji Düşük', 'Low Energy'),
                left: state.tt(
                  'Saldırı için en az ${state.attackEnergyCost} enerji gerekli.',
                  'At least ${state.attackEnergyCost} energy is required for attack.',
                ),
                buttonLabel:
                    '${state.energyRushGoldCost} ${state.tt('Altın Adrenalin', 'Gold Adrenaline')}',
                onTap: () async {
                  final msg = await state.buyEnergyRush();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(msg)));
                },
              ),
            ...missions.map((m) => _missionCard(state, m)),
          ],
        );
      },
    );
  }

  // ── Tab butonu ──────────────────────────────────────────────────────────────
  Widget _tab(String title, String value) {
    final active = difficulty == value;
    return GestureDetector(
      onTap: () => setState(() => difficulty = value),
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF132C58) : const Color(0xFF1A2740),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? const Color(0xFFFBBF24) : const Color(0x557F8EA8),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: active ? const Color(0xFFFBBF24) : Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ── Durum kartı (hapis/hastane/enerji) ─────────────────────────────────────
  Widget _statusCard({
    required String title,
    required String left,
    required String buttonLabel,
    required VoidCallback onTap,
    String? secondaryLabel,
    VoidCallback? onSecondaryTap,
  }) {
    return GlassPanel(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFEF4444),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(left, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onTap, child: Text(buttonLabel)),
          ),
          if (secondaryLabel != null && onSecondaryTap != null) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onSecondaryTap,
                child: Text(secondaryLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Görev kartı ─────────────────────────────────────────────────────────────
  Widget _missionCard(GameState state, MissionDef m) {
    return GlassPanel(
      margin: const EdgeInsets.only(bottom: 8),
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
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${m.rewardMin}-${m.rewardMax}   +${m.xp} XP   %${(m.successRate * 100).toInt()}',
                  style: const TextStyle(
                    color: Color(0xFF34D399),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${state.tt('Enerji', 'Energy')}: ${m.staminaCost} | ${state.tt('Lv.', 'Lv.')} ${state.level}+',
                  style: const TextStyle(color: Color(0xFFD1D5DB)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () async {
              final res = await state.completeMission(m);
              if (!mounted) return;
              await _showMissionResultSheet(context, state, m, res);
            },
            child: Text(state.tt('Yap', 'Do')),
          ),
        ],
      ),
    );
  }

  // ── Mission Result Bottom Sheet ─────────────────────────────────────────────
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
      builder: (ctx) => _MissionResultSheet(
        state: state,
        mission: mission,
        res: res,
        onRepeat: () async {
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

  // ── Günlük hedefler paneli ──────────────────────────────────────────────────
  Widget _buildDailyPanel(GameState state) {
    return GlassPanel(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık satırı
          Row(
            children: [
              const Icon(
                Icons.local_fire_department,
                color: Color(0xFFFBBF24),
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                state.tt('Günlük Hedefler', 'Daily Objectives'),
                style: const TextStyle(
                  color: Color(0xFFFBBF24),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              FilledButton.tonal(
                onPressed: state.dailyLoginClaimed
                    ? null
                    : () async {
                        final msg = await state.claimDailyLoginReward();
                        if (!mounted) return;
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(msg)));
                      },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  state.dailyLoginClaimed
                      ? state.tt('✓ Alındı', '✓ Claimed')
                      : state.tt(
                          'Seri ${state.dailyStreak} 🎁',
                          'Streak ${state.dailyStreak} 🎁',
                        ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Streak takvimi (7 kutu) ─────────────────────────────────────
          _buildStreakCalendar(state),
          const SizedBox(height: 12),

          // ── Görev listesi ───────────────────────────────────────────────
          ...state.dailyTaskCards.map((task) => _dailyTaskRow(state, task)),
        ],
      ),
    );
  }

  /// 7 günlük görsel streak takvimi
  Widget _buildStreakCalendar(GameState state) {
    const totalDays = 7;
    final streak = state.dailyStreak.clamp(0, totalDays);
    final labels = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    final labelsEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.tt(
            'Giriş serisi: $streak gün  🔥',
            'Login streak: $streak day(s)  🔥',
          ),
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(totalDays, (i) {
            final done = i < streak;
            final isToday = i == streak - 1;
            final label = state.isEnglish ? labelsEn[i] : labels[i];

            return Expanded(
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 36,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: done
                          ? (isToday
                                ? const Color(0xFFFBBF24)
                                : const Color(0xFF34D399))
                          : const Color(0xFF0A1630),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: done
                            ? (isToday
                                  ? const Color(0xFFFBBF24)
                                  : const Color(0xFF34D399))
                            : const Color(0xFF2B3A5A),
                        width: isToday ? 2 : 1,
                      ),
                      boxShadow: isToday
                          ? [
                              BoxShadow(
                                color: const Color(0xFFFBBF24).withOpacity(0.4),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        done ? (isToday ? '🔥' : '✓') : '${i + 1}',
                        style: TextStyle(
                          fontSize: isToday ? 18 : 14,
                          fontWeight: FontWeight.w800,
                          color: done
                              ? (isToday
                                    ? const Color(0xFF0A0F1E)
                                    : const Color(0xFF0A0F1E))
                              : const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: done
                          ? const Color(0xFFFBBF24)
                          : const Color(0xFF4B5563),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  /// Tek bir günlük görev satırı
  Widget _dailyTaskRow(GameState state, Map<String, dynamic> task) {
    final taskId = task['id'] as String;
    final progress = (task['progress'] as num).toInt();
    final target = (task['target'] as num).toInt();
    final claimed = task['claimed'] == true;
    final rewardCash = (task['rewardCash'] as num).toInt();
    final ratio = target <= 0
        ? 0.0
        : (progress / target).clamp(0.0, 1.0).toDouble();
    final canClaim = !claimed && progress >= target;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: claimed ? const Color(0x1A34D399) : const Color(0x33101B31),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: claimed
              ? const Color(0x6634D399)
              : canClaim
              ? const Color(0xAAFBBF24)
              : const Color(0x447F8EA8),
        ),
      ),
      child: Row(
        children: [
          // İkon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: claimed
                  ? const Color(0xFF34D399).withOpacity(0.15)
                  : const Color(0xFF0A1630),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              claimed ? Icons.check_circle : _taskIcon(taskId),
              color: claimed
                  ? const Color(0xFF34D399)
                  : const Color(0xFF60A5FA),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          // Detay
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['title'] as String,
                  style: TextStyle(
                    color: claimed ? const Color(0xFF34D399) : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(6),
                  backgroundColor: const Color(0xFF0A1630),
                  valueColor: AlwaysStoppedAnimation(
                    claimed
                        ? const Color(0xFF34D399)
                        : canClaim
                        ? const Color(0xFFFBBF24)
                        : const Color(0xFF34D399),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$progress/$target  •  +\$$rewardCash',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Buton
          SizedBox(
            width: 60,
            child: FilledButton(
              onPressed: canClaim
                  ? () async {
                      final msg = await state.claimDailyTask(taskId);
                      if (!mounted) return;
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(msg)));
                    }
                  : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                claimed ? '✓' : state.tt('Al', 'Claim'),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _taskIcon(String taskId) {
    switch (taskId) {
      case 'missions_completed':
        return Icons.assignment_turned_in_outlined;
      case 'building_action':
        return Icons.domain_outlined;
      case 'raid_joined':
        return Icons.shield_outlined;
      case 'cash_earned':
        return Icons.attach_money;
      default:
        return Icons.star_outline;
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Mission Result Bottom Sheet (ayrı widget)
// ════════════════════════════════════════════════════════════════════════════
class _MissionResultSheet extends StatelessWidget {
  const _MissionResultSheet({
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
                  color: accentColor.withOpacity(0.12),
                  border: Border.all(color: accentColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.3),
                      blurRadius: 22,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(icon, color: accentColor, size: 44),
              ),
              const SizedBox(height: 16),

              // Başlık
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

              // Sonuç satırları
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

              // Sonraki öneri
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

              // Aksiyon butonları
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
                  child: Text(
                    state.tt('Kapat', 'Close'),
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
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
    Color valueColor, {
    bool small = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFFD1D5DB),
              fontSize: small ? 11 : 14,
            ),
          ),
          const Spacer(),
          if (value.isNotEmpty)
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: small ? 11 : 14,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}
