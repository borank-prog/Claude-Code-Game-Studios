import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/game_models.dart';
import '../state/game_state.dart';
import '../widgets/format.dart';
import '../widgets/glass_panel.dart';

class _StatLine {
  final String label;
  final String value;
  final Color color;
  const _StatLine(this.label, this.value, this.color);
}

class MarketScreen extends StatelessWidget {
  const MarketScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, state, _) {
        final items = state.availableShopItems();

        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
          children: [
            GlassPanel(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      state.tt('KARA BORSA', 'BLACK MARKET'),
                      style: const TextStyle(
                        color: Color(0xFFFBBF24),
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.monetization_on_outlined,
                        color: Color(0xFFFBBF24),
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        compactNumber(state.gold),
                        style: const TextStyle(
                          color: Color(0xFFFBBF24),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            GlassPanel(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statIndicator(
                    state,
                    state.tt('CAN', 'HP'),
                    '${state.currentTP}/${state.maxTP}',
                    const Color(0xFFEF4444),
                  ),
                  _statIndicator(
                    state,
                    state.tt('ENERJİ', 'ENERGY'),
                    '${state.currentEnerji}/${state.maxEnerji}',
                    const Color(0xFF34D399),
                  ),
                  _statIndicator(
                    state,
                    state.tt('GÜÇ', 'POWER'),
                    '${state.totalPower}',
                    const Color(0xFFA78BFA),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _sectionTitle(state.tt('ACİL HİZMETLER', 'EMERGENCY SERVICES')),
            _premiumCard(
              context,
              state,
              title: state.tt('VIP Tedavi', 'VIP Heal'),
              description: state.tt(
                'Hastane süresini atla, canı anında %100 yap.',
                'Skip hospital timer and restore HP to 100% instantly.',
              ),
              icon: Icons.local_hospital_outlined,
              iconColor: const Color(0xFFEF4444),
              priceGold: state.vipHealGoldCost,
              onPressed: () async => state.buyVipHeal(),
              showSnackBar: false,
              onAfterPressed: (msg) async {
                if (!context.mounted) return;
                if (_isPurchaseSuccess(msg)) {
                  await _showPurchaseDialog(
                    context,
                    state,
                    serviceTitle: state.tt('VIP Tedavi', 'VIP Heal'),
                    serviceDesc: msg,
                    serviceIcon: Icons.local_hospital_outlined,
                    serviceIconColor: const Color(0xFFEF4444),
                  );
                } else {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(msg)));
                }
              },
            ),
            _premiumCard(
              context,
              state,
              title: state.tt('Adrenalin İğnesi', 'Adrenaline Shot'),
              description: state.tt(
                'Biten enerjiyi anında doldur, aksiyona devam et.',
                'Instantly refill depleted energy and continue attacking.',
              ),
              icon: Icons.bolt,
              iconColor: const Color(0xFF60A5FA),
              priceGold: state.energyRushGoldCost,
              onPressed: () async => state.buyEnergyRush(),
              showSnackBar: false,
              onAfterPressed: (msg) async {
                if (!context.mounted) return;
                if (_isPurchaseSuccess(msg)) {
                  await _showPurchaseDialog(
                    context,
                    state,
                    serviceTitle: state.tt(
                      'Adrenalin İğnesi',
                      'Adrenaline Shot',
                    ),
                    serviceDesc: msg,
                    serviceIcon: Icons.bolt,
                    serviceIconColor: const Color(0xFF60A5FA),
                  );
                } else {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(msg)));
                }
              },
            ),
            _premiumCard(
              context,
              state,
              title: state.tt('24 Saatlik VIP Kalkan', '24-Hour VIP Shield'),
              description: state.tt(
                'Bu süre boyunca diğer oyuncular sana saldıramaz.',
                'Other players cannot attack you during this period.',
              ),
              icon: Icons.shield_outlined,
              iconColor: const Color(0xFF22D3EE),
              priceGold: state.vipShieldGoldCost,
              onPressed: () async => state.buyVipShield(),
              trailingNote: state.isVipShieldActive
                  ? state.tt(
                      'Aktif: ${state.shieldSecondsLeft ~/ 3600}s ${(state.shieldSecondsLeft % 3600) ~/ 60}d',
                      'Active: ${state.shieldSecondsLeft ~/ 3600}h ${(state.shieldSecondsLeft % 3600) ~/ 60}m',
                    )
                  : null,
              showSnackBar: false,
              onAfterPressed: (msg) async {
                if (!context.mounted) return;
                if (_isPurchaseSuccess(msg)) {
                  await _showPurchaseDialog(
                    context,
                    state,
                    serviceTitle: state.tt(
                      '24 Saatlik VIP Kalkan',
                      '24-Hour VIP Shield',
                    ),
                    serviceDesc: msg,
                    serviceIcon: Icons.shield_outlined,
                    serviceIconColor: const Color(0xFF22D3EE),
                  );
                } else {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(msg)));
                }
              },
            ),
            _premiumCard(
              context,
              state,
              title: state.tt('Kaçakçı Sandığı', 'Smuggler Crate'),
              description: state.tt(
                'Sandığın en iyi ödülü Magnum Altıpatlar olabilir.',
                'Best possible drop is Magnum Revolver.',
              ),
              icon: Icons.all_inbox_outlined,
              iconColor: const Color(0xFFF59E0B),
              priceGold: state.smugglerCrateGoldCost,
              onPressed: () async => state.openSmugglerCrate(),
              showSnackBar: false,
              onAfterPressed: (msg) async {
                await _showSmugglerResultDialog(context, state, msg);
              },
            ),
            const SizedBox(height: 10),
            _sectionTitle(state.tt('AĞIR SİLAHLAR', 'HEAVY WEAPONS')),
            _premiumWeaponCard(
              context,
              state,
              itemId: 'altin_deagle',
              title: state.tt('Altın Çöl Kartalı', 'Golden Desert Eagle'),
              description: state.tt(
                '+900 Güç. Düşük seviyede çok büyük avantaj.',
                '+900 Power. Very large edge at lower levels.',
              ),
              icon: Icons.gpp_good_outlined,
              iconColor: const Color(0xFFFBBF24),
            ),
            _premiumWeaponCard(
              context,
              state,
              itemId: 'roketatar',
              title: state.tt('RPG-7 Roketatar', 'RPG-7 Launcher'),
              description: state.tt(
                '+10000 Güç. Ağır yıkım kapasitesi.',
                '+10000 Power. Heavy destruction capability.',
              ),
              icon: Icons.whatshot_outlined,
              iconColor: const Color(0xFFFB923C),
            ),
            const SizedBox(height: 10),
            _sectionTitle(state.tt('STANDART MARKET', 'STANDARD MARKET')),
            ...items.map((item) {
              final owned = (state.ownedItems[item.id] ?? 0) > 0;
              final locked = state.level < item.reqLevel;
              final price = item.costGold > 0
                  ? '${item.costGold} ${state.tt('Altın', 'Gold')}'
                  : '\$${item.costCash}';
              return GlassPanel(
                margin: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        item.iconAsset,
                        width: 58,
                        height: 58,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.itemName(item),
                            style: TextStyle(
                              color: locked
                                  ? const Color(0xFF94A3B8)
                                  : Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '+${item.powerBonus} ${state.tt('Güç', 'Power')}',
                            style: const TextStyle(color: Color(0xFF34D399)),
                          ),
                          if (locked)
                            Text(
                              '[${state.tt('Sv.', 'Lv.')} ${item.reqLevel}] ${state.tt('KİLİTLİ', 'LOCKED')}',
                              style: const TextStyle(color: Color(0xFF94A3B8)),
                            ),
                        ],
                      ),
                    ),
                    if (owned)
                      _ownedItemTrailing(context, state, item.id)
                    else
                      FilledButton(
                        onPressed: locked
                            ? null
                            : () async {
                                if (state.isActionLocked) {
                                  await _showActionLockedPopup(context, state);
                                  return;
                                }
                                final ok = await state.buyItem(item.id);
                                if (!context.mounted) return;
                                if (ok) {
                                  await _showPurchaseDialog(
                                    context,
                                    state,
                                    item: item,
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        state.tt(
                                          'Satın alma başarısız.',
                                          'Purchase failed.',
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              },
                        child: Text(price),
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

  Widget _ownedItemTrailing(
    BuildContext context,
    GameState state,
    String itemId,
  ) {
    final dur = state.itemDurabilityPercent(itemId);
    final repairCost = state.repairItemGoldCost(itemId);
    final Color barColor = dur > 60
        ? const Color(0xFF34D399)
        : dur > 30
            ? const Color(0xFFFBBF24)
            : const Color(0xFFEF4444);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '%$dur',
          style: TextStyle(
            color: barColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: 56,
          child: LinearProgressIndicator(
            value: dur / 100,
            color: barColor,
            backgroundColor: const Color(0xFF1E2D45),
            minHeight: 5,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        if (repairCost > 0)
          GestureDetector(
            onTap: () async {
              final msg = await state.repairItemWithGold(itemId);
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(msg)));
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.build_circle_outlined,
                    color: Color(0xFFFBBF24),
                    size: 13,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '$repairCost ${state.tt('Altın', 'Gold')}',
                    style: const TextStyle(
                      color: Color(0xFFFBBF24),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 6),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFD1D5DB),
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _statIndicator(
    GameState state,
    String label,
    String value,
    Color valueColor,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Future<void> _showPurchaseDialog(
    BuildContext context,
    GameState state, {
    ItemDef? item,
    String? serviceTitle,
    String? serviceDesc,
    IconData? serviceIcon,
    Color serviceIconColor = const Color(0xFF34D399),
    List<_StatLine> extraStats = const [],
  }) async {
    final isItem = item != null;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xEE0F1B33),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF34D399), width: 1.4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.tt('SATIN ALINDI!', 'PURCHASED!'),
                style: const TextStyle(
                  color: Color(0xFF34D399),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 14),
              if (isItem)
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A1630),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF34D399),
                      width: 1.2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      item.iconAsset,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.inventory_2_outlined,
                        color: const Color(0xFF34D399),
                        size: 48,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: serviceIconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: serviceIconColor, width: 1.5),
                  ),
                  child: Icon(
                    serviceIcon ?? Icons.check_circle,
                    color: serviceIconColor,
                    size: 38,
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                isItem ? state.itemName(item) : (serviceTitle ?? ''),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    if (isItem) ...[
                      _statRow(
                        state.tt('Güç Bonusu', 'Power Bonus'),
                        '+${item.powerBonus}',
                        const Color(0xFF34D399),
                      ),
                      _statRow(
                        state.tt('Tür', 'Type'),
                        _itemTypeName(state, item.type),
                        const Color(0xFF60A5FA),
                      ),
                      _statRow(
                        state.tt('Min. Seviye', 'Min. Level'),
                        '${item.reqLevel}',
                        const Color(0xFFA78BFA),
                      ),
                      if (item.costGold > 0)
                        _statRow(
                          state.tt('Fiyat', 'Price'),
                          '${item.costGold} ${state.tt('Altın', 'Gold')}',
                          const Color(0xFFFBBF24),
                        )
                      else
                        _statRow(
                          state.tt('Fiyat', 'Price'),
                          '\$${item.costCash}',
                          const Color(0xFFFBBF24),
                        ),
                    ] else ...[
                      if (serviceDesc != null)
                        Text(
                          serviceDesc,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                          ),
                        ),
                    ],
                    ...extraStats.map(
                      (s) => _statRow(s.label, s.value, s.color),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF34D399),
                    foregroundColor: Colors.black,
                  ),
                  child: Text(
                    state.tt('Harika!', 'Awesome!'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  String _itemTypeName(GameState state, String type) {
    return switch (type) {
      'weapon' => state.tt('Silah', 'Weapon'),
      'armor' => state.tt('Zırh', 'Armor'),
      'vehicle' => state.tt('Araç', 'Vehicle'),
      'knife' => state.tt('Yakın Dövüş', 'Melee'),
      _ => type,
    };
  }

  Widget _premiumCard(
    BuildContext context,
    GameState state, {
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required int priceGold,
    required Future<String> Function() onPressed,
    String? trailingNote,
    bool showSnackBar = true,
    Future<void> Function(String message)? onAfterPressed,
  }) {
    return GlassPanel(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.18),
              border: Border.all(color: iconColor.withValues(alpha: 0.5)),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                  ),
                ),
                if (trailingNote != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      trailingNote,
                      style: const TextStyle(
                        color: Color(0xFF34D399),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
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
              final msg = await onPressed();
              if (!context.mounted) return;
              if (showSnackBar) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(msg)));
              }
              if (onAfterPressed != null) {
                await onAfterPressed(msg);
              }
            },
            child: Text(
              '$priceGold ${state.tt('Altın', 'Gold')}',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _premiumWeaponCard(
    BuildContext context,
    GameState state, {
    required String itemId,
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
  }) {
    final list = state.availableShopItems();
    ItemDef? item;
    for (final it in list) {
      if (it.id == itemId) {
        item = it;
        break;
      }
    }
    if (item == null) {
      return const SizedBox.shrink();
    }
    final owned = (state.ownedItems[itemId] ?? 0) > 0;

    return _premiumCard(
      context,
      state,
      title: title,
      description: description,
      icon: icon,
      iconColor: iconColor,
      priceGold: item.costGold,
      onPressed: () async {
        if (owned) {
          return state.tt('Bu eşya zaten sende.', 'You already own this item.');
        }
        return state.buyVipWeaponById(itemId);
      },
      trailingNote: owned
          ? state.tt('Envanterde', 'Owned')
          : '+${item.powerBonus} ${state.tt('Güç', 'Power')}',
      showSnackBar: false,
      onAfterPressed: (msg) async {
        if (!context.mounted) return;
        if (_isPurchaseSuccess(msg)) {
          await _showPurchaseDialog(context, state, item: item);
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
      },
    );
  }

  bool _isPurchaseSuccess(String msg) {
    final lower = msg.toLowerCase();
    return !lower.contains('yok') &&
        !lower.contains('not enough') &&
        !lower.contains('geçersiz') &&
        !lower.contains('invalid') &&
        !lower.contains('zaten sende') &&
        !lower.contains('already own') &&
        !lower.contains('başarısız') &&
        !lower.contains('failed');
  }

  Future<void> _showSmugglerResultDialog(
    BuildContext context,
    GameState state,
    String message,
  ) async {
    final rewardId = state.lastCrateRewardItemId;
    ItemDef? rewardItem;
    for (final item in state.availableShopItems()) {
      if (item.id == rewardId) {
        rewardItem = item;
        break;
      }
    }

    final rewardName = rewardItem != null
        ? state.itemName(rewardItem)
        : state.tt('Bilinmeyen Ödül', 'Unknown Reward');
    final imageAsset =
        rewardItem?.iconAsset ??
        'assets/art/items/equipment_icons/altin_deagle.png';

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: BoxDecoration(
              color: const Color(0xEE13233E),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF59E0B), width: 1.4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.lastCrateJackpot
                      ? state.tt('JACKPOT!', 'JACKPOT!')
                      : state.tt(
                          'KAÇAKÇI SANDIĞI AÇILDI',
                          'SMUGGLER CRATE OPENED',
                        ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: state.lastCrateJackpot
                        ? const Color(0xFFFBBF24)
                        : const Color(0xFF93C5FD),
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A1630),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFFBBF24),
                      width: 1.2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(imageAsset, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  rewardName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFE5E7EB),
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                if (state.lastCrateDuplicateCompensation > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    state.tt(
                      'Tekrar eşya: +\$${state.lastCrateDuplicateCompensation}',
                      'Duplicate item: +\$${state.lastCrateDuplicateCompensation}',
                    ),
                    style: const TextStyle(
                      color: Color(0xFF34D399),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFBBF24),
                      foregroundColor: Colors.black,
                    ),
                    child: Text(state.tt('Kapat', 'Close')),
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
