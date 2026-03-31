import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/achievement_data.dart';
import '../state/game_state.dart';
import '../widgets/glass_panel.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  IconData _iconForType(IconType type) {
    switch (type) {
      case IconType.star:
        return Icons.star_rounded;
      case IconType.sword:
        return Icons.gavel_rounded;
      case IconType.shield:
        return Icons.shield_rounded;
      case IconType.money:
        return Icons.attach_money_rounded;
      case IconType.people:
        return Icons.groups_rounded;
      case IconType.trophy:
        return Icons.emoji_events_rounded;
      case IconType.fire:
        return Icons.local_fire_department_rounded;
      case IconType.crown:
        return Icons.workspace_premium_rounded;
      case IconType.skull:
        return Icons.dangerous_rounded;
      case IconType.building:
        return Icons.domain_rounded;
    }
  }

  Color _colorForCategory(String category) {
    switch (category) {
      case 'combat':
        return const Color(0xFFEF4444);
      case 'missions':
        return const Color(0xFF60A5FA);
      case 'economy':
        return const Color(0xFF34D399);
      case 'social':
        return const Color(0xFFFBBF24);
      default:
        return Colors.white54;
    }
  }

  String _categoryTitle(GameState state, String category) {
    switch (category) {
      case 'combat':
        return state.tt('SAVAS', 'COMBAT');
      case 'missions':
        return state.tt('GOREVLER', 'MISSIONS');
      case 'economy':
        return state.tt('EKONOMI', 'ECONOMY');
      case 'social':
        return state.tt('SOSYAL', 'SOCIAL');
      default:
        return category.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, state, _) {
        final categories = ['combat', 'missions', 'economy', 'social'];

        return Scaffold(
          backgroundColor: const Color(0xFF081428),
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(
              state.tt('BASARIMLAR', 'ACHIEVEMENTS'),
              style: const TextStyle(
                color: Color(0xFFFBBF24),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
            children: [
              // Summary card
              GlassPanel(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _summaryItem(
                      state.tt('Acilan', 'Unlocked'),
                      '${state.claimedAchievements.length + state.unlockedAchievements.length}/${AchievementData.all.length}',
                      const Color(0xFFFBBF24),
                    ),
                    _summaryItem(
                      state.tt('Bekleyen Odul', 'Pending'),
                      '${state.unclaimedAchievementCount}',
                      const Color(0xFF34D399),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              ...categories.expand((cat) {
                final defs =
                    AchievementData.all.where((a) => a.category == cat);
                return [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8, left: 4),
                    child: Text(
                      _categoryTitle(state, cat),
                      style: TextStyle(
                        color: _colorForCategory(cat),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  ...defs.map((def) => _achievementCard(context, state, def)),
                ];
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _achievementCard(
    BuildContext context,
    GameState state,
    AchievementDef def,
  ) {
    final claimed = state.isAchievementClaimed(def.id);
    final unlocked =
        state.isAchievementUnlocked(def.id) && !claimed;
    final ratio = state.achievementRatio(def);
    final progress = state.achievementProgressValue(def);
    final catColor = _colorForCategory(def.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: claimed
            ? const Color(0x1A34D399)
            : unlocked
                ? const Color(0x1AFBBF24)
                : const Color(0xFF0A1630),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: claimed
              ? const Color(0x6634D399)
              : unlocked
                  ? const Color(0xAAFBBF24)
                  : const Color(0xFF1E2D45),
          width: unlocked ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: claimed
                  ? const Color(0xFF34D399).withValues(alpha: 0.15)
                  : catColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: claimed ? const Color(0xFF34D399) : catColor,
                width: 1.5,
              ),
            ),
            child: Icon(
              claimed ? Icons.check_circle_rounded : _iconForType(def.icon),
              color: claimed ? const Color(0xFF34D399) : catColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.tt(def.titleTr, def.titleEn),
                  style: TextStyle(
                    color: claimed
                        ? const Color(0xFF34D399)
                        : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  state.tt(def.descTr, def.descEn),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 6,
                          backgroundColor: const Color(0xFF1E2D45),
                          valueColor: AlwaysStoppedAnimation(
                            claimed
                                ? const Color(0xFF34D399)
                                : unlocked
                                    ? const Color(0xFFFBBF24)
                                    : catColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$progress/${def.target}',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (def.rewardCash > 0 || def.rewardGold > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${def.rewardCash > 0 ? '+\$${def.rewardCash}' : ''}'
                      '${def.rewardGold > 0 ? ' +${def.rewardGold} ${state.tt('Altin', 'Gold')}' : ''}'
                      '${def.rewardXp > 0 ? ' +${def.rewardXp} XP' : ''}',
                      style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Claim button
          if (unlocked)
            SizedBox(
              width: 60,
              child: FilledButton(
                onPressed: () async {
                  final msg = await state.claimAchievement(def.id);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg)),
                  );
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  state.tt('Al', 'Claim'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            )
          else if (claimed)
            const Icon(
              Icons.check_circle,
              color: Color(0xFF34D399),
              size: 24,
            ),
        ],
      ),
    );
  }
}
