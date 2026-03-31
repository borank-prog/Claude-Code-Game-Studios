import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/attack_type.dart';
import '../services/gang_raid_service.dart';
import '../services/pvp_service.dart';
import '../state/game_state.dart';
import 'attack_result_sheet.dart';
import 'gang_raid_lobby_sheet.dart';

class AttackConfirmSheet extends StatefulWidget {
  final String targetId;
  final String targetName;
  final int targetPower;
  final int attackerPower;
  final String attackerId;
  final String attackerName;

  const AttackConfirmSheet({
    super.key,
    required this.targetId,
    required this.targetName,
    required this.targetPower,
    required this.attackerPower,
    required this.attackerId,
    required this.attackerName,
  });

  @override
  State<AttackConfirmSheet> createState() => _AttackConfirmSheetState();
}

class _AttackConfirmSheetState extends State<AttackConfirmSheet> {
  AttackType _selectedType = AttackType.quick;
  bool _loading = false;
  String? _errorMsg;
  final _pvp = PvpService();

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

  Future<void> _launch() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      final state = context.read<GameState>();
      if (state.isActionLocked) {
        await _showActionLockedPopup(state);
        setState(() {
          _loading = false;
        });
        return;
      }
      if (!state.hasEnoughEnergyForAttack) {
        setState(() {
          _errorMsg = 'Saldırı için enerji yetersiz.';
          _loading = false;
        });
        return;
      }

      final block = await _pvp.canAttack(
        attackerId: widget.attackerId,
        targetId: widget.targetId,
      );
      if (block != null) {
        setState(() {
          _errorMsg = block;
          _loading = false;
        });
        return;
      }

      if (_selectedType == AttackType.gang) {
        final raidSvc = GangRaidService();
        final raid = await raidSvc.createRaid(
          leaderId: widget.attackerId,
          targetId: widget.targetId,
          leaderName: widget.attackerName,
        );
        if (!mounted) return;
        Navigator.pop(context);
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => GangRaidLobbySheet(
            raid: raid,
            currentUserId: widget.attackerId,
            currentUserName: widget.attackerName,
            totalPower: widget.attackerPower,
            targetPower: widget.targetPower,
          ),
        );
        return;
      }

      final result = await _pvp.executeAttack(
        attackerId: widget.attackerId,
        targetId: widget.targetId,
        attackerName: widget.attackerName,
        targetName: widget.targetName,
        type: _selectedType,
        attackerPower: widget.attackerPower,
        targetPower: widget.targetPower,
        equipmentBonus: _selectedType == AttackType.planned ? 15 : 0,
        attackCost: state.attackEnergyCost,
      );
      await state.applyAttackItemWear(reason: 'online_pvp_attack');
      if (result.remainingEnergy != null) {
        await state.syncAttackEnergyFromServer(
          remainingEnergy: result.remainingEnergy!,
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AttackResultSheet(result: result),
      );
    } catch (e) {
      final raw = e.toString();
      final clean = raw.startsWith('Exception: ') ? raw.substring(11) : raw;
      setState(() {
        _errorMsg = clean.isEmpty ? 'Bir hata oluştu, tekrar dene.' : clean;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111a2e),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '${widget.targetName}\'e Saldır',
            style: const TextStyle(
              color: Color(0xFFfbbf24),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Güç: Sen ${widget.attackerPower} — Hedef ${widget.targetPower}',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ...AttackType.values.map(
            (t) => _TypeTile(
              type: t,
              selected: _selectedType == t,
              onTap: () => setState(() => _selectedType = t),
            ),
          ),
          if (_errorMsg != null) ...[
            const SizedBox(height: 12),
            Text(_errorMsg!, style: const TextStyle(color: Colors.redAccent)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _launch,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFfbbf24),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      'Saldır',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  final AttackType type;
  final bool selected;
  final VoidCallback onTap;

  const _TypeTile({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  String get _label => switch (type) {
    AttackType.quick => 'Hızlı Saldırı',
    AttackType.planned => 'Planlı Saldırı (+%15 güç)',
    AttackType.gang => 'Çete Baskını',
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFfbbf24).withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFFfbbf24) : Colors.white12,
          ),
        ),
        child: Text(
          _label,
          style: TextStyle(
            color: selected ? const Color(0xFFfbbf24) : Colors.white70,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
