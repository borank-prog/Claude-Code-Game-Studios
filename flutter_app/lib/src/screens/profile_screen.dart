import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/game_models.dart';
import '../state/game_state.dart';
import '../widgets/format.dart';
import '../widgets/glass_panel.dart';
import '../widgets/item_asset_image.dart';
import 'gang_chat_screen.dart';
import 'gang_leaderboard_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _snack(BuildContext context, String text) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

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

  Future<void> _copyPlayerId(BuildContext context, GameState state) async {
    final id = state.userId.trim();
    if (id.isEmpty) {
      _snack(
        context,
        state.tt('Oyuncu ID bulunamadı.', 'Player ID not found.'),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: id));
    if (!context.mounted) return;
    _snack(context, state.tt('Oyuncu ID kopyalandı.', 'Player ID copied.'));
  }

  Future<void> _promptAddFriend(BuildContext context, GameState state) async {
    final ctrl = TextEditingController();
    final entered = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111a2e),
        title: Text(
          state.tt('Arkadaş Ekle', 'Add Friend'),
          style: const TextStyle(color: Color(0xFFFBBF24)),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: state.tt('Oyuncu UID gir', 'Enter player UID'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(state.tt('Vazgeç', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: Text(state.tt('Ekle', 'Add')),
          ),
        ],
      ),
    );
    final uid = entered?.trim() ?? '';
    if (uid.isEmpty) return;
    final ok = await state.sendFriendRequest(uid);
    if (!context.mounted) return;
    _snack(
      context,
      ok
          ? state.tt('Arkadaş isteği gönderildi.', 'Friend request sent.')
          : state.tt('İstek gönderilemedi.', 'Request failed.'),
    );
  }

  Future<void> _repairItem(
    BuildContext context,
    GameState state,
    ItemDef item,
  ) async {
    if (state.isActionLocked) {
      await _showActionLockedPopup(context, state);
      return;
    }
    final msg = await state.repairItemWithGold(item.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _equipItem(
    BuildContext context,
    GameState state,
    ItemDef item, {
    String? preferredSlot,
  }) async {
    if (state.isActionLocked) {
      await _showActionLockedPopup(context, state);
      return;
    }
    final ok = await state.equipOwnedItem(
      item.id,
      preferredSlot: preferredSlot,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? state.tt(
                  '${state.itemName(item)} kuşanıldı.',
                  '${state.itemName(item)} equipped.',
                )
              : state.tt(
                  'Bu eşya kuşanılamadı.',
                  'This item could not be equipped.',
                ),
        ),
      ),
    );
  }

  Future<void> _equipItemById(
    BuildContext context,
    GameState state,
    String itemId, {
    String? preferredSlot,
  }) async {
    final item = state.availableShopItems().firstWhere(
      (e) => e.id == itemId,
      orElse: () => const ItemDef(
        id: '',
        name: '',
        type: '',
        powerBonus: 0,
        costCash: 0,
        costGold: 0,
        reqLevel: 1,
        iconAsset: 'assets/art/items/profile_cards/bos_slot_1.png',
      ),
    );
    if (item.id.isEmpty) return;
    await _equipItem(
      context,
      state,
      item,
      preferredSlot: preferredSlot ?? state.suggestedSlotForItem(item),
    );
  }

  Future<void> _openSlotPicker(
    BuildContext context,
    GameState state,
    String slot,
  ) async {
    if (state.isActionLocked) {
      await _showActionLockedPopup(context, state);
      return;
    }
    final candidates = state.equipCandidatesForSlot(slot);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F1B33),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: mq.size.height * 0.75),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: Text(
                    '${state.slotName(slot)} ${state.tt('Seç', 'Select')}',
                    style: const TextStyle(
                      color: Color(0xFFFBBF24),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        if (candidates.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              state.tt(
                                'Bu slot için envanterinde eşya yok.',
                                'No inventory item for this slot.',
                              ),
                              style: const TextStyle(color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ...candidates.map((item) {
                          final current =
                              (state.equipped[slot] ?? '') == item.id;
                          final durability = state.itemDurabilityPercent(
                            item.id,
                          );
                          final repairCost = state.repairItemGoldCost(item.id);
                          return ListTile(
                            isThreeLine: true,
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: ItemAssetImage(
                                candidates: itemAssetCandidates(item),
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                placeholder: const Icon(
                                  Icons.inventory_2_outlined,
                                  color: Color(0xFF4B5563),
                                  size: 22,
                                ),
                              ),
                            ),
                            title: Text(
                              state.itemName(item),
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              '+${item.powerBonus} ${state.tt('Güç', 'Power')}  •  ${state.tt('Dayanıklılık', 'Durability')}: %$durability',
                              style: const TextStyle(color: Color(0xFF34D399)),
                            ),
                            trailing: SizedBox(
                              width: 152,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (repairCost > 0)
                                    IconButton(
                                      tooltip:
                                          '${state.tt('Tamir et', 'Repair')} (-$repairCost ${state.tt('Altın', 'Gold')})',
                                      onPressed: () async {
                                        await _repairItem(context, state, item);
                                      },
                                      icon: const Icon(
                                        Icons.build_circle_outlined,
                                        color: Color(0xFFFBBF24),
                                      ),
                                    ),
                                  if (current)
                                    Text(
                                      state.tt('Kuşanılı', 'Equipped'),
                                      style: const TextStyle(
                                        color: Color(0xFFFBBF24),
                                      ),
                                    )
                                  else
                                    FilledButton(
                                      onPressed: () async {
                                        if (state.isActionLocked) {
                                          await _showActionLockedPopup(
                                            context,
                                            state,
                                          );
                                          return;
                                        }
                                        await state.equipOwnedItem(
                                          item.id,
                                          preferredSlot: slot,
                                        );
                                        if (!context.mounted) return;
                                        Navigator.of(ctx).pop();
                                      },
                                      child: Text(state.tt('Kuşan', 'Equip')),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 6),
                        TextButton.icon(
                          onPressed: () async {
                            if (state.isActionLocked) {
                              await _showActionLockedPopup(context, state);
                              return;
                            }
                            await state.unequipSlot(slot);
                            if (!context.mounted) return;
                            Navigator.of(ctx).pop();
                          },
                          icon: const Icon(Icons.remove_circle_outline),
                          label: Text(state.tt('Slotu Boşalt', 'Clear Slot')),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, state, _) {
        final avatar = state.avatar;
        final xpRate = state.xpToNext == 0
            ? 0.0
            : (state.xp / state.xpToNext).clamp(0.0, 1.0);
        final tpRate = state.maxTP == 0
            ? 0.0
            : (state.currentTP / state.maxTP).clamp(0.0, 1.0);
        final enerjiRate = state.maxEnerji == 0
            ? 0.0
            : (state.currentEnerji / state.maxEnerji).clamp(0.0, 1.0);

        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 120),
          children: [
            // ── HUD Şeridi ───────────────────────────────────────────
            _buildHud(context, state, tpRate, enerjiRate, xpRate),
            const SizedBox(height: 12),

            // ── Karakter kartı ───────────────────────────────────────
            _buildCharacterCard(context, state, avatar),
            const SizedBox(height: 12),

            // ── Özellikler ───────────────────────────────────────────
            _buildAttributes(context, state),
            const SizedBox(height: 10),

            // ── Ekipman slotları ─────────────────────────────────────
            _buildEquipmentGrid(context, state),
            const SizedBox(height: 10),

            // ── Envanter ─────────────────────────────────────────────
            _buildInventory(context, state),
            const SizedBox(height: 10),
            _buildFriendsSection(context, state),
            const SizedBox(height: 10),
            _buildCartelSection(context, state),
          ],
        );
      },
    );
  }

  // ── HUD şeridi ────────────────────────────────────────────────────────────
  Widget _buildHud(
    BuildContext context,
    GameState state,
    double tpRate,
    double enerjiRate,
    double xpRate,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 42, 14, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xDD0A1630), Color(0xBB0A1630)],
        ),
      ),
      child: Column(
        children: [
          // Seviye | Rütbe — Güç
          Row(
            children: [
              Text(
                'Sv. ${state.level} | ${state.tt('Rütbe', 'Rank')}: ${state.rankName}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${state.tt('Güç', 'Power')}: ${state.totalPower}',
                style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // TP bar
          _hudBar(
            tpRate,
            const Color(0xFFEF4444),
            'TP ${state.currentTP}/${state.maxTP}',
            null,
          ),
          const SizedBox(height: 4),
          // Enerji bar
          _hudBar(
            enerjiRate,
            const Color(0xFF26D79C),
            '${state.tt('Enerji', 'Energy')} ${state.currentEnerji}/${state.maxEnerji}',
            '${state.xp}/${state.xpToNext} XP',
          ),
          const SizedBox(height: 4),
          // XP bar
          _hudBar(xpRate, const Color(0xFF60A5FA), null, null),
          const SizedBox(height: 10),
          // Nakit | Altın
          Row(
            children: [
              const Icon(
                Icons.attach_money,
                color: Color(0xFF34D399),
                size: 18,
              ),
              const SizedBox(width: 2),
              Text(
                '${state.tt('Nakit', 'Cash')}: \$${compactNumber(state.cash)}',
                style: const TextStyle(
                  color: Color(0xFF34D399),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.workspace_premium,
                color: Color(0xFFFBBF24),
                size: 18,
              ),
              const SizedBox(width: 2),
              Text(
                '${state.tt('Altın', 'Gold')}: ${compactNumber(state.gold)}',
                style: const TextStyle(
                  color: Color(0xFFFBBF24),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Ayarlar | Çıkış (kaldırıldı)
        ],
      ),
    );
  }

  Widget _hudBar(
    double value,
    Color color,
    String? leftLabel,
    String? rightLabel,
  ) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 10,
            backgroundColor: const Color(0xFF0A1630),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        if (leftLabel != null || rightLabel != null) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              if (leftLabel != null)
                Text(
                  leftLabel,
                  style: const TextStyle(
                    color: Color(0xFFD1D5DB),
                    fontSize: 11,
                  ),
                ),
              const Spacer(),
              if (rightLabel != null)
                Text(
                  rightLabel,
                  style: const TextStyle(
                    color: Color(0xFFD1D5DB),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  // ── Karakter kartı ────────────────────────────────────────────────────────
  Widget _buildCharacterCard(
    BuildContext context,
    GameState state,
    AvatarClass avatar,
  ) {
    final showPenaltyPanel =
        state.jailSecondsLeft > 0 || state.hospitalSecondsLeft > 0;
    return Center(
      child: Column(
        children: [
          // Portre
          Container(
            width: 150,
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFBBF24), width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.25),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                avatar.portraitAsset,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFF0A1630),
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFF4B5563),
                    size: 60,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (showPenaltyPanel) ...[
            _buildPenaltyPanel(context, state),
            const SizedBox(height: 10),
          ],
          // İsim
          Text(
            state.displayPlayerName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          // Rütbe badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x33FBBF24),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x88FBBF24)),
            ),
            child: Text(
              '${state.tt('Rütbe', 'Rank')} ${state.rank} — ${state.rankName}',
              style: const TextStyle(
                color: Color(0xFFFBBF24),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Güç badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x33EF4444),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x88EF4444)),
            ),
            child: Text(
              '⚔️ ${state.tt('Güç', 'Power')}: ${state.totalPower}',
              style: const TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // UID — tıkla kopyala
          if (state.userId.isNotEmpty)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: state.userId));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.tt('UID kopyalandı', 'UID copied')),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.userId,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.copy_rounded,
                      size: 13,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),
          // Durum etiketleri
          if (state.isVipShieldActive || state.isHospitalized) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (state.isVipShieldActive)
                  _statusBadge(
                    '🛡️ ${state.tt('Kalkan Aktif', 'Shield Active')}',
                    const Color(0xFF60A5FA),
                  ),
                if (state.isVipShieldActive && state.isHospitalized)
                  const SizedBox(width: 6),
                if (state.isHospitalized)
                  _statusBadge(
                    '🏥 ${state.tt('Hastanelik', 'Hospitalized')}',
                    const Color(0xFFEF4444),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPenaltyPanel(BuildContext context, GameState state) {
    final inJail = state.jailSecondsLeft > 0;
    final title = inJail
        ? state.tt('HAPİSTESİN', 'YOU ARE IN JAIL')
        : state.tt('HASTANEDESİN', 'YOU ARE IN HOSPITAL');
    final borderColor = inJail
        ? const Color(0xFFEF4444)
        : const Color(0xFFFB7185);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xCC10203A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withValues(alpha: 0.7)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: borderColor,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          StreamBuilder<int>(
            stream: Stream<int>.periodic(
              const Duration(seconds: 1),
              (_) => DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
            initialData: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            builder: (context, snap) {
              final nowEpoch =
                  snap.data ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
              final left = inJail
                  ? (state.jailUntilEpoch - nowEpoch).clamp(0, 999999)
                  : (state.hospitalUntilEpoch - nowEpoch).clamp(0, 999999);
              return Text(
                '${state.tt('Kalan Süre', 'Time Left')}: ${secondsToClock(left)}',
                style: const TextStyle(
                  color: Color(0xFFFCA5A5),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                final beforeGold = state.gold;
                if (inJail) {
                  await state.payJailWithGold();
                } else {
                  await state.payHospitalWithGold();
                }
                if (!context.mounted) return;
                if (state.gold == beforeGold) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        state.tt('Yeterli altının yok!', 'Not enough gold!'),
                      ),
                    ),
                  );
                }
              },
              child: Text(
                inJail
                    ? '${state.jailSkipGoldCost} ${state.tt('Altın Öde ve Çık', 'Pay Gold & Exit')}'
                    : '${state.hospitalSkipGoldCost} ${state.tt('Altın Öde ve Çık', 'Pay Gold & Exit')}',
              ),
            ),
          ),
          if (!inJail) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  final msg = await state.buyVipHeal();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(msg)));
                },
                child: Text(
                  '${state.vipHealGoldCost} ${state.tt('Altın VIP Tedavi', 'Gold VIP Heal')}',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ── Özellikler ────────────────────────────────────────────────────────────
  Widget _buildAttributes(BuildContext context, GameState state) {
    return GlassPanel(
      child: Column(
        children: [
          Row(
            children: [
              Text(
                state.tt('ÖZELLİKLER', 'ATTRIBUTES'),
                style: const TextStyle(
                  color: Color(0xFFD1D5DB),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${state.tt('Stat Puanları', 'Stat Points')}: ${state.statPoints}',
                style: const TextStyle(
                  color: Color(0xFFFBBF24),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildStatRow(
            context,
            state,
            icon: Icons.bolt,
            titleTr: 'Güç',
            titleEn: 'Power',
            value: state.statPower,
            bonusText: '+${state.statPower * 3} ${state.tt('güç', 'power')}',
            statKey: 'power',
          ),
          const SizedBox(height: 6),
          _buildStatRow(
            context,
            state,
            icon: Icons.favorite,
            titleTr: 'Dayanıklılık',
            titleEn: 'Vitality',
            value: state.statVitality,
            bonusText:
                '+${state.statVitality * 6} ${state.tt('TP sınırı', 'max TP')}',
            statKey: 'vitality',
          ),
          const SizedBox(height: 6),
          _buildStatRow(
            context,
            state,
            icon: Icons.flash_on,
            titleTr: 'Enerji',
            titleEn: 'Energy',
            value: state.statEnergy,
            bonusText:
                '+${state.statEnergy * 5} ${state.tt('enerji sınırı', 'max energy')}',
            statKey: 'energy',
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(
    BuildContext context,
    GameState state, {
    required IconData icon,
    required String titleTr,
    required String titleEn,
    required int value,
    required String bonusText,
    required String statKey,
  }) {
    final canSpend = state.statPoints > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x2214213B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x337F8EA8)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFFFBBF24)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${state.tt(titleTr, titleEn)}: $value',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  bonusText,
                  style: const TextStyle(
                    color: Color(0xFF34D399),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 30,
            child: FilledButton(
              onPressed: !canSpend
                  ? null
                  : () async {
                      if (state.isActionLocked) {
                        await _showActionLockedPopup(context, state);
                        return;
                      }
                      final ok = await state.spendStatPoint(statKey);
                      if (!context.mounted || ok) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            state.tt(
                              'Stat puanı yok.',
                              'No stat points available.',
                            ),
                          ),
                        ),
                      );
                    },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFBBF24),
                foregroundColor: const Color(0xFF111827),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 0,
                ),
              ),
              child: const Text('+'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Ekipman slotları ──────────────────────────────────────────────────────
  Widget _buildEquipmentGrid(BuildContext context, GameState state) {
    const slots = ['weapon', 'armor', 'knife', 'vehicle'];
    final visibleSlots = slots.where((slot) {
      final id = state.equipped[slot];
      if (id == null) return false;
      final trimmed = id.trim();
      if (trimmed.isEmpty) return false;
      if (trimmed == 'bos_slot') return false;
      if (trimmed == 'empty') return false;
      return true;
    }).toList();

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                color: Color(0xFFFBBF24),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                state.tt('EKİPMAN', 'EQUIPMENT'),
                style: const TextStyle(
                  color: Color(0xFFFBBF24),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '+${state.equipmentPower} ${state.tt('güç', 'power')}',
                style: const TextStyle(
                  color: Color(0xFF34D399),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (visibleSlots.isEmpty)
            DragTarget<String>(
              onAcceptWithDetails: (details) async {
                await _equipItemById(context, state, details.data);
              },
              builder: (context, candidates, rejects) => Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: candidates.isNotEmpty
                        ? const Color(0xFFFBBF24)
                        : const Color(0x557F8EA8),
                  ),
                  color: candidates.isNotEmpty
                      ? const Color(0x22FBBF24)
                      : const Color(0x2214213B),
                ),
                child: Text(
                  state.tt(
                    'Henüz kuşanılmış eşya yok.\nEnvanterdeki eşyayı basılı tutup buraya sürükle veya eşyaya dokunarak kuşan.',
                    'No equipped items yet.\nDrag an inventory item here or tap an item to equip it.',
                  ),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          else
            GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.85,
              children: visibleSlots.map((slot) {
                final itemId = state.equipped[slot] ?? '';
                final ItemDef item = state.availableShopItems().firstWhere(
                  (e) => e.id == itemId,
                  orElse: () => const ItemDef(
                    id: '',
                    name: '',
                    type: '',
                    powerBonus: 0,
                    costCash: 0,
                    costGold: 0,
                    reqLevel: 1,
                    iconAsset: 'assets/art/items/profile_cards/bos_slot_1.png',
                  ),
                );

                return DragTarget<String>(
                  onAcceptWithDetails: (details) async {
                    await _equipItemById(
                      context,
                      state,
                      details.data,
                      preferredSlot: slot,
                    );
                  },
                  builder: (context, candidates, rejects) => InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openSlotPicker(context, state, slot),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: candidates.isNotEmpty
                              ? const Color(0xFFFBBF24)
                              : const Color(0x88FBBF24),
                          width: 1.5,
                        ),
                        color: candidates.isNotEmpty
                            ? const Color(0x33FBBF24)
                            : const Color(0x22FBBF24),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: ItemAssetImage(
                                candidates: itemAssetCandidates(item),
                                fit: BoxFit.contain,
                                width: double.infinity,
                                placeholder: const Icon(
                                  Icons.inventory_2_outlined,
                                  color: Color(0xFF4B5563),
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            state.slotName(slot),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            state.itemName(item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFFBBF24),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${state.tt('Dur', 'Dur')}: %${state.itemDurabilityPercent(item.id)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ── Envanter ──────────────────────────────────────────────────────────────
  Widget _buildInventory(BuildContext context, GameState state) {
    final inv = state.ownedInventoryItems();
    final availableInv = inv
        .where((item) => !state.equipped.values.contains(item.id))
        .toList();

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.backpack_outlined,
                color: Color(0xFFD1D5DB),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                state.tt('ENVANTER', 'INVENTORY'),
                style: const TextStyle(
                  color: Color(0xFFD1D5DB),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${availableInv.length} ${state.tt('eşya', 'items')}',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (availableInv.isEmpty) ...[
            Text(
              state.tt(
                'Boşta eşyan yok. Kuşanılmayan eşyalar burada görünür.',
                'No free items. Unequipped items appear here.',
              ),
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.92,
              ),
              itemCount: availableInv.length,
              itemBuilder: (_, index) {
                final item = availableInv[index];
                final targetSlot = state.suggestedSlotForItem(item);
                return LongPressDraggable<String>(
                  data: item.id,
                  feedback: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: 82,
                      height: 86,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFBBF24)),
                        color: const Color(0xFF0F1B33),
                      ),
                      child: ItemAssetImage(
                        candidates: itemAssetCandidates(item),
                        fit: BoxFit.contain,
                        placeholder: const Icon(
                          Icons.inventory_2_outlined,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.35,
                    child: _inventoryItemCard(state, item),
                  ),
                  child: InkWell(
                    onTap: () => _equipItem(
                      context,
                      state,
                      item,
                      preferredSlot: targetSlot,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    child: _inventoryItemCard(state, item),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ── Arkadaşlar (Profilde) ────────────────────────────────────────────────
  Widget _buildFriendsSection(BuildContext context, GameState state) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.people_alt_outlined,
                color: Color(0xFFFBBF24),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                state.tt('ARKADAŞLAR', 'FRIENDS'),
                style: const TextStyle(
                  color: Color(0xFFFBBF24),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _copyPlayerId(context, state),
                icon: const Icon(Icons.copy_rounded, size: 15),
                label: Text(state.tt('ID Kopyala', 'Copy ID')),
              ),
            ],
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Text(
              'Oyuncu ID: ${state.userId.isEmpty ? '-' : state.userId}',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _promptAddFriend(context, state),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: Text(state.tt('Arkadaş Ekle', 'Add Friend')),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            state.tt('Gelen İstekler', 'Incoming Requests'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          if (state.incomingRequests.isEmpty)
            Text(
              state.tt('Bekleyen istek yok.', 'No pending requests.'),
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            )
          else
            ...state.incomingRequests.map((r) {
              final rid = r['id']?.toString() ?? '';
              final from =
                  r['fromName']?.toString() ?? r['fromId']?.toString() ?? '-';
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        from,
                        style: const TextStyle(color: Color(0xFFD1D5DB)),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await state.acceptFriendRequest(rid);
                        if (!context.mounted) return;
                        _snack(
                          context,
                          state.tt('Arkadaş eklendi.', 'Friend added.'),
                        );
                      },
                      child: Text(state.tt('Kabul', 'Accept')),
                    ),
                    TextButton(
                      onPressed: () async {
                        await state.rejectFriendRequest(rid);
                        if (!context.mounted) return;
                        _snack(
                          context,
                          state.tt('İstek reddedildi.', 'Request rejected.'),
                        );
                      },
                      child: Text(state.tt('Red', 'Reject')),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 10),
          Text(
            state.tt('Arkadaş Listesi', 'Friend List'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          if (state.friends.isEmpty)
            Text(
              state.tt('Henüz arkadaşın yok.', 'You have no friends yet.'),
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            )
          else
            ...state.friends.map((f) {
              final friendUid = (f['uid']?.toString() ?? '').trim();
              final friendName = (f['displayName']?.toString() ?? '').trim();
              final display = friendName.isEmpty ? friendUid : friendName;
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '- $display',
                        style: const TextStyle(color: Color(0xFF34D399)),
                      ),
                    ),
                    TextButton(
                      onPressed: friendUid.isEmpty
                          ? null
                          : () async {
                              final ok = await state.removeFriend(
                                friendUid,
                                friendName: display,
                              );
                              if (!context.mounted) return;
                              _snack(
                                context,
                                ok
                                    ? state.tt(
                                        '$display arkadaşlıktan çıkarıldı.',
                                        '$display removed from friends.',
                                      )
                                    : state.tt(
                                        'Arkadaş çıkarılamadı.',
                                        'Could not remove friend.',
                                      ),
                              );
                            },
                      child: Text(
                        state.tt('Çıkar', 'Remove'),
                        style: const TextStyle(
                          color: Color(0xFFF87171),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── Kartel (Profilde) ────────────────────────────────────────────────────
  Widget _buildCartelSection(BuildContext context, GameState state) {
    final hasCartel =
        state.gangId.trim().isNotEmpty ||
        ((state.currentGang?['name']?.toString() ?? '').trim().isNotEmpty);
    if (!hasCartel) {
      return GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.groups_rounded,
                  color: Color(0xFFFBBF24),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  state.tt('KARTEL', 'CARTEL'),
                  style: const TextStyle(
                    color: Color(0xFFFBBF24),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              state.tt(
                'Henüz bir kartelde değilsin.',
                'You are not in a cartel yet.',
              ),
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final gangName =
        (state.currentGang?['name']?.toString() ?? '').trim().isEmpty
        ? state.tt('Çete', 'Gang')
        : state.currentGang!['name'].toString().trim();

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.groups_rounded,
                color: Color(0xFFFBBF24),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                state.tt('KARTEL', 'CARTEL'),
                style: const TextStyle(
                  color: Color(0xFFFBBF24),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  final gangId = state.gangId.trim();
                  if (gangId.isEmpty) return;
                  await Clipboard.setData(ClipboardData(text: gangId));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        state.tt('Kartel ID kopyalandı.', 'Cartel ID copied.'),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 15),
                label: Text(state.tt('ID Kopyala', 'Copy ID')),
              ),
            ],
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x2214213B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x557F8EA8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gangName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${state.tt('Rütbe', 'Rank')}: ${state.gangRank}   •   ${state.tt('Toplam Güç', 'Total Power')}: ${state.totalGangPower}',
                  style: const TextStyle(
                    color: Color(0xFFFBBF24),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${state.tt('Kasa', 'Vault')}: \$${state.gangVault}   •   ${state.tt('Saygınlık', 'Respect')}: ${state.gangRespectPoints}',
                  style: const TextStyle(
                    color: Color(0xFF34D399),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${state.tt('Aktif Üye', 'Online Members')}: ${state.onlineGangMembers}/${state.gangMembers.length}',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GangChatScreen(
                          roomId: state.gangId,
                          roomName: gangName,
                          currentUid: state.userId,
                          currentName: state.playerName,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: Text(state.tt('Kartel Sohbeti', 'Cartel Chat')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const GangLeaderboardScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.emoji_events_outlined, size: 18),
                  label: Text(state.tt('Kartel Sırası', 'Cartel Rank')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: state.leaveGang,
              child: Text(
                state.tt('Kartelden Ayrıl', 'Leave Cartel'),
                style: const TextStyle(color: Color(0xFFF87171)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inventoryItemCard(GameState state, ItemDef item) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x557F8EA8), width: 1),
        color: const Color(0x2214213B),
      ),
      child: Column(
        children: [
          Expanded(
            child: ItemAssetImage(
              candidates: itemAssetCandidates(item),
              fit: BoxFit.contain,
              width: double.infinity,
              placeholder: const Icon(
                Icons.inventory_2_outlined,
                color: Color(0xFF4B5563),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            state.itemName(item),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFD1D5DB),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '${state.tt('Dur', 'Dur')}: %${state.itemDurabilityPercent(item.id)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF34D399),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
