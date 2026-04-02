import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/gang_war.dart';
import '../models/gang_war_event.dart';
import '../models/gang_war_participant.dart';
import '../models/gang_war_report.dart';
import '../services/gang_war_service.dart';
import '../state/game_state.dart';

class GangWarScreen extends StatefulWidget {
  const GangWarScreen({super.key});

  @override
  State<GangWarScreen> createState() => _GangWarScreenState();
}

class _GangWarScreenState extends State<GangWarScreen> {
  final GangWarService _service = GangWarService();
  bool _loadingWars = true;
  bool _busy = false;
  String _error = '';
  List<GangWar> _wars = const <GangWar>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAll();
    });
  }

  Future<void> _refreshAll() async {
    final state = context.read<GameState>();
    await state.refreshSocialData();
    await _loadWars();
  }

  Future<void> _loadWars() async {
    final state = context.read<GameState>();
    final gangId = state.gangId.trim();
    if (gangId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _wars = const <GangWar>[];
        _loadingWars = false;
        _error = '';
      });
      return;
    }

    setState(() {
      _loadingWars = true;
      _error = '';
    });

    try {
      final rows = await _service.fetchRecentWarsForGang(
        gangId: gangId,
        limit: 25,
      );
      if (!mounted) return;
      setState(() {
        _wars = rows;
        _loadingWars = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingWars = false;
        _error = e.toString();
      });
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  List<Map<String, dynamic>> _targetGangs(GameState state) {
    final myGangId = state.gangId.trim();
    final rows = state.discoverableGangs
        .where((g) {
          final id = (g['id']?.toString() ?? '').trim();
          if (id.isEmpty || id == myGangId) return false;
          final memberCount = (g['memberCount'] as num?)?.toInt() ?? 0;
          return memberCount >= state.gangWarMinMembersToStart;
        })
        .map((g) => Map<String, dynamic>.from(g))
        .toList(growable: false);

    rows.sort((a, b) {
      final membersA = (a['memberCount'] as num?)?.toInt() ?? 0;
      final membersB = (b['memberCount'] as num?)?.toInt() ?? 0;
      final byMembers = membersB.compareTo(membersA);
      if (byMembers != 0) return byMembers;
      final powerA = (a['totalPower'] as num?)?.toInt() ?? 0;
      final powerB = (b['totalPower'] as num?)?.toInt() ?? 0;
      return powerB.compareTo(powerA);
    });
    return rows;
  }

  Future<void> _pickAndStartWar(GameState state) async {
    final blocked = state.gangWarStartBlockReason;
    if (blocked != null && blocked.trim().isNotEmpty) {
      _snack(blocked);
      return;
    }

    final targets = _targetGangs(state);
    if (targets.isEmpty) {
      _snack(
        state.tt(
          'Şu an savaş açılabilecek uygun kartel bulunamadı.',
          'No eligible cartel found to start a war.',
        ),
      );
      return;
    }

    final selectedGangId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF0F1B33),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.tt('Hedef Kartel Seç', 'Select Target Cartel'),
                  style: const TextStyle(
                    color: Color(0xFFFBBF24),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: MediaQuery.of(sheetCtx).size.height * 0.55,
                  child: ListView.separated(
                    itemCount: targets.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final row = targets[i];
                      final id = (row['id']?.toString() ?? '').trim();
                      final name = (row['name']?.toString() ?? '').trim();
                      final count = (row['memberCount'] as num?)?.toInt() ?? 0;
                      final power = (row['totalPower'] as num?)?.toInt() ?? 0;
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: id.isEmpty
                            ? null
                            : () => Navigator.of(sheetCtx).pop(id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x337F8EA8)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name.isEmpty
                                          ? state.tt('Kartel', 'Cartel')
                                          : name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${state.tt('Üye', 'Members')}: $count  •  ${state.tt('Güç', 'Power')}: $power',
                                      style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Color(0xFF94A3B8),
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    final targetGangId = (selectedGangId ?? '').trim();
    if (targetGangId.isEmpty) return;

    setState(() => _busy = true);
    try {
      final result = await _service.createWarByTargetGang(
        targetGangId: targetGangId,
      );
      final warId = (result['warId']?.toString() ?? '').trim();
      _snack(
        state.tt(
          warId.isEmpty
              ? 'Kartel savaşı başlatıldı.'
              : 'Kartel savaşı başlatıldı. ID: $warId',
          warId.isEmpty
              ? 'Cartel war started.'
              : 'Cartel war started. ID: $warId',
        ),
      );
      await _loadWars();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolveWar(GameState state, GangWar war) async {
    if (!state.canInitiateGangWar) {
      _snack(
        state.tt(
          'Bu işlemi sadece Lider veya Sağ Kol yapabilir.',
          'Only Leader or Right Hand can resolve this.',
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await _service.resolveWar(warId: war.id);
      final winnerGangId = (result['winnerGangId']?.toString() ?? '').trim();
      final resolvedMsg = winnerGangId.isEmpty
          ? state.tt('Savaş berabere bitti.', 'War ended in draw.')
          : (winnerGangId == state.gangId
                ? state.tt('Savaşı kazandınız.', 'Your cartel won the war.')
                : state.tt('Savaşı kaybettiniz.', 'Your cartel lost the war.'));
      _snack(resolvedMsg);
      await _loadWars();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _statusLabel(GameState state, GangWar war) {
    switch (war.status) {
      case GangWarStatus.recruiting:
        return state.tt('Toplanıyor', 'Recruiting');
      case GangWarStatus.ready:
        return state.tt('Hazır', 'Ready');
      case GangWarStatus.active:
        return state.tt('Aktif', 'Active');
      case GangWarStatus.resolved:
        return state.tt('Sonuçlandı', 'Resolved');
      case GangWarStatus.cancelled:
        return state.tt('İptal', 'Cancelled');
    }
  }

  String _resultLabel(GameState state, GangWar war) {
    switch (war.result) {
      case GangWarResult.pending:
        return state.tt('Bekliyor', 'Pending');
      case GangWarResult.attackerWin:
        return state.tt('Saldıran Kazandı', 'Attacker Won');
      case GangWarResult.defenderWin:
        return state.tt('Savunan Kazandı', 'Defender Won');
      case GangWarResult.draw:
        return state.tt('Berabere', 'Draw');
    }
  }

  Color _statusColor(GangWar war) {
    switch (war.status) {
      case GangWarStatus.active:
        return const Color(0xFF34D399);
      case GangWarStatus.resolved:
        return const Color(0xFFFBBF24);
      case GangWarStatus.cancelled:
        return const Color(0xFFF87171);
      case GangWarStatus.ready:
        return const Color(0xFF60A5FA);
      case GangWarStatus.recruiting:
        return const Color(0xFF94A3B8);
    }
  }

  String _timeLabel(DateTime? dt) {
    if (dt == null) return '-';
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _participantSlotLabel(GameState state, GangWarParticipant p) {
    return '${p.displayName} • ${state.gangRoleName(p.gangRole)} • ${state.tt('Güç', 'Power')}: ${p.powerSnapshot}';
  }

  String _eventTitle(GameState state, GangWarEvent e) {
    switch (e.type) {
      case 'war_created':
        return state.tt('Savaş Başladı', 'War Started');
      case 'duel_resolved':
        return state.tt('Tur ${e.turn}', 'Round ${e.turn}');
      case 'war_resolved':
        return state.tt('Savaş Sonucu', 'War Result');
      default:
        return state.tt('Olay', 'Event');
    }
  }

  String _eventBody(GameState state, GangWarEvent e) {
    final payload = e.payload;
    if (e.type == 'war_created') {
      final ac = (payload['attackerCount'] as num?)?.toInt() ?? 0;
      final dc = (payload['defenderCount'] as num?)?.toInt() ?? 0;
      final dur = (payload['durationMinutes'] as num?)?.toInt() ?? 0;
      return state.tt(
        'Kadrolar hazırlandı: $ac vs $dc • Süre: $dur dk',
        'Rosters are ready: $ac vs $dc • Duration: $dur min',
      );
    }
    if (e.type == 'duel_resolved') {
      final atkName = (payload['attackerName']?.toString() ?? '').trim();
      final defName = (payload['defenderName']?.toString() ?? '').trim();
      final atkWeapon = (payload['attackerWeapon']?.toString() ?? '').trim();
      final defWeapon = (payload['defenderWeapon']?.toString() ?? '').trim();
      final atkTotal = (payload['attackerTotal'] as num?)?.toInt() ?? 0;
      final defTotal = (payload['defenderTotal'] as num?)?.toInt() ?? 0;
      final result = (payload['result']?.toString() ?? '').trim();
      final resultLabel = result == 'attacker'
          ? state.tt('Saldıran turu aldı', 'Attacker won the round')
          : result == 'defender'
          ? state.tt('Savunan turu aldı', 'Defender won the round')
          : state.tt('Tur berabere', 'Round draw');
      return state.tt(
        '$atkName ($atkWeapon) vs $defName ($defWeapon) • $atkTotal-$defTotal • $resultLabel',
        '$atkName ($atkWeapon) vs $defName ($defWeapon) • $atkTotal-$defTotal • $resultLabel',
      );
    }
    if (e.type == 'war_resolved') {
      final atkScore = (payload['attackerScore'] as num?)?.toInt() ?? 0;
      final defScore = (payload['defenderScore'] as num?)?.toInt() ?? 0;
      final winnerGangId = (payload['winnerGangId']?.toString() ?? '').trim();
      if (winnerGangId.isEmpty) {
        return state.tt(
          'Skor: $atkScore-$defScore • Berabere',
          'Score: $atkScore-$defScore • Draw',
        );
      }
      final winnerName = (payload['winnerGangName']?.toString() ?? '').trim();
      return state.tt(
        'Skor: $atkScore-$defScore • Kazanan: ${winnerName.isEmpty ? winnerGangId : winnerName}',
        'Score: $atkScore-$defScore • Winner: ${winnerName.isEmpty ? winnerGangId : winnerName}',
      );
    }
    return state.tt('Detay bulunamadı.', 'No details available.');
  }

  Future<void> _openWarDetailSheet(GameState state, GangWar war) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1B33),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.of(sheetCtx).size.height * 0.88,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${war.attackerGangName}  vs  ${war.defenderGangName}',
                          style: const TextStyle(
                            color: Color(0xFFFBBF24),
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(war).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusLabel(state, war),
                          style: TextStyle(
                            color: _statusColor(war),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${state.tt('Skor', 'Score')}: ${war.attackerCount}-${war.defenderCount}  •  ${state.tt('Başlangıç', 'Start')}: ${_timeLabel(war.startsAt)}  •  ${state.tt('Bitiş', 'End')}: ${_timeLabel(war.endsAt)}',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    state.tt('KADROLAR', 'ROSTERS'),
                    style: const TextStyle(
                      color: Color(0xFFFBBF24),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: StreamBuilder<List<GangWarParticipant>>(
                      stream: _service.watchParticipants(war.id),
                      builder: (context, participantSnap) {
                        final participants =
                            participantSnap.data ??
                            const <GangWarParticipant>[];
                        final attackers = participants
                            .where((p) => p.side == GangWarSide.attacker)
                            .toList(growable: false);
                        final defenders = participants
                            .where((p) => p.side == GangWarSide.defender)
                            .toList(growable: false);

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0x337F8EA8),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      state.tt('Saldıran', 'Attacker'),
                                      style: const TextStyle(
                                        color: Color(0xFF34D399),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (attackers.isEmpty)
                                      Text(
                                        state.tt(
                                          'Kadrolar yükleniyor...',
                                          'Roster loading...',
                                        ),
                                        style: const TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 12,
                                        ),
                                      )
                                    else
                                      ...attackers.map(
                                        (p) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 4,
                                          ),
                                          child: Text(
                                            _participantSlotLabel(state, p),
                                            style: const TextStyle(
                                              color: Color(0xFFCBD5E1),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0x337F8EA8),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      state.tt('Savunan', 'Defender'),
                                      style: const TextStyle(
                                        color: Color(0xFF60A5FA),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (defenders.isEmpty)
                                      Text(
                                        state.tt(
                                          'Kadrolar yükleniyor...',
                                          'Roster loading...',
                                        ),
                                        style: const TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 12,
                                        ),
                                      )
                                    else
                                      ...defenders.map(
                                        (p) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 4,
                                          ),
                                          child: Text(
                                            _participantSlotLabel(state, p),
                                            style: const TextStyle(
                                              color: Color(0xFFCBD5E1),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    state.tt('SAVAŞ AKIŞI', 'WAR FLOW'),
                    style: const TextStyle(
                      color: Color(0xFFFBBF24),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: StreamBuilder<List<GangWarEvent>>(
                      stream: _service.watchEvents(warId: war.id, limit: 100),
                      builder: (context, eventSnap) {
                        final events = eventSnap.data ?? const <GangWarEvent>[];
                        if (events.isEmpty) {
                          return Text(
                            state.tt(
                              'Henüz savaş olayı oluşmadı.',
                              'No war events yet.',
                            ),
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          );
                        }
                        return ListView.builder(
                          itemCount: events.length,
                          itemBuilder: (_, i) {
                            final e = events[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0x337F8EA8),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        _eventTitle(state, e),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _timeLabel(e.createdAt),
                                        style: const TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _eventBody(state, e),
                                    style: const TextStyle(
                                      color: Color(0xFFCBD5E1),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => Navigator.pop(sheetCtx),
                          child: Text(state.tt('Kapat', 'Close')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: (_busy || war.isFinished)
                              ? null
                              : () async {
                                  Navigator.pop(sheetCtx);
                                  await _resolveWar(state, war);
                                },
                          icon: const Icon(Icons.bolt_rounded, size: 16),
                          label: Text(state.tt('Savaşı Çöz', 'Resolve War')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final canStart = state.gangWarStartBlockReason == null;
    final activeWars = _wars
        .where((w) => !w.isFinished && w.status == GangWarStatus.active)
        .toList(growable: false);
    final historyWars = _wars
        .where((w) => w.isFinished || w.status == GangWarStatus.resolved)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: const Color(0xFF081428),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1B33),
        title: Text(state.tt('Kartel Savaşı', 'Cartel War')),
        actions: [
          IconButton(
            onPressed: _busy ? null : _refreshAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        color: const Color(0xFFFBBF24),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            Container(
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
                    state.tt('Savaş Durumu', 'War Status'),
                    style: const TextStyle(
                      color: Color(0xFFFBBF24),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    state.tt(
                      'Uygun Üye: ${state.gangWarEligibleMemberCount}/${state.gangWarMaxMembersPerSide}  •  Min: ${state.gangWarMinMembersToStart}',
                      'Eligible Members: ${state.gangWarEligibleMemberCount}/${state.gangWarMaxMembersPerSide}  •  Min: ${state.gangWarMinMembersToStart}',
                    ),
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.canInitiateGangWar
                        ? state.tt(
                            'Yetki: Komutan (Lider / Sağ Kol)',
                            'Permission: Commander (Leader / Right Hand)',
                          )
                        : state.tt(
                            'Yetki: Üye (savaş başlatamaz)',
                            'Permission: Member (cannot start war)',
                          ),
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                  if (!canStart && state.gangWarStartBlockReason != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      state.gangWarStartBlockReason!,
                      style: const TextStyle(
                        color: Color(0xFFF87171),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _pickAndStartWar(state),
                      icon: const Icon(Icons.shield_moon_outlined, size: 18),
                      label: Text(
                        state.tt(
                          'Yeni Kartel Savaşı Başlat',
                          'Start New Cartel War',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              state.tt('AKTİF SAVAŞLAR', 'ACTIVE WARS'),
              style: const TextStyle(
                color: Color(0xFFFBBF24),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            if (_loadingWars)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFFBBF24)),
                ),
              )
            else if (_error.trim().isNotEmpty)
              Text(
                _error,
                style: const TextStyle(color: Color(0xFFF87171), fontSize: 12),
              )
            else if (activeWars.isEmpty)
              Text(
                state.tt(
                  'Şu an aktif kartel savaşı yok.',
                  'No active cartel wars right now.',
                ),
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              )
            else
              ...activeWars.map(
                (war) => InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openWarDetailSheet(state, war),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0x2214213B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x557F8EA8)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${war.attackerGangName}  vs  ${war.defenderGangName}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(
                                  war,
                                ).withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _statusLabel(state, war),
                                style: TextStyle(
                                  color: _statusColor(war),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${state.tt('Skor', 'Score')}: ${war.attackerCount}-${war.defenderCount}  •  ${state.tt('Bitiş', 'Ends')}: ${_timeLabel(war.endsAt)}',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => _openWarDetailSheet(state, war),
                                icon: const Icon(
                                  Icons.visibility_outlined,
                                  size: 16,
                                ),
                                label: Text(state.tt('Detay', 'Details')),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => _resolveWar(state, war),
                                icon: const Icon(Icons.bolt_rounded, size: 16),
                                label: Text(
                                  state.tt('Savaşı Çöz', 'Resolve War'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Text(
              state.tt('SONUÇLANAN SAVAŞLAR', 'RESOLVED WARS'),
              style: const TextStyle(
                color: Color(0xFFFBBF24),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            if (historyWars.isEmpty)
              Text(
                state.tt('Henüz sonuçlanan savaş yok.', 'No resolved war yet.'),
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              )
            else
              ...historyWars
                  .take(8)
                  .map(
                    (war) => InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openWarDetailSheet(state, war),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0x2214213B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x557F8EA8)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${war.attackerGangName}  vs  ${war.defenderGangName}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _resultLabel(state, war),
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (war.winnerGangId.trim().isNotEmpty)
                              Text(
                                war.winnerGangId.trim() == state.gangId
                                    ? state.tt('Kazandın', 'Won')
                                    : state.tt('Kaybettin', 'Lost'),
                                style: TextStyle(
                                  color: war.winnerGangId.trim() == state.gangId
                                      ? const Color(0xFF34D399)
                                      : const Color(0xFFF87171),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
            const SizedBox(height: 10),
            Text(
              state.tt('SAVAŞ RAPORLARI', 'WAR REPORTS'),
              style: const TextStyle(
                color: Color(0xFFFBBF24),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            StreamBuilder<List<GangWarReport>>(
              stream: _service.watchMyReports(uid: state.userId, limit: 20),
              builder: (context, snapshot) {
                final rows = snapshot.data ?? const <GangWarReport>[];
                if (rows.isEmpty) {
                  return Text(
                    state.tt(
                      'Henüz kartel savaş raporu yok.',
                      'No cartel war report yet.',
                    ),
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  );
                }
                return Column(
                  children: rows
                      .take(8)
                      .map((r) {
                        final gainColor = r.cashDelta >= 0
                            ? const Color(0xFF34D399)
                            : const Color(0xFFF87171);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0x2214213B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x557F8EA8)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.title.isEmpty
                                    ? state.tt('Kartel Savaşı', 'Cartel War')
                                    : r.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                r.summary,
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    '${state.tt('Skor', 'Score')}: ${r.attackerScore}-${r.defenderScore}',
                                    style: const TextStyle(
                                      color: Color(0xFFCBD5E1),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${r.cashDelta >= 0 ? '+' : ''}\$${r.cashDelta}  •  +${r.xpDelta} XP',
                                    style: TextStyle(
                                      color: gainColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      })
                      .toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
