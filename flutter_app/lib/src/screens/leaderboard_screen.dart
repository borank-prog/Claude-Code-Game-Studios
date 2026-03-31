import 'package:flutter/material.dart';

import '../models/leaderboard_entry.dart';
import '../services/leaderboard_service.dart';
import '../widgets/game_background.dart';

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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _categories.length, vsync: this);
    _tabs.addListener(() => setState(() {}));
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    for (final cat in _categories) {
      final data = await _svc.fetchTop(category: cat);
      final rank = await _svc.fetchMyRank(widget.currentUid, cat);
      _cache[cat] = data;
      _myRanks[cat] = rank;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cat = _categories[_tabs.index];
    final entries = _cache[cat] ?? [];
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
            : Column(
                children: [
                  if (top3.length == 3) _Podium(top3: top3, category: cat),
                  if (myRank > 3) _MyRankBanner(rank: myRank, category: cat),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: rest.length,
                      itemBuilder: (_, i) => _LeaderRow(
                        entry: rest[i],
                        isMe: rest[i].uid == widget.currentUid,
                        category: cat,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<LeaderboardEntry> top3;
  final LeaderboardCategory category;

  const _Podium({required this.top3, required this.category});

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
                    color: colors[i].withOpacity(0.15),
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
                    color: colors[i].withOpacity(0.12),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                    border: Border.all(
                      color: colors[i].withOpacity(0.3),
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
        color: const Color(0xFFa78bfa).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFa78bfa).withOpacity(0.35),
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

  const _LeaderRow({
    required this.entry,
    required this.isMe,
    required this.category,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe
            ? const Color(0xFFa78bfa).withOpacity(0.08)
            : const Color(0xFF111a2e),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMe
              ? const Color(0xFFa78bfa).withOpacity(0.35)
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
                  ? const Color(0xFFa78bfa).withOpacity(0.15)
                  : Colors.white.withOpacity(0.06),
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
                          color: const Color(0xFFa78bfa).withOpacity(0.2),
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
                    style: const TextStyle(color: Colors.white30, fontSize: 10),
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
        ],
      ),
    );
  }
}
