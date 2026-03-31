import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/online_service.dart';
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
    setState(() => _loading = true);
    try {
      final data = await _svc.fetchGangLeaderboard();
      if (mounted) setState(() { _gangs = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openGangDetail(BuildContext context, GameState state, Map<String, dynamic> gang) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GangDetailSheet(gang: gang, state: state),
    );
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
              state.tt('ÇETE SIRALAMASI', 'GANG RANKINGS'),
              style: const TextStyle(
                color: Color(0xFFFBBF24),
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                onPressed: _fetch,
                icon: const Icon(Icons.refresh, color: Color(0xFFFBBF24)),
              ),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFBBF24)))
              : _gangs.isEmpty
                  ? Center(
                      child: Text(
                        state.tt('Henüz çete sıralaması yok.', 'No gang rankings yet.'),
                        style: const TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                      itemCount: _gangs.length,
                      itemBuilder: (context, i) {
                        final g = _gangs[i];
                        final isMyGang = g['id'] == state.gangId;
                        return GestureDetector(
                          onTap: () => _openGangDetail(context, state, g),
                          child: GlassPanel(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: i < 3
                                        ? const Color(0xFFFBBF24).withOpacity(0.15)
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
                                            g['name']?.toString() ?? 'Çete',
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
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFBBF24).withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(4),
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
                                        '${g['memberCount'] ?? 0}/5 ${state.tt('üye', 'members')}  •  ${state.tt('Saygınlık', 'Respect')}: ${g['respectPoints'] ?? 0}',
                                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
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
                                      state.tt('Güç', 'Power'),
                                      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
                                    ),
                                    const SizedBox(height: 4),
                                    const Icon(Icons.chevron_right, color: Color(0xFF4B5563), size: 18),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        );
      },
    );
  }
}

class _GangDetailSheet extends StatefulWidget {
  final Map<String, dynamic> gang;
  final GameState state;
  const _GangDetailSheet({required this.gang, required this.state});

  @override
  State<_GangDetailSheet> createState() => _GangDetailSheetState();
}

class _GangDetailSheetState extends State<_GangDetailSheet> {
  final _onlineSvc = OnlineService();
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  static const Map<String, List<Map<String, dynamic>>> _seedMembers = {
    'seed_gang_01': [
      {'displayName': 'Kurt_Memo', 'role': 'Lider', 'power': 1235},
      {'displayName': 'Tetikci_Orhan', 'role': 'Üye', 'power': 1180},
      {'displayName': 'Baron_Ali', 'role': 'Üye', 'power': 1125},
      {'displayName': 'Racon_Selim', 'role': 'Üye', 'power': 1070},
      {'displayName': 'Gece_Kargasi', 'role': 'Üye', 'power': 1015},
    ],
    'seed_gang_02': [
      {'displayName': 'Sokak_Vurgun', 'role': 'Lider', 'power': 960},
      {'displayName': 'Golge', 'role': 'Üye', 'power': 905},
      {'displayName': 'Kasirga_Han', 'role': 'Üye', 'power': 850},
      {'displayName': 'Kral_Panzer', 'role': 'Üye', 'power': 795},
      {'displayName': 'Don_Marco', 'role': 'Üye', 'power': 740},
    ],
    'seed_gang_03': [
      {'displayName': 'Mafya_Cem', 'role': 'Lider', 'power': 785},
      {'displayName': 'Demir_Yusuf', 'role': 'Üye', 'power': 730},
      {'displayName': 'Silahsor_Apo', 'role': 'Üye', 'power': 675},
      {'displayName': 'Karanlik_Tolga', 'role': 'Üye', 'power': 620},
      {'displayName': 'Bicakci_Erdem', 'role': 'Üye', 'power': 565},
    ],
    'seed_gang_04': [
      {'displayName': 'Bela_Burak', 'role': 'Lider', 'power': 510},
      {'displayName': 'Baba_Rasim', 'role': 'Üye', 'power': 455},
      {'displayName': 'Serseri_Cenk', 'role': 'Üye', 'power': 400},
      {'displayName': 'Reis_Tuna', 'role': 'Üye', 'power': 345},
      {'displayName': 'Vurguncu_Levent', 'role': 'Üye', 'power': 290},
    ],
  };

  Future<void> _fetchMembers() async {
    final gangId = widget.gang['id']?.toString() ?? '';
    if (gangId.isEmpty) { setState(() => _loading = false); return; }
    // Seed çeteler için Firestore'a gitme
    if (_seedMembers.containsKey(gangId)) {
      if (mounted) setState(() { _members = List.from(_seedMembers[gangId]!); _loading = false; });
      return;
    }
    try {
      final m = await _onlineSvc.fetchGangMembers(gangId);
      if (mounted) setState(() { _members = m; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendJoinRequest() async {
    final state = widget.state;
    final gangId = widget.gang['id']?.toString() ?? '';
    setState(() => _sending = true);
    final ok = await state.joinGang(gangId);
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? state.tt('Katılım isteği gönderildi.', 'Join request sent.')
          : (state.lastAuthError.isNotEmpty ? state.lastAuthError : state.tt('Katılım başarısız.', 'Join failed.'))),
    ));
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final gang = widget.gang;
    final gangId = gang['id']?.toString() ?? '';
    final gangName = gang['name']?.toString() ?? state.tt('Çete', 'Gang');
    final memberCount = (gang['memberCount'] as num?)?.toInt() ?? 0;
    final totalPower = (gang['totalPower'] as num?)?.toInt() ?? 0;
    final respect = (gang['respectPoints'] as num?)?.toInt() ?? 0;
    final inviteOnly = gang['inviteOnly'] == true;
    final acceptRequests = gang['acceptJoinRequests'] != false;
    final isMyGang = gangId == state.gangId;
    final isFull = memberCount >= 5;
    final canRequest = !isMyGang && !inviteOnly && acceptRequests && !isFull && state.gangId.isEmpty;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      decoration: const BoxDecoration(
        color: Color(0xFF0F1B33),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(gangName, style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _InfoChip(label: '$memberCount/5 ${state.tt('üye', 'members')}', color: const Color(0xFF60A5FA)),
                    const SizedBox(width: 8),
                    _InfoChip(label: '${state.tt('Güç', 'Power')}: $totalPower', color: const Color(0xFF34D399)),
                    const SizedBox(width: 8),
                    _InfoChip(label: '${state.tt('Saygınlık', 'Respect')}: $respect', color: const Color(0xFFA78BFA)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  inviteOnly
                      ? state.tt('Sadece davet ile katılım', 'Invite only')
                      : isFull
                          ? state.tt('Çete dolu (max 5)', 'Gang full (max 5)')
                          : state.tt('Katılıma açık', 'Open to join'),
                  style: TextStyle(
                    color: inviteOnly || isFull ? const Color(0xFFFCA5A5) : const Color(0xFF34D399),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF1E2D45)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(state.tt('ÜYELER', 'MEMBERS'), style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          ),
          Flexible(
            child: _loading
                ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: Color(0xFFFBBF24))))
                : _members.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(state.tt('Üye bilgisi yüklenemedi.', 'Could not load members.'), style: const TextStyle(color: Colors.white38)),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _members.length,
                        itemBuilder: (_, i) {
                          final m = _members[i];
                          final name = m['displayName']?.toString() ?? state.tt('Üye', 'Member');
                          final role = m['role']?.toString() ?? 'Üye';
                          final power = (m['power'] as num?)?.toInt() ?? 0;
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: role == 'Lider'
                                  ? const Color(0xFFFBBF24).withOpacity(0.2)
                                  : const Color(0xFF1E2D45),
                              child: Icon(
                                role == 'Lider' ? Icons.star_rounded : Icons.person,
                                color: role == 'Lider' ? const Color(0xFFFBBF24) : Colors.white54,
                                size: 16,
                              ),
                            ),
                            title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                            subtitle: Text(role, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                            trailing: Text('$power ${state.tt('Güç', 'Power')}', style: const TextStyle(color: Color(0xFF34D399), fontSize: 12)),
                          );
                        },
                      ),
          ),
          if (!isMyGang)
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: canRequest && !_sending ? _sendJoinRequest : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: canRequest ? const Color(0xFFFBBF24) : Colors.grey.shade800,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _sending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : Text(
                          inviteOnly
                              ? state.tt('Sadece davet ile katılım', 'Invite only')
                              : isFull
                                  ? state.tt('Çete dolu', 'Gang full')
                                  : state.gangId.isNotEmpty
                                      ? state.tt('Zaten bir çetedesin', 'Already in a gang')
                                      : state.tt('Katılım İsteği Gönder', 'Send Join Request'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
