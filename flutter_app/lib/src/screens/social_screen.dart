import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/game_state.dart';
import '../widgets/glass_panel.dart';
import 'attack_confirm_sheet.dart';
import 'trade_screen.dart';
import 'gang_leaderboard_screen.dart';
import 'inbox_screen.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final friendCtrl = TextEditingController();
  final gangNameCtrl = TextEditingController();
  final gangIdCtrl = TextEditingController();
  final gangInviteUidCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<GameState>().refreshSocialData();
    });
  }

  @override
  void dispose() {
    friendCtrl.dispose();
    gangNameCtrl.dispose();
    gangIdCtrl.dispose();
    gangInviteUidCtrl.dispose();
    super.dispose();
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _copyPlayerId(GameState state) async {
    final id = state.userId.trim();
    if (id.isEmpty) {
      _snack(state.tt('Oyuncu ID bulunamadı.', 'Player ID not found.'));
      return;
    }
    await Clipboard.setData(ClipboardData(text: id));
    if (!mounted) return;
    _snack(state.tt('Oyuncu ID kopyalandı.', 'Player ID copied.'));
  }

  Future<void> _showLeaderboardProfile(
    GameState state,
    Map<String, dynamic> row,
  ) async {
    final uid = (row['uid'] ?? '').toString().trim();
    if (uid.isEmpty || uid == state.userId) return;
    final name = (row['displayName'] ?? row['name'] ?? 'Oyuncu')
        .toString()
        .trim();
    final power = (row['power'] as num?)?.toInt() ?? 0;
    final wins = (row['wins'] as num?)?.toInt() ?? 0;
    final cash = (row['cash'] as num?)?.toInt() ?? 0;
    final gangName = (row['gangName'] ?? '').toString().trim();
    final online = row['online'] == true;
    final canAttack = state.userId.isNotEmpty && uid.isNotEmpty;

    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SocialLeaderboardProfileSheet(
        name: name.isEmpty ? 'Oyuncu' : name,
        uid: uid,
        power: power,
        wins: wins,
        cash: cash,
        gangName: gangName,
        online: online,
        canAttack: canAttack,
      ),
    );

    if (action == 'friend') {
      final ok = await state.sendFriendRequest(uid);
      if (!mounted) return;
      _snack(
        ok
            ? state.tt(
                '$name için arkadaşlık isteği gönderildi.',
                'Friend request sent to $name.',
              )
            : state.tt(
                'İstek gönderilemedi.',
                'Could not send friend request.',
              ),
      );
      return;
    }

    if (action == 'attack' && canAttack && mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AttackConfirmSheet(
          attackerId: state.userId,
          attackerName: state.displayPlayerName,
          attackerPower: state.totalPower,
          targetId: uid,
          targetName: name.isEmpty ? 'Oyuncu' : name,
          targetPower: power,
        ),
      );
    }
  }

  bool _canAttackRow(GameState state, Map<String, dynamic> row) {
    final uid = (row['uid'] ?? '').toString().trim();
    if (state.userId.isEmpty || uid.isEmpty) return false;
    if (uid == state.userId) return false;
    return true;
  }

  void _openAttackSheetForRow(GameState state, Map<String, dynamic> row) {
    final uid = (row['uid'] ?? '').toString().trim();
    if (uid.isEmpty) return;
    final name = (row['displayName'] ?? row['name'] ?? 'Oyuncu')
        .toString()
        .trim();
    final power = (row['power'] as num?)?.toInt() ?? 0;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AttackConfirmSheet(
        attackerId: state.userId,
        attackerName: state.displayPlayerName,
        attackerPower: state.totalPower,
        targetId: uid,
        targetName: name.isEmpty ? 'Oyuncu' : name,
        targetPower: power,
      ),
    );
  }

  int _metric(GameState state, String key) =>
      state.balanceMetricsSnapshot[key] ?? 0;

  String _rate(int success, int attempts) {
    if (attempts <= 0) return '0%';
    final pct = ((success * 100) / attempts).toStringAsFixed(1);
    return '$pct%';
  }

  int _leaderboardScore(Map<String, dynamic> row) {
    final power = (row['power'] as num?)?.toInt() ?? 0;
    final cash = (row['cash'] as num?)?.toInt() ?? 0;
    final wins = (row['wins'] as num?)?.toInt() ?? 0;
    final gangWins = (row['gangWins'] as num?)?.toInt() ?? 0;
    return (power * 12) + (wins * 900) + (gangWins * 1200) + (cash ~/ 2000);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, state, _) {
        final rows = state.leaderboardRows.isNotEmpty
            ? state.leaderboardRows
            : [
                {'displayName': 'El_Patron [VIP]', 'power': 154000},
                {'displayName': 'Pablo_Esc [VIP]', 'power': 128500},
                {
                  'displayName': state.displayPlayerName,
                  'power': state.totalPower,
                },
              ];
        final rankedRows = List<Map<String, dynamic>>.from(
          rows,
        )..sort((a, b) => _leaderboardScore(b).compareTo(_leaderboardScore(a)));

        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
          children: [
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.tt('DENGE TELEMETRİSİ', 'BALANCE TELEMETRY'),
                    style: const TextStyle(
                      color: Color(0xFFFBBF24),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    state.tt(
                      'Görev: ${_metric(state, 'mission_success_total')}/${_metric(state, 'mission_attempts_total')} başarı (${_rate(_metric(state, 'mission_success_total'), _metric(state, 'mission_attempts_total'))})',
                      'Missions: ${_metric(state, 'mission_success_total')}/${_metric(state, 'mission_attempts_total')} success (${_rate(_metric(state, 'mission_success_total'), _metric(state, 'mission_attempts_total'))})',
                    ),
                    style: const TextStyle(color: Color(0xFFD1D5DB)),
                  ),
                  Text(
                    state.tt(
                      'Kolay/Orta/Zor: ${_rate(_metric(state, 'mission_success_easy'), _metric(state, 'mission_attempts_easy'))} • ${_rate(_metric(state, 'mission_success_medium'), _metric(state, 'mission_attempts_medium'))} • ${_rate(_metric(state, 'mission_success_hard'), _metric(state, 'mission_attempts_hard'))}',
                      'Easy/Medium/Hard: ${_rate(_metric(state, 'mission_success_easy'), _metric(state, 'mission_attempts_easy'))} • ${_rate(_metric(state, 'mission_success_medium'), _metric(state, 'mission_attempts_medium'))} • ${_rate(_metric(state, 'mission_success_hard'), _metric(state, 'mission_attempts_hard'))}',
                    ),
                    style: const TextStyle(color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.tt(
                      'Hapis: ${_metric(state, 'jail_entries_total')}  |  Hastane: ${_metric(state, 'hospital_entries_total')}',
                      'Jail: ${_metric(state, 'jail_entries_total')}  |  Hospital: ${_metric(state, 'hospital_entries_total')}',
                    ),
                    style: const TextStyle(color: Color(0xFFD1D5DB)),
                  ),
                  Text(
                    state.tt(
                      'Altın Skip (Hapis/Hastane): ${_metric(state, 'jail_skip_gold_spent_total')} / ${_metric(state, 'hospital_skip_gold_spent_total')}',
                      'Gold Skip (Jail/Hospital): ${_metric(state, 'jail_skip_gold_spent_total')} / ${_metric(state, 'hospital_skip_gold_spent_total')}',
                    ),
                    style: const TextStyle(color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Quick action buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TradeScreen()),
                      );
                    },
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: Text(state.tt('Takas', 'Trade')),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const GangLeaderboardScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.leaderboard, size: 18),
                    label: Text(state.tt('Cete Sira', 'Gang Rank')),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: state.userId.isEmpty
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => InboxScreen(uid: state.userId),
                        ),
                      );
                    },
              icon: const Icon(Icons.mail_outline_rounded, size: 18),
              label: Text(state.tt('Mesaj Kutusu', 'Inbox')),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
            const SizedBox(height: 8),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.tt('ARKADAŞLAR', 'FRIENDS'),
                    style: TextStyle(
                      color: Color(0xFFFBBF24),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _copyPlayerId(state),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Oyuncu ID: ${state.userId.isEmpty ? '-' : state.userId}',
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.copy_rounded,
                            color: Color(0xFFFBBF24),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            state.tt('Kopyala', 'Copy'),
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
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: friendCtrl,
                          decoration: InputDecoration(
                            labelText: state.tt(
                              'Oyuncu UID (arkadaş ekle)',
                              'Player UID (add friend)',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          final ok = await state.sendFriendRequest(
                            friendCtrl.text,
                          );
                          _snack(
                            ok
                                ? state.tt(
                                    'Arkadaş isteği gönderildi.',
                                    'Friend request sent.',
                                  )
                                : state.tt(
                                    'İstek gönderilemedi.',
                                    'Request failed.',
                                  ),
                          );
                          if (ok) friendCtrl.clear();
                        },
                        child: Text(state.tt('Ekle', 'Add')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.tt('Gelen İstekler', 'Incoming Requests'),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  ...state.incomingRequests.map((r) {
                    final rid = r['id']?.toString() ?? '';
                    final from =
                        r['fromName']?.toString() ??
                        r['fromId']?.toString() ??
                        '-';
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
                            onPressed: () => state.acceptFriendRequest(rid),
                            child: Text(state.tt('Kabul', 'Accept')),
                          ),
                          TextButton(
                            onPressed: () => state.rejectFriendRequest(rid),
                            child: Text(state.tt('Red', 'Reject')),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  Text(
                    state.tt('Arkadaş Listesi', 'Friend List'),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  ...state.friends.map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '- ${f['displayName'] ?? f['uid']}',
                        style: const TextStyle(color: Color(0xFF34D399)),
                      ),
                    ),
                  ),
                  if (state.friends.isEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        state.tt(
                          'Henüz arkadaşın yok.',
                          'You have no friends yet.',
                        ),
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.tt('KARTEL YÖNETİMİ', 'CARTEL MANAGEMENT'),
                    style: TextStyle(
                      color: Color(0xFFFBBF24),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (state.hasGang)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: const Color(0x2214213B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x557F8EA8)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.currentGang?['name']?.toString() ??
                                state.tt('Çete', 'Gang'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${state.tt('Rütbe', 'Rank')}: ${state.gangRank}   •   ${state.tt('Toplam Güç', 'Total Power')}: ${state.totalGangPower}',
                            style: const TextStyle(color: Color(0xFFFBBF24)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${state.tt('Kasa', 'Vault')}: \$${state.gangVault}   •   ${state.tt('Saygınlık', 'Respect')}: ${state.gangRespectPoints}',
                            style: const TextStyle(color: Color(0xFF34D399)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${state.tt('Aktif Üye', 'Online Members')}: ${state.onlineGangMembers}/${state.gangMembers.length}',
                            style: const TextStyle(color: Color(0xFF94A3B8)),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () async {
                                    final ok = await state.donateToGang(
                                      amount: 1000,
                                    );
                                    _snack(
                                      ok
                                          ? state.tt(
                                              '\$1000 bağış yapıldı.',
                                              '\$1000 donated.',
                                            )
                                          : state.tt(
                                              'Bağış başarısız.',
                                              'Donation failed.',
                                            ),
                                    );
                                  },
                                  icon: const Icon(Icons.attach_money),
                                  label: Text(
                                    state.tt(
                                      '\$1000 Bağış Yap',
                                      'Donate \$1000',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  if (state.gangId.isEmpty) ...[
                    if (state.incomingGangInvites.isNotEmpty) ...[
                      Text(
                        state.tt(
                          'GELEN ÇETE DAVETLERİ',
                          'INCOMING GANG INVITES',
                        ),
                        style: const TextStyle(
                          color: Color(0xFFFBBF24),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...state.incomingGangInvites.map((invite) {
                        final inviteId = (invite['id']?.toString() ?? '')
                            .trim();
                        final gangName =
                            (invite['gangName']?.toString() ?? '')
                                .trim()
                                .isEmpty
                            ? state.tt('İsimsiz Çete', 'Unnamed Gang')
                            : invite['gangName'].toString().trim();
                        final leaderName =
                            (invite['leaderName']?.toString() ?? '')
                                .trim()
                                .isEmpty
                            ? state.tt('Lider', 'Leader')
                            : invite['leaderName'].toString().trim();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                gangName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${state.tt('Davet eden', 'Invited by')}: $leaderName',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: inviteId.isEmpty
                                          ? null
                                          : () => state.acceptGangInvite(
                                              inviteId,
                                            ),
                                      child: Text(
                                        state.tt('Kabul Et', 'Accept'),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: inviteId.isEmpty
                                          ? null
                                          : () => state.rejectGangInvite(
                                              inviteId,
                                            ),
                                      child: Text(state.tt('Reddet', 'Reject')),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                    ],
                    TextField(
                      controller: gangNameCtrl,
                      decoration: InputDecoration(
                        labelText: state.tt('Yeni çete adı', 'New gang name'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    FilledButton(
                      onPressed: () async {
                        final ok = await state.createGang(gangNameCtrl.text);
                        final failText = state.lastAuthError.trim().isNotEmpty
                            ? state.lastAuthError
                            : state.tt(
                                'Çete kurulamadı.',
                                'Gang could not be created.',
                              );
                        _snack(
                          ok
                              ? state.tt('Çete kuruldu.', 'Gang created.')
                              : failText,
                        );
                        if (ok) gangNameCtrl.clear();
                      },
                      child: Text(state.tt('Çete Kur', 'Create Gang')),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: gangIdCtrl,
                            decoration: InputDecoration(
                              labelText: state.tt(
                                'Çete ID ile katıl',
                                'Join with Gang ID',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () async {
                            final ok = await state.joinGang(gangIdCtrl.text);
                            final failText =
                                state.lastAuthError.trim().isNotEmpty
                                ? state.lastAuthError
                                : state.tt(
                                    'Katılım başarısız.',
                                    'Join failed.',
                                  );
                            _snack(
                              ok
                                  ? state.tt(
                                      'Katılım isteği lidere gönderildi.',
                                      'Join request sent to leader.',
                                    )
                                  : failText,
                            );
                            if (ok) gangIdCtrl.clear();
                          },
                          child: Text(state.tt('Katıl', 'Join')),
                        ),
                      ],
                    ),
                  ] else ...[
                    Text(
                      '${state.currentGang?['name'] ?? state.tt('Çete', 'Gang')} (${state.gangId})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${state.tt('Rütbe', 'Rank')}: ${state.gangRank}  •  ${state.tt('Saygınlık', 'Respect')}: ${state.gangRespectPoints}',
                      style: const TextStyle(color: Color(0xFF34D399)),
                    ),
                    if (state.isGangLeader) ...[
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          state.tt(
                            'Sadece davet ile katılım',
                            'Invite-only membership',
                          ),
                        ),
                        subtitle: Text(
                          state.tt(
                            'Açıkken yeni üyeler sadece lider davetiyle katılır.',
                            'When enabled, new members can join only via leader invite.',
                          ),
                        ),
                        value:
                            state.gangInviteOnly ||
                            !state.gangAcceptJoinRequests,
                        onChanged: (v) async {
                          final ok = await state.setGangInviteOnly(v);
                          if (!mounted) return;
                          if (!ok && state.lastAuthError.isNotEmpty) {
                            _snack(state.lastAuthError);
                          }
                        },
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: gangInviteUidCtrl,
                              decoration: InputDecoration(
                                labelText: state.tt(
                                  'Oyuncu adı veya UID',
                                  'Player name or UID',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () async {
                              final ok = await state.sendGangInvite(
                                gangInviteUidCtrl.text,
                              );
                              _snack(
                                ok
                                    ? state.tt(
                                        'Çete daveti gönderildi.',
                                        'Gang invite sent.',
                                      )
                                    : (state.lastAuthError.isNotEmpty
                                          ? state.lastAuthError
                                          : state.tt(
                                              'Davet gönderilemedi.',
                                              'Invite failed.',
                                            )),
                              );
                              if (ok) gangInviteUidCtrl.clear();
                            },
                            child: Text(state.tt('Davet Et', 'Invite')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        state.tt('KATILIM İSTEKLERİ', 'JOIN REQUESTS'),
                        style: const TextStyle(
                          color: Color(0xFFFBBF24),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (state.gangJoinRequests.isEmpty)
                        Text(
                          state.tt(
                            'Bekleyen istek yok.',
                            'No pending requests.',
                          ),
                          style: const TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      ...state.gangJoinRequests.map((req) {
                        final requestId = (req['id']?.toString() ?? '').trim();
                        final fromName =
                            (req['fromName']?.toString() ?? '').trim().isEmpty
                            ? state.tt('Bilinmeyen Oyuncu', 'Unknown Player')
                            : req['fromName'].toString().trim();
                        final fromPower =
                            (req['fromPower'] as num?)?.toInt() ?? 0;
                        final message = (req['message']?.toString() ?? '')
                            .trim();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fromName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${state.tt('Güç', 'Power')}: $fromPower',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                              if (message.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  message,
                                  style: const TextStyle(
                                    color: Color(0xFFD1D5DB),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: requestId.isEmpty
                                          ? null
                                          : () => state.acceptGangJoinRequest(
                                              requestId,
                                            ),
                                      child: Text(
                                        state.tt('Onayla', 'Approve'),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: requestId.isEmpty
                                          ? null
                                          : () => state.rejectGangJoinRequest(
                                              requestId,
                                            ),
                                      child: Text(state.tt('Reddet', 'Reject')),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 6),
                    ],
                    const SizedBox(height: 6),
                    FilledButton(
                      onPressed: state.leaveGang,
                      child: Text(state.tt('Çeteden Ayrıl', 'Leave Gang')),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.tt('ÜYELER', 'MEMBERS'),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    ...state.gangMembers.map(
                      (m) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '- ${m['displayName'] ?? '-'} | ${state.gangRoleName((m['role'] ?? 'Üye').toString())} | ${state.tt('Güç', 'Power')}: ${m['power'] ?? 0}',
                          style: const TextStyle(color: Color(0xFFD1D5DB)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    state.tt('LİDERLİK TABLOSU', 'LEADERBOARD'),
                    style: TextStyle(
                      color: Color(0xFFFBBF24),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: state.refreshSocialData,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...rankedRows.asMap().entries.map(
              (e) => GestureDetector(
                onTap: () => _showLeaderboardProfile(state, e.value),
                child: GlassPanel(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Text(
                        '#${e.key + 1}',
                        style: const TextStyle(
                          color: Color(0xFFFBBF24),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          (e.value['displayName'] ??
                                  e.value['name'] ??
                                  'Oyuncu')
                              .toString(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      Text(
                        '${state.tt('Skor', 'Score')}: ${_leaderboardScore(e.value)}  •  ${state.tt('Güç', 'Power')}: ${(e.value['power'] ?? 0)}',
                        style: const TextStyle(color: Color(0xFF34D399)),
                      ),
                      if (_canAttackRow(state, e.value)) ...[
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: state.tt('Saldır', 'Attack'),
                          onPressed: () =>
                              _openAttackSheetForRow(state, e.value),
                          icon: const Icon(
                            Icons.gps_fixed_rounded,
                            color: Color(0xFFFBBF24),
                            size: 18,
                          ),
                        ),
                      ] else ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white24,
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SocialLeaderboardProfileSheet extends StatelessWidget {
  final String name;
  final String uid;
  final int power;
  final int wins;
  final int cash;
  final String gangName;
  final bool online;
  final bool canAttack;

  const _SocialLeaderboardProfileSheet({
    required this.name,
    required this.uid,
    required this.power,
    required this.wins,
    required this.cash,
    required this.gangName,
    required this.online,
    required this.canAttack,
  });

  String _fmt(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      margin: const EdgeInsets.fromLTRB(12, 16, 12, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: online ? const Color(0xFF34D399) : Colors.white24,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'UID: $uid',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          if (gangName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              gangName,
              style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStat(label: 'Güç', value: '$power'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(label: 'Galibiyet', value: '$wins'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(label: 'Nakit', value: '\$${_fmt(cash)}'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, 'friend'),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Arkadaş Ekle'),
                ),
              ),
              if (canAttack) ...[
                const SizedBox(width: 8),
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
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF34D399),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
