import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/game_state.dart';
import '../widgets/glass_panel.dart';
import 'attack_confirm_sheet.dart';
import 'gang_chat_screen.dart';
import 'gang_leaderboard_screen.dart';
import 'inbox_screen.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final TextEditingController _newGangCtrl = TextEditingController();
  final TextEditingController _joinGangCtrl = TextEditingController();

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
    _newGangCtrl.dispose();
    _joinGangCtrl.dispose();
    super.dispose();
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _showLeaderboardProfile(
    GameState state,
    Map<String, dynamic> row,
    Set<String> attackWindowIds,
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
    final canAttack = _canAttackRow(
      state,
      row,
      attackWindowIds: attackWindowIds,
    );

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

  Set<String> _computeAttackWindowIds(
    GameState state,
    List<Map<String, dynamic>> rows,
  ) {
    final uidRows = rows
        .where((row) => (row['uid'] ?? '').toString().trim().isNotEmpty)
        .toList(growable: false);
    final byPower = List<Map<String, dynamic>>.from(uidRows)
      ..sort((a, b) {
        final powerA = (a['power'] as num?)?.toInt() ?? 0;
        final powerB = (b['power'] as num?)?.toInt() ?? 0;
        return powerB.compareTo(powerA);
      });

    final myPower = state.totalPower;
    var myIndex = byPower.indexWhere(
      (row) => myPower >= ((row['power'] as num?)?.toInt() ?? 0),
    );
    if (myIndex < 0) myIndex = byPower.length;

    final aboveStart = (myIndex - 5).clamp(0, byPower.length).toInt();
    final above = byPower.sublist(aboveStart, myIndex);
    final belowEnd = (myIndex + 5).clamp(0, byPower.length).toInt();
    final below = byPower.sublist(myIndex, belowEnd);

    final ids = <String>{
      ...above.map((row) => (row['uid'] ?? '').toString().trim()),
      ...below.map((row) => (row['uid'] ?? '').toString().trim()),
    }..removeWhere((id) => id.isEmpty || id == state.userId);
    return ids;
  }

  bool _canAttackRow(
    GameState state,
    Map<String, dynamic> row, {
    required Set<String> attackWindowIds,
  }) {
    final uid = (row['uid'] ?? '').toString().trim();
    if (state.userId.isEmpty || uid.isEmpty) return false;
    if (uid == state.userId) return false;
    final power = (row['power'] as num?)?.toInt() ?? 0;
    if (power == state.totalPower) return true;
    return attackWindowIds.contains(uid);
  }

  void _openAttackSheetForRow(
    GameState state,
    Map<String, dynamic> row, {
    required Set<String> attackWindowIds,
  }) {
    if (!_canAttackRow(state, row, attackWindowIds: attackWindowIds)) {
      _snack(
        state.tt(
          'Sadece üstündeki 5 ve altındaki 5 oyuncuya saldırabilirsin.',
          'You can attack only the top 5 above and bottom 5 below you.',
        ),
      );
      return;
    }
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

  int _leaderboardScore(Map<String, dynamic> row) {
    final power = (row['power'] as num?)?.toInt() ?? 0;
    final cash = (row['cash'] as num?)?.toInt() ?? 0;
    final wins = (row['wins'] as num?)?.toInt() ?? 0;
    final gangWins = (row['gangWins'] as num?)?.toInt() ?? 0;
    return (power * 12) + (wins * 900) + (gangWins * 1200) + (cash ~/ 2000);
  }

  Future<void> _createGang(GameState state) async {
    final ok = await state.createGang(_newGangCtrl.text);
    if (!mounted) return;
    if (ok) {
      _newGangCtrl.clear();
      _snack(state.tt('Çete kuruldu.', 'Gang created.'));
      return;
    }
    _snack(
      state.lastAuthError.isNotEmpty
          ? state.lastAuthError
          : state.tt('Çete kurulamadı.', 'Gang could not be created.'),
    );
  }

  Future<void> _joinGang(GameState state, String targetId) async {
    final ok = await state.joinGang(targetId);
    if (!mounted) return;
    if (ok) {
      _joinGangCtrl.clear();
      _snack(state.tt('Katılım isteği gönderildi.', 'Join request sent.'));
      return;
    }
    _snack(
      state.lastAuthError.isNotEmpty
          ? state.lastAuthError
          : state.tt('Çeteye katılınamadı.', 'Could not join gang.'),
    );
  }

  void _openGangMembersSheet(GameState state, Map<String, dynamic> gang) {
    final id = (gang['id']?.toString() ?? '').trim();
    if (id.isEmpty) return;
    final name = (gang['name']?.toString() ?? '').trim();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GangMembersSheet(
        gangId: id,
        gangName: name.isEmpty ? state.tt('Çete', 'Gang') : name,
        currentUid: state.userId,
      ),
    );
  }

  Widget _buildGangSection(GameState state) {
    final hasGang = state.hasGang;
    final discoverable = state.discoverableGangs
        .take(6)
        .toList(growable: false);
    final gangName =
        (state.currentGang?['name']?.toString() ?? '').trim().isNotEmpty
        ? state.currentGang!['name'].toString().trim()
        : state.tt('Çete', 'Gang');

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
                hasGang
                    ? state.tt('KARTEL', 'CARTEL')
                    : state.tt('KARTEL YÖNETİMİ', 'CARTEL MANAGEMENT'),
                style: const TextStyle(
                  color: Color(0xFFFBBF24),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasGang) ...[
            Text(
              gangName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${state.tt('Rütbe', 'Rank')}: ${state.gangRank}   •   ${state.tt('Toplam Güç', 'Total Power')}: ${state.totalGangPower}',
              style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              '${state.tt('Aktif Üye', 'Online Members')}: ${state.onlineGangMembers}/${state.gangMembers.length}',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            if (state.isGangLeader) ...[
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: state.gangInviteOnly,
                onChanged: (v) => state.setGangInviteOnly(v),
                title: Text(
                  state.tt('Sadece davet ile katılım', 'Invite-only joins'),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                subtitle: Text(
                  state.gangInviteOnly
                      ? state.tt(
                          'İstekler kapalı. Sadece davet edilenler katılır.',
                          'Join requests closed. Only invited players can join.',
                        )
                      : state.tt(
                          'İstekler açık. Oyuncular katılım isteği gönderebilir.',
                          'Join requests open. Players can send join requests.',
                        ),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
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
          ] else ...[
            TextField(
              controller: _newGangCtrl,
              decoration: InputDecoration(
                hintText: state.tt('Yeni çete adı', 'New gang name'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 140,
              child: FilledButton(
                onPressed: state.userId.isEmpty
                    ? null
                    : () => _createGang(state),
                child: Text(state.tt('Çete Kur', 'Create')),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _joinGangCtrl,
                    decoration: InputDecoration(
                      hintText: state.tt(
                        'Çete ID ile katıl',
                        'Join with gang ID',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: state.userId.isEmpty
                      ? null
                      : () => _joinGang(state, _joinGangCtrl.text),
                  child: Text(state.tt('Katıl', 'Join')),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              state.tt('AÇIK ÇETELER', 'OPEN GANGS'),
              style: const TextStyle(
                color: Color(0xFFFBBF24),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            if (discoverable.isEmpty)
              Text(
                state.tt(
                  'Şu an açık çete bulunamadı.',
                  'No open gangs available right now.',
                ),
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              )
            else
              ...discoverable.map((g) {
                final id = (g['id']?.toString() ?? '').trim();
                final name = (g['name']?.toString() ?? '').trim();
                final members = (g['memberCount'] as num?)?.toInt() ?? 0;
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: id.isEmpty
                      ? null
                      : () => _openGangMembersSheet(state, g),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x334B5563)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name.isEmpty ? state.tt('Çete', 'Gang') : name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '${state.tt('Üye', 'Members')}: $members  •  ID: $id',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 34,
                          child: OutlinedButton(
                            onPressed: id.isEmpty
                                ? null
                                : () => _joinGang(state, id),
                            child: Text(state.tt('Katıl', 'Join')),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, state, _) {
        final rows = state.leaderboardRows;
        final rankedRows = List<Map<String, dynamic>>.from(
          rows,
        )..sort((a, b) => _leaderboardScore(b).compareTo(_leaderboardScore(a)));
        final attackWindowIds = _computeAttackWindowIds(state, rankedRows);

        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
          children: [
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
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: state.userId.isEmpty
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GangChatScreen(
                            roomId: 'global',
                            roomName: state.tt('Genel Sohbet', 'Global Chat'),
                            currentUid: state.userId,
                            currentName: state.playerName,
                            isGlobal: true,
                          ),
                        ),
                      );
                    },
              icon: const Icon(Icons.forum_outlined, size: 18),
              label: Text(state.tt('Genel Sohbet', 'Global Chat')),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
            const SizedBox(height: 8),
            _buildGangSection(state),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    state.tt('LİDERLİK TABLOSU', 'LEADERBOARD'),
                    style: TextStyle(
                      color: Color(0xFFFBBF24),
                      fontSize: 17,
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
            if (rankedRows.isEmpty)
              GlassPanel(
                child: Text(
                  state.tt(
                    'Liderlik tablosu yükleniyor veya henüz oyuncu yok.',
                    'Leaderboard is loading or no players yet.',
                  ),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              ...rankedRows.asMap().entries.map(
                (e) => GestureDetector(
                  onTap: () =>
                      _showLeaderboardProfile(state, e.value, attackWindowIds),
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
                        if (_canAttackRow(
                          state,
                          e.value,
                          attackWindowIds: attackWindowIds,
                        )) ...[
                          const SizedBox(width: 6),
                          IconButton(
                            tooltip: state.tt('Saldır', 'Attack'),
                            onPressed: () => _openAttackSheetForRow(
                              state,
                              e.value,
                              attackWindowIds: attackWindowIds,
                            ),
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
                    fontSize: 16,
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

class _GangMembersSheet extends StatelessWidget {
  final String gangId;
  final String gangName;
  final String currentUid;

  const _GangMembersSheet({
    required this.gangId,
    required this.gangName,
    required this.currentUid,
  });

  Widget _buildMemberTiles({
    required BuildContext context,
    required GameState state,
    required List<Map<String, dynamic>> members,
  }) {
    if (members.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          state.tt(
            'Bu çetede henüz üye görünmüyor.',
            'No members visible in this gang yet.',
          ),
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 360),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: members.length,
        separatorBuilder: (_, index) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final raw = members[index];
          final uid = ((raw['uid'] as String?) ?? '').trim();
          final rawName =
              ((raw['displayName'] ?? raw['name']) as String?) ?? '';
          final name = rawName.trim().isEmpty
              ? state.tt('Oyuncu', 'Player')
              : rawName.trim();
          final role = ((raw['role'] as String?) ?? '').trim();
          final power = (raw['power'] as num?)?.toInt() ?? 0;
          final isMe = uid == currentUid;
          return InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: uid.isEmpty
                ? null
                : () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => _GangMemberProfileSheet(
                        uid: uid,
                        fallbackName: name,
                        role: role,
                        fallbackPower: power,
                        gangName: gangName,
                        isCurrentUser: isMe,
                      ),
                    );
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x334B5563)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFFFBBF24),
                        fontWeight: FontWeight.w800,
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
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isMe)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF34D399,
                                  ).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  state.tt('Sen', 'You'),
                                  style: const TextStyle(
                                    color: Color(0xFF34D399),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Text(
                          role.isEmpty
                              ? '${state.tt('Güç', 'Power')}: $power'
                              : '${state.gangRoleName(role)}  •  ${state.tt('Güç', 'Power')}: $power',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white24,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<GameState>();
    return GlassPanel(
      margin: const EdgeInsets.fromLTRB(12, 16, 12, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
            '${state.tt('Çete ID', 'Gang ID')}: $gangId',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
          ),
          const SizedBox(height: 10),
          Text(
            state.tt('ÜYELER', 'MEMBERS'),
            style: const TextStyle(
              color: Color(0xFFFBBF24),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('gangs')
                .doc(gangId)
                .collection('members')
                .orderBy('power', descending: true)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              final docs = snap.data?.docs ?? const [];
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    state.tt(
                      'Üyeler yüklenemedi, yedek listeden deneniyor...',
                      'Could not load members, trying backup list...',
                    ),
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                );
              }

              if (docs.isNotEmpty) {
                final members = docs
                    .map((d) {
                      final m = Map<String, dynamic>.from(d.data());
                      m['uid'] = ((m['uid'] as String?) ?? d.id).trim();
                      return m;
                    })
                    .toList(growable: false);
                return _buildMemberTiles(
                  context: context,
                  state: state,
                  members: members,
                );
              }

              return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .where('gangId', isEqualTo: gangId)
                    .limit(20)
                    .get(),
                builder: (context, userSnap) {
                  if (userSnap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  if (userSnap.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        state.tt(
                          'Çete üyeleri şu an getirilemedi.',
                          'Could not fetch gang members right now.',
                        ),
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                    );
                  }
                  final members =
                      userSnap.data?.docs
                          .map((d) {
                            final data = d.data();
                            return <String, dynamic>{
                              'uid': d.id,
                              'displayName':
                                  data['displayName'] ?? data['name'],
                              'role': data['gangRole'] ?? '',
                              'power': (data['power'] as num?)?.toInt() ?? 0,
                            };
                          })
                          .toList(growable: false) ??
                      const <Map<String, dynamic>>[];
                  final sorted = List<Map<String, dynamic>>.from(members)
                    ..sort((a, b) {
                      final pa = (a['power'] as num?)?.toInt() ?? 0;
                      final pb = (b['power'] as num?)?.toInt() ?? 0;
                      return pb.compareTo(pa);
                    });
                  return _buildMemberTiles(
                    context: context,
                    state: state,
                    members: sorted,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GangMemberProfileSheet extends StatelessWidget {
  final String uid;
  final String fallbackName;
  final String role;
  final int fallbackPower;
  final String gangName;
  final bool isCurrentUser;

  const _GangMemberProfileSheet({
    required this.uid,
    required this.fallbackName,
    required this.role,
    required this.fallbackPower,
    required this.gangName,
    required this.isCurrentUser,
  });

  String _fmtCash(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return '$value';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<GameState>();
    return GlassPanel(
      margin: const EdgeInsets.fromLTRB(12, 16, 12, 24),
      child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
        builder: (context, snap) {
          final data = snap.data?.data();
          final name =
              ((data?['displayName'] ?? data?['name'] ?? fallbackName)
                      .toString())
                  .trim();
          final resolvedName = name.isEmpty
              ? state.tt('Oyuncu', 'Player')
              : name;
          final power = (data?['power'] as num?)?.toInt() ?? fallbackPower;
          final wins = (data?['wins'] as num?)?.toInt() ?? 0;
          final cash = (data?['cash'] as num?)?.toInt() ?? 0;
          final level = (data?['level'] as num?)?.toInt() ?? 1;
          final online = data?['online'] == true;
          final resolvedGangName =
              ((data?['gangName'] as String?)?.trim() ?? gangName).trim();

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      resolvedName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
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
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'UID: $uid',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: state.tt('UID Kopyala', 'Copy UID'),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: uid));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            state.tt('UID kopyalandı.', 'UID copied.'),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.copy_rounded,
                      size: 18,
                      color: Color(0xFFFBBF24),
                    ),
                  ),
                ],
              ),
              if (resolvedGangName.isNotEmpty || role.isNotEmpty)
                Text(
                  [
                    if (resolvedGangName.isNotEmpty) resolvedGangName,
                    if (role.isNotEmpty) state.gangRoleName(role),
                  ].join('  •  '),
                  style: const TextStyle(
                    color: Color(0xFFFBBF24),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (isCurrentUser) ...[
                const SizedBox(height: 4),
                Text(
                  state.tt('Bu sensin.', 'This is you.'),
                  style: const TextStyle(
                    color: Color(0xFF34D399),
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _GangProfileStat(
                      label: state.tt('Seviye', 'Level'),
                      value: '$level',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _GangProfileStat(
                      label: state.tt('Güç', 'Power'),
                      value: '$power',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _GangProfileStat(
                      label: state.tt('Galibiyet', 'Wins'),
                      value: '$wins',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _GangProfileStat(
                label: state.tt('Nakit', 'Cash'),
                value: '\$${_fmtCash(cash)}',
                fullWidth: true,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GangProfileStat extends StatelessWidget {
  final String label;
  final String value;
  final bool fullWidth;

  const _GangProfileStat({
    required this.label,
    required this.value,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
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
    if (fullWidth) return SizedBox(width: double.infinity, child: child);
    return child;
  }
}
