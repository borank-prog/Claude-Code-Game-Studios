import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/leaderboard_entry.dart';
import '../state/game_state.dart';
import '../services/leaderboard_service.dart';
import '../widgets/game_background.dart';
import 'attack_confirm_sheet.dart';

class LeaderboardScreen extends StatefulWidget {
  final String currentUid;

  const LeaderboardScreen({super.key, required this.currentUid});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  final _svc = LeaderboardService();
  late TabController _tabs;
  final _categories = const <LeaderboardCategory>[
    LeaderboardCategory.score,
    LeaderboardCategory.power,
    LeaderboardCategory.wins,
    LeaderboardCategory.cash,
  ];
  final _cache = <LeaderboardCategory, List<LeaderboardEntry>>{};
  final _myRanks = <LeaderboardCategory, int>{};
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _categories.length, vsync: this);
    _tabs.addListener(() => setState(() {}));
    _loadAll();
  }

  Set<String> _computeAttackWindowIds(GameState state) {
    if (state.userId.isEmpty) return const <String>{};
    final scoreEntries =
        _cache[LeaderboardCategory.score] ?? const <LeaderboardEntry>[];
    if (scoreEntries.isEmpty) return const <String>{};

    final sorted = List<LeaderboardEntry>.from(scoreEntries)
      ..sort((a, b) => b.score.compareTo(a.score));
    final myIndex = sorted.indexWhere((e) => e.uid == state.userId);
    if (myIndex < 0) return const <String>{};

    final start = (myIndex - 5).clamp(0, sorted.length).toInt();
    final end = (myIndex + 6).clamp(0, sorted.length).toInt();
    final allowed = <String>{};
    for (var i = start; i < end; i++) {
      if (i == myIndex) continue;
      final uid = sorted[i].uid.trim();
      if (uid.isNotEmpty) allowed.add(uid);
    }
    return allowed;
  }

  void _showProfile(BuildContext context, LeaderboardEntry entry) {
    final state = context.read<GameState>();
    final attackWindowIds = _computeAttackWindowIds(state);
    final canAttack =
        state.userId.isNotEmpty &&
        entry.uid.isNotEmpty &&
        entry.uid != state.userId &&
        !entry.uid.startsWith('bot_') &&
        attackWindowIds.contains(entry.uid);
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlayerProfileSheet(
        entry: entry,
        canAttack: canAttack,
        attackHint: state.tt(
          'Sadece üstündeki 5 ve altındaki 5 sıraya saldırabilirsin.',
          'You can attack only the top 5 above and bottom 5 below you.',
        ),
      ),
    ).then((action) {
      if (action != 'attack' || !canAttack || !context.mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AttackConfirmSheet(
          attackerId: state.userId,
          attackerName: state.displayPlayerName,
          attackerPower: state.totalPower,
          targetId: entry.uid,
          targetName: entry.name,
          targetPower: entry.power,
        ),
      );
    });
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    for (final cat in _categories) {
      final data = await _svc.fetchTop(category: cat, limit: 300);
      final rank = await _svc.fetchMyRank(widget.currentUid, cat);
      _cache[cat] = data;
      _myRanks[cat] = rank;
    }
    if (mounted) setState(() => _loading = false);
  }

  List<LeaderboardEntry> _applySearch(List<LeaderboardEntry> entries) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return entries;
    return entries
        .where((e) {
          return e.name.toLowerCase().contains(q) ||
              e.uid.toLowerCase().contains(q) ||
              (e.gangName ?? '').toLowerCase().contains(q);
        })
        .toList(growable: false);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cat = _categories[_tabs.index];
    final entries = _applySearch(_cache[cat] ?? []);
    final myRank = _myRanks[cat] ?? 0;
    final top3 = entries.take(3).toList();
    final rest = entries.skip(3).toList();

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
          'Liderlik Tablosu',
          style: TextStyle(
            color: Color(0xFFfbbf24),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF9ca3af)),
            onPressed: _loadAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: const Color(0xFFfbbf24),
          indicatorWeight: 2,
          labelColor: const Color(0xFFfbbf24),
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
          tabs: const [
            Tab(text: 'Skor'),
            Tab(text: 'Güç'),
            Tab(text: 'Galibiyet'),
            Tab(text: 'Nakit'),
          ],
        ),
      ),
      body: GameBackground(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFfbbf24)),
              )
            : RefreshIndicator(
                color: const Color(0xFFfbbf24),
                backgroundColor: const Color(0xFF111a2e),
                onRefresh: _loadAll,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Oyuncu / UID ara...',
                          hintStyle: const TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Colors.white54,
                          ),
                          suffixIcon: _searchQuery.trim().isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white54,
                                  ),
                                ),
                          filled: true,
                          fillColor: const Color(0xFF111a2e),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFfbbf24),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (top3.length == 3)
                      _Podium(
                        top3: top3,
                        category: cat,
                        currentUid: widget.currentUid,
                        onTap: (e) {
                          if (e.uid != widget.currentUid) {
                            _showProfile(context, e);
                          }
                        },
                      ),
                    if (myRank > 0) _MyRankBanner(rank: myRank, category: cat),
                    Expanded(
                      child: entries.isEmpty
                          ? const Center(
                              child: Text(
                                'Aradığın oyuncu bulunamadı',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: rest.length,
                              itemBuilder: (_, i) => _LeaderRow(
                                entry: rest[i],
                                isMe: rest[i].uid == widget.currentUid,
                                category: cat,
                                onTap: rest[i].uid == widget.currentUid
                                    ? null
                                    : () => _showProfile(context, rest[i]),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<LeaderboardEntry> top3;
  final LeaderboardCategory category;
  final String currentUid;
  final void Function(LeaderboardEntry) onTap;

  const _Podium({
    required this.top3,
    required this.category,
    required this.currentUid,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final order = [top3[1], top3[0], top3[2]];
    final heights = [80.0, 110.0, 60.0];
    final sizes = [52.0, 64.0, 44.0];
    final colors = [
      const Color(0xFF9ca3af),
      const Color(0xFFfbbf24),
      const Color(0xFFcd7c2f),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (i) {
          final e = order[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(e),
              child: Column(
                children: [
                  if (i == 1)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Icon(
                        Icons.emoji_events_rounded,
                        color: Color(0xFFfbbf24),
                        size: 24,
                      ),
                    ),
                  Container(
                    width: sizes[i],
                    height: sizes[i],
                    decoration: BoxDecoration(
                      color: colors[i].withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: colors[i], width: 2),
                    ),
                    child: Center(
                      child: Text(
                        e.name.isNotEmpty ? e.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: colors[i],
                          fontSize: sizes[i] * 0.35,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    e.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _val(e, category),
                    style: TextStyle(color: colors[i], fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: heights[i],
                    decoration: BoxDecoration(
                      color: colors[i].withValues(alpha: 0.12),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                      border: Border.all(
                        color: colors[i].withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '#${e.rank}',
                        style: TextStyle(
                          color: colors[i],
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  String _val(LeaderboardEntry e, LeaderboardCategory cat) {
    return switch (cat) {
      LeaderboardCategory.score => '${e.score} skor',
      LeaderboardCategory.power => '${e.power} güç',
      LeaderboardCategory.cash => '\$${_fmt(e.cash)}',
      LeaderboardCategory.wins => '${e.wins} galibiyet',
    };
  }

  String _fmt(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return '$v';
  }
}

class _MyRankBanner extends StatelessWidget {
  final int rank;
  final LeaderboardCategory category;

  const _MyRankBanner({required this.rank, required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFa78bfa).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFa78bfa).withValues(alpha: 0.35),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.my_location_rounded,
            color: Color(0xFFa78bfa),
            size: 16,
          ),
          const SizedBox(width: 8),
          const Text(
            'Senin sıran:',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const Spacer(),
          Text(
            '#$rank',
            style: const TextStyle(
              color: Color(0xFFa78bfa),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isMe;
  final LeaderboardCategory category;
  final VoidCallback? onTap;

  const _LeaderRow({
    required this.entry,
    required this.isMe,
    required this.category,
    this.onTap,
  });

  String _val() {
    return switch (category) {
      LeaderboardCategory.score => '${entry.score} skor',
      LeaderboardCategory.power => '${entry.power} güç',
      LeaderboardCategory.cash => '\$${_fmt(entry.cash)}',
      LeaderboardCategory.wins => '${entry.wins} galibiyet',
    };
  }

  String _fmt(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? const Color(0xFFa78bfa).withValues(alpha: 0.08)
              : const Color(0xFF111a2e),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isMe
                ? const Color(0xFFa78bfa).withValues(alpha: 0.35)
                : Colors.white12,
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '#${entry.rank}',
                style: TextStyle(
                  color: entry.rank <= 10
                      ? const Color(0xFFfbbf24)
                      : Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isMe
                    ? const Color(0xFFa78bfa).withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  entry.name.isNotEmpty ? entry.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: isMe
                        ? const Color(0xFFa78bfa)
                        : const Color(0xFFfbbf24),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          color: entry.online
                              ? const Color(0xFF34D399)
                              : Colors.white24,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        entry.name,
                        style: TextStyle(
                          color: isMe ? const Color(0xFFa78bfa) : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isMe)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFa78bfa).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Sen',
                            style: TextStyle(
                              color: Color(0xFFa78bfa),
                              fontSize: 9,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (entry.gangName != null)
                    Text(
                      entry.gangName!,
                      style: const TextStyle(
                        color: Colors.white30,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              _val(),
              style: const TextStyle(
                color: Color(0xFFfbbf24),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!isMe)
              const Icon(Icons.chevron_right, color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }
}

// ── Oyuncu Profil Modal ──────────────────────────────────────────────────────

class _PlayerProfileSheet extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool canAttack;
  final String attackHint;

  const _PlayerProfileSheet({
    required this.entry,
    required this.canAttack,
    required this.attackHint,
  });

  String _fmt(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F1B33),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          // Avatar dairesi + online nokta
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFfbbf24).withValues(alpha: 0.15),
                  border: Border.all(color: const Color(0xFFfbbf24), width: 2),
                ),
                child: Center(
                  child: Text(
                    entry.name.isNotEmpty ? entry.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Color(0xFFfbbf24),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: entry.online
                      ? const Color(0xFF34D399)
                      : Colors.white38,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0F1B33), width: 2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            entry.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            entry.online ? 'Çevrimiçi' : 'Çevrimdışı',
            style: TextStyle(
              color: entry.online ? const Color(0xFF34D399) : Colors.white38,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (entry.gangName != null && entry.gangName!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              entry.gangName!,
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 13),
            ),
          ],
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: entry.uid));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('UID kopyalandı'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.uid,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.copy_rounded, size: 13, color: Color(0xFF94A3B8)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // İstatistikler
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatBox(
                label: 'Sıra',
                value: '#${entry.rank}',
                color: const Color(0xFFfbbf24),
              ),
              _StatBox(
                label: 'Güç',
                value: '${entry.power}',
                color: const Color(0xFFa78bfa),
              ),
              _StatBox(
                label: 'Galibiyet',
                value: '${entry.wins}',
                color: const Color(0xFF34D399),
              ),
              _StatBox(
                label: 'Nakit',
                value: '\$${_fmt(entry.cash)}',
                color: const Color(0xFF60A5FA),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    foregroundColor: Colors.white70,
                  ),
                  child: const Text('Kapat'),
                ),
              ),
              if (canAttack) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, 'attack'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFfbbf24),
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.gps_fixed_rounded, size: 16),
                    label: const Text('Saldır'),
                  ),
                ),
              ],
            ],
          ),
          if (!canAttack) ...[
            const SizedBox(height: 10),
            Text(
              attackHint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
