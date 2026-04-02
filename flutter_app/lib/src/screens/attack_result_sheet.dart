import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/attack_result.dart';
import '../state/game_state.dart';

class AttackResultSheet extends StatefulWidget {
  final AttackResult result;
  const AttackResultSheet({super.key, required this.result});

  @override
  State<AttackResultSheet> createState() => _AttackResultSheetState();
}

class _AttackResultSheetState extends State<AttackResultSheet>
    with TickerProviderStateMixin {
  late AnimationController _iconCtrl;
  late AnimationController _statsCtrl;
  late Animation<double> _iconScale;
  late Animation<double> _iconOpacity;
  late Animation<double> _statsSlide;
  late Animation<double> _statsOpacity;

  @override
  void initState() {
    super.initState();

    _iconCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _statsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _iconScale = CurvedAnimation(
      parent: _iconCtrl,
      curve: Curves.elasticOut,
    ).drive(Tween(begin: 0.0, end: 1.0));
    _iconOpacity = CurvedAnimation(
      parent: _iconCtrl,
      curve: Curves.easeIn,
    ).drive(Tween(begin: 0.0, end: 1.0));
    _statsSlide = CurvedAnimation(
      parent: _statsCtrl,
      curve: Curves.easeOut,
    ).drive(Tween(begin: 30.0, end: 0.0));
    _statsOpacity = CurvedAnimation(
      parent: _statsCtrl,
      curve: Curves.easeIn,
    ).drive(Tween(begin: 0.0, end: 1.0));

    _iconCtrl.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _statsCtrl.forward();
    });
  }

  @override
  void dispose() {
    _iconCtrl.dispose();
    _statsCtrl.dispose();
    super.dispose();
  }

  Color get _color => switch (widget.result.outcome) {
    AttackOutcome.win => const Color(0xFF34d399),
    AttackOutcome.lose => const Color(0xFFf87171),
    AttackOutcome.draw => const Color(0xFFfbbf24),
  };

  String get _title => switch (widget.result.outcome) {
    AttackOutcome.win => 'Zafer!',
    AttackOutcome.lose => 'Mağlubiyet',
    AttackOutcome.draw => 'Berabere',
  };

  IconData get _icon => switch (widget.result.outcome) {
    AttackOutcome.win => Icons.emoji_events_rounded,
    AttackOutcome.lose => Icons.local_hospital_rounded,
    AttackOutcome.draw => Icons.handshake_rounded,
  };

  String _fmtSigned(int value) => value > 0 ? '+$value' : '$value';

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111a2e),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.88),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _iconCtrl,
                    builder: (context, _) => Opacity(
                      opacity: _iconOpacity.value,
                      child: Transform.scale(
                        scale: _iconScale.value,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _color.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: _color, width: 2),
                          ),
                          child: Icon(_icon, color: _color, size: 40),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _title,
                    style: TextStyle(
                      color: _color,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.result.message,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  AnimatedBuilder(
                    animation: _statsCtrl,
                    builder: (_, child) => Opacity(
                      opacity: _statsOpacity.value,
                      child: Transform.translate(
                        offset: Offset(0, _statsSlide.value),
                        child: child,
                      ),
                    ),
                    child: Column(
                      children: [
                        if (widget.result.stolenCash > 0)
                          _StatRow(
                            icon: Icons.attach_money,
                            label: 'Çalınan nakit',
                            value: '+${widget.result.stolenCash} \$',
                            color: const Color(0xFF34d399),
                          ),
                        if (widget.result.xpGained > 0)
                          _StatRow(
                            icon: Icons.bolt,
                            label: 'Kazanılan XP',
                            value: '+${widget.result.xpGained}',
                            color: const Color(0xFFfbbf24),
                          ),
                        if ((widget.result.weaponTotalPct ?? 0) != 0)
                          _StatRow(
                            icon: Icons.tune_rounded,
                            label: 'Silah Üstünlüğü',
                            value:
                                '%${_fmtSigned(widget.result.weaponTotalPct!)}',
                            color: (widget.result.weaponTotalPct ?? 0) >= 0
                                ? const Color(0xFF34d399)
                                : const Color(0xFFf87171),
                          ),
                        if ((widget.result.weaponPowerPct ?? 0) != 0 ||
                            (widget.result.weaponSpeedPct ?? 0) != 0)
                          _StatRow(
                            icon: Icons.compare_arrows_rounded,
                            label: 'Güç / Hız Etkisi',
                            value:
                                '%${_fmtSigned(widget.result.weaponPowerPct ?? 0)} / %${_fmtSigned(widget.result.weaponSpeedPct ?? 0)}',
                            color: const Color(0xFFa78bfa),
                          ),
                        if ((widget.result.knifePct ?? 0) != 0)
                          _StatRow(
                            icon: Icons.front_hand_rounded,
                            label: 'Yakın Dövüş Etkisi',
                            value: '%${_fmtSigned(widget.result.knifePct!)}',
                            color: (widget.result.knifePct ?? 0) >= 0
                                ? const Color(0xFF34d399)
                                : const Color(0xFFf87171),
                          ),
                        if ((widget.result.armorPct ?? 0) != 0)
                          _StatRow(
                            icon: Icons.shield_rounded,
                            label: 'Zırh Etkisi',
                            value: '%${_fmtSigned(widget.result.armorPct!)}',
                            color: (widget.result.armorPct ?? 0) >= 0
                                ? const Color(0xFF34d399)
                                : const Color(0xFFf87171),
                          ),
                        if ((widget.result.vehiclePct ?? 0) != 0)
                          _StatRow(
                            icon: Icons.directions_car_rounded,
                            label: 'Araç Etkisi',
                            value: '%${_fmtSigned(widget.result.vehiclePct!)}',
                            color: (widget.result.vehiclePct ?? 0) >= 0
                                ? const Color(0xFF34d399)
                                : const Color(0xFFf87171),
                          ),
                        if ((widget.result.loadoutTotalPct ?? 0) != 0)
                          _StatRow(
                            icon: Icons.auto_graph_rounded,
                            label: 'Toplam Ekipman Etkisi',
                            value:
                                '%${_fmtSigned(widget.result.loadoutTotalPct!)}',
                            color: (widget.result.loadoutTotalPct ?? 0) >= 0
                                ? const Color(0xFF34d399)
                                : const Color(0xFFf87171),
                          ),
                        if ((widget.result.attackerWeaponName ?? '')
                                .isNotEmpty &&
                            (widget.result.targetWeaponName ?? '').isNotEmpty)
                          _StatRow(
                            icon: Icons.gavel_rounded,
                            label: 'Eşleşme',
                            value:
                                'Sen: ${widget.result.attackerWeaponName}\nRakip: ${widget.result.targetWeaponName}',
                            multilineValue: true,
                            color: const Color(0xFF60a5fa),
                          ),
                        if ((widget.result.attackerArmorName ?? '')
                                .isNotEmpty &&
                            (widget.result.targetArmorName ?? '').isNotEmpty)
                          _StatRow(
                            icon: Icons.security_rounded,
                            label: 'Zırh vs Zırh',
                            value:
                                'Sen: ${widget.result.attackerArmorName}\nRakip: ${widget.result.targetArmorName}',
                            multilineValue: true,
                            color: const Color(0xFF60a5fa),
                          ),
                        if ((widget.result.attackerVehicleName ?? '')
                                .isNotEmpty &&
                            (widget.result.targetVehicleName ?? '').isNotEmpty)
                          _StatRow(
                            icon: Icons.route_rounded,
                            label: 'Araç vs Araç',
                            value:
                                'Sen: ${widget.result.attackerVehicleName}\nRakip: ${widget.result.targetVehicleName}',
                            multilineValue: true,
                            color: const Color(0xFF60a5fa),
                          ),
                        if (widget.result.outcome == AttackOutcome.lose)
                          _StatRow(
                            icon: Icons.timer,
                            label: 'Hastane süresi',
                            value:
                                '${context.read<GameState>().penaltyDurationMinutes} dakika',
                            color: const Color(0xFFf87171),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Row(
              children: [
                if (widget.result.outcome == AttackOutcome.win) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, 'retry'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _color.withValues(alpha: 0.5)),
                        foregroundColor: _color,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Tekrar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _color,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Kapat',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool multilineValue;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.multilineValue = false,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = const TextStyle(color: Colors.white54, fontSize: 13);
    final valueStyle = TextStyle(
      color: color,
      fontWeight: FontWeight.bold,
      fontSize: multilineValue ? 12 : 14,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: multilineValue
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 18),
                    const SizedBox(width: 10),
                    Text(label, style: labelStyle),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  textAlign: TextAlign.left,
                  softWrap: true,
                  style: valueStyle,
                ),
              ],
            )
          : Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 10),
                Text(label, style: labelStyle),
                const Spacer(),
                Text(value, textAlign: TextAlign.right, style: valueStyle),
              ],
            ),
    );
  }
}
