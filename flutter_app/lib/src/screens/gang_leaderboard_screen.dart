import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/trade_service.dart';
import '../state/game_state.dart';
import '../widgets/glass_panel.dart';

class GangLeaderboardScreen extends StatefulWidget {
  const GangLeaderboardScreen({super.key});

  @override
  State<GangLeaderboardScreen> createState() => _GangLeaderboardScreenState();
}

class _GangLeaderboardScreenState extends State<GangLeaderboardScreen> {
  final _svc = TradeService();
  List<Map<String, dynamic>> _gangs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final data = await _svc.fetchGangLeaderboard();
      if (mounted) setState(() { _gangs = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, state, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF081428),
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(
              state.tt('CETE SIRALAMASI', 'GANG RANKINGS'),
              style: const TextStyle(
                color: Color(0xFFFBBF24),
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                onPressed: () {
                  setState(() => _loading = true);
                  _fetch();
                },
                icon: const Icon(Icons.refresh, color: Color(0xFFFBBF24)),
              ),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _gangs.isEmpty
                  ? Center(
                      child: Text(
                        state.tt(
                          'Henuz cete siralamasi yok.',
                          'No gang rankings yet.',
                        ),
                        style: const TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                      itemCount: _gangs.length,
                      itemBuilder: (context, i) {
                        final g = _gangs[i];
                        final isMyGang = g['id'] == state.gangId;
                        return GlassPanel(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: i < 3
                                      ? const Color(0xFFFBBF24)
                                          .withOpacity(0.15)
                                      : const Color(0xFF0A1630),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: i < 3
                                        ? const Color(0xFFFBBF24)
                                        : const Color(0xFF1E2D45),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '#${i + 1}',
                                    style: TextStyle(
                                      color: i < 3
                                          ? const Color(0xFFFBBF24)
                                          : Colors.white54,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          g['name']?.toString() ?? 'Cete',
                                          style: TextStyle(
                                            color: isMyGang
                                                ? const Color(0xFFFBBF24)
                                                : Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        if (isMyGang) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFBBF24)
                                                  .withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              state.tt('Senin', 'Yours'),
                                              style: const TextStyle(
                                                color: Color(0xFFFBBF24),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${g['memberCount'] ?? 0} ${state.tt('uye', 'members')}  •  ${state.tt('Sayginlik', 'Respect')}: ${g['respectPoints'] ?? 0}',
                                      style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${g['totalPower'] ?? 0}',
                                    style: const TextStyle(
                                      color: Color(0xFF34D399),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    state.tt('Guc', 'Power'),
                                    style: const TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        );
      },
    );
  }
}
