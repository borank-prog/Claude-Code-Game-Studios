import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/attack_log.dart';
import '../models/attack_result.dart';
import '../services/attack_history_service.dart';
import '../widgets/game_background.dart';
import 'attack_confirm_sheet.dart';

enum HistoryFilter { all, attacks, defenses }

class AttackHistoryScreen extends StatefulWidget {
  final String uid;
  final String playerName;
  final int playerPower;

  const AttackHistoryScreen({
    super.key,
    required this.uid,
    required this.playerName,
    required this.playerPower,
  });

  @override
  State<AttackHistoryScreen> createState() => _AttackHistoryScreenState();
}

class _AttackHistoryScreenState extends State<AttackHistoryScreen> {
  final _svc = AttackHistoryService();
  late Future<List<AttackLog>> _future;
  HistoryFilter _filter = HistoryFilter.all;

  @override
  void initState() {
    super.initState();
    _future = _svc.fetchHistory(widget.uid);
  }

  void _refresh() => setState(() {
        _future = _svc.fetchHistory(widget.uid);
      });

  List<AttackLog> _applyFilter(List<AttackLog> logs) => switch (_filter) {
        HistoryFilter.all => logs,
        HistoryFilter.attacks => logs.where((l) => !l.isDefense).toList(),
        HistoryFilter.defenses => logs.where((l) => l.isDefense).toList(),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0b1220),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0b1220),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF9ca3af),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Saldırı Geçmişi',
          style: TextStyle(
            color: Color(0xFFfbbf24),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF9ca3af),
              size: 22,
            ),
            onPressed: _refresh,
          ),
        ],
      ),
      body: GameBackground(
        child: FutureBuilder<List<AttackLog>>(
          future: _future,
          builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFfbbf24)),
            );
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Color(0xFFf87171),
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Yüklenemedi',
                    style: TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _refresh,
                    child: const Text('Tekrar dene'),
                  ),
                ],
              ),
            );
          }

          final all = snap.data ?? [];
          final filtered = _applyFilter(all);

          return Column(
            children: [
              _StatsBar(logs: all),
              _FilterTabs(
                current: _filter,
                onChanged: (f) => setState(() => _filter = f),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? _EmptyState(filter: _filter)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _AttackEntry(
                          log: filtered[i],
                          currentUid: widget.uid,
                          playerPower: widget.playerPower,
                          playerName: widget.playerName,
                        ),
                      ),
              ),
            ],
          );
          },
        ),
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  final List<AttackLog> logs;
  const _StatsBar({required this.logs});

  @override
  Widget build(BuildContext context) {
    final wins = logs.where((l) => l.outcome == AttackOutcome.win).length;
    final losses = logs.where((l) => l.outcome == AttackOutcome.lose).length;
    final rate = logs.isEmpty ? 0 : (wins / logs.length * 100).round();
    final totalEarned =
        logs.where((l) => l.stolenCash > 0).fold(0, (sum, l) => sum + l.stolenCash);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          _StatCard(
            value: '$wins',
            label: 'Galibiyet',
            color: const Color(0xFF34d399),
          ),
          const SizedBox(width: 8),
          _StatCard(
            value: '$losses',
            label: 'Mağlubiyet',
            color: const Color(0xFFf87171),
          ),
          const SizedBox(width: 8),
          _StatCard(
            value: '%$rate',
            label: 'Başarı',
            color: const Color(0xFFa78bfa),
          ),
          const SizedBox(width: 8),
          _StatCard(
            value: _formatCash(totalEarned),
            label: 'Kazanılan',
            color: const Color(0xFFfbbf24),
          ),
        ],
      ),
    );
  }

  String _formatCash(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return '$v';
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTabs extends StatelessWidget {
  final HistoryFilter current;
  final ValueChanged<HistoryFilter> onChanged;

  const _FilterTabs({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          _Tab(
            label: 'Tümü',
            value: HistoryFilter.all,
            current: current,
            onTap: onChanged,
          ),
          const SizedBox(width: 6),
          _Tab(
            label: 'Saldırılar',
            value: HistoryFilter.attacks,
            current: current,
            onTap: onChanged,
          ),
          const SizedBox(width: 6),
          _Tab(
            label: 'Savunmalar',
            value: HistoryFilter.defenses,
            current: current,
            onTap: onChanged,
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final HistoryFilter value;
  final HistoryFilter current;
  final ValueChanged<HistoryFilter> onTap;

  const _Tab({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = value == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFFfbbf24).withOpacity(0.12)
                : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? const Color(0xFFfbbf24).withOpacity(0.4)
                  : Colors.white12,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? const Color(0xFFfbbf24) : Colors.white38,
              fontSize: 12,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _AttackEntry extends StatelessWidget {
  final AttackLog log;
  final String currentUid;
  final int playerPower;
  final String playerName;

  const _AttackEntry({
    required this.log,
    required this.currentUid,
    required this.playerPower,
    required this.playerName,
  });

  Color get _outcomeColor => switch (log.outcome) {
        AttackOutcome.win => const Color(0xFF34d399),
        AttackOutcome.lose => const Color(0xFFf87171),
        AttackOutcome.draw => const Color(0xFFfbbf24),
      };

  IconData get _outcomeIcon => switch (log.outcome) {
        AttackOutcome.win => Icons.check_rounded,
        AttackOutcome.lose => Icons.close_rounded,
        AttackOutcome.draw => Icons.remove_rounded,
      };

  String get _cashLabel {
    if (log.outcome == AttackOutcome.draw) return 'Berabere';
    if (log.outcome == AttackOutcome.lose && log.stolenCash == 0) {
      return log.isDefense ? 'Korundu' : 'Hastane';
    }
    final sign = log.stolenCash > 0 ? '+' : '';
    return '$sign${_fmt(log.stolenCash)} \$';
  }

  String _fmt(int v) {
    if (v.abs() >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return '$v';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    if (diff.inDays == 1) return 'Dün';
    return DateFormat('d MMM', 'tr').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111a2e),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _outcomeColor.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _outcomeColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_outcomeIcon, color: _outcomeColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.opponentName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${log.typeLabel} · ${log.directionLabel}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                if (log.canRevenge)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: GestureDetector(
                      onTap: () => _openRevenge(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFfbbf24).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFFfbbf24).withOpacity(0.35),
                          ),
                        ),
                        child: const Text(
                          'İntikam al',
                          style: TextStyle(
                            color: Color(0xFFfbbf24),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _cashLabel,
                style: TextStyle(
                  color: _outcomeColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _timeAgo(log.timestamp),
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
              if (log.xpGained > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '+${log.xpGained} XP',
                    style: const TextStyle(
                      color: Color(0xFFa78bfa),
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _openRevenge(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AttackConfirmSheet(
        attackerId: currentUid,
        targetId: log.opponentId,
        targetName: log.opponentName,
        attackerPower: playerPower,
        targetPower: 0,
        attackerName: playerName,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final HistoryFilter filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final msg = switch (filter) {
      HistoryFilter.attacks => 'Henüz saldırı yapmadın',
      HistoryFilter.defenses => 'Henüz saldırıya uğramadın',
      HistoryFilter.all => 'Geçmiş boş',
    };

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.history_rounded,
            color: Colors.white12,
            size: 52,
          ),
          const SizedBox(height: 12),
          Text(
            msg,
            style: const TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
