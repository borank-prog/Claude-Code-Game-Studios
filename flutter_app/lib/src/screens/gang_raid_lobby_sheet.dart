import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/gang_raid.dart';
import '../services/gang_raid_service.dart';
import '../models/attack_result.dart';
import 'attack_result_sheet.dart';

class GangRaidLobbySheet extends StatefulWidget {
  final GangRaid raid;
  final String currentUserId;
  final String currentUserName;
  final int totalPower;
  final int targetPower;

  const GangRaidLobbySheet({
    super.key,
    required this.raid,
    required this.currentUserId,
    required this.currentUserName,
    required this.totalPower,
    required this.targetPower,
  });

  @override
  State<GangRaidLobbySheet> createState() => _GangRaidLobbySheetState();
}

class _GangRaidLobbySheetState extends State<GangRaidLobbySheet> {
  final _svc = GangRaidService();
  bool _starting = false;
  bool _joining = false;

  bool get _isLeader => widget.currentUserId == widget.raid.leaderId;

  Future<void> _join(GangRaid raid) async {
    setState(() => _joining = true);
    try {
      await _svc.joinRaid(
        raidId: raid.id,
        userId: widget.currentUserId,
        userName: widget.currentUserName,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Katılım hatası: $e')),
      );
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _start(GangRaid raid) async {
    setState(() => _starting = true);
    try {
      // Server-authoritative gang raid via Cloud Function
      final callable =
          FirebaseFunctions.instance.httpsCallable('executeGangRaid');
      final response = await callable.call<Map<String, dynamic>>({
        'raidId': raid.id,
      });
      final data = Map<String, dynamic>.from(response.data);

      final outcome = data['outcome'] == 'win'
          ? AttackOutcome.win
          : data['outcome'] == 'lose'
              ? AttackOutcome.lose
              : AttackOutcome.draw;

      final result = AttackResult(
        outcome: outcome,
        stolenCash: (data['stolenCash'] as num?)?.toInt() ?? 0,
        xpGained: (data['xpGained'] as num?)?.toInt() ?? 0,
        message: data['message']?.toString() ?? '',
      );

      if (!mounted) return;
      Navigator.pop(context);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AttackResultSheet(result: result),
      );
    } catch (e) {
      setState(() => _starting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GangRaid?>(
      stream: _svc.watchRaid(widget.raid.id),
      initialData: widget.raid,
      builder: (context, snap) {
        final raid = snap.data;
        if (raid == null) return const SizedBox.shrink();

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF111a2e),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
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
              Row(
                children: [
                  const Text(
                    'Çete Baskın Odası',
                    style: TextStyle(
                      color: Color(0xFFfbbf24),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${raid.members.length}/4',
                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Arkadaşlarını davet et, hazır olunca başlat',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 20),
              ...List.generate(4, (i) {
                final filled = i < raid.members.length;
                final uid = filled ? raid.members[i] : null;
                final isMe = uid == widget.currentUserId;
                final isLeader = uid == raid.leaderId;
                final displayName = filled
                    ? (isMe
                        ? 'Sen'
                        : (raid.memberNames[uid] ?? 'Üye ${i + 1}'))
                    : 'Boş slot';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: filled
                        ? const Color(0xFFfbbf24).withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: filled
                          ? const Color(0xFFfbbf24).withValues(alpha: 0.3)
                          : Colors.white12,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        filled ? Icons.person : Icons.person_outline,
                        color: filled ? const Color(0xFFfbbf24) : Colors.white24,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        displayName,
                        style: TextStyle(
                          color: filled ? Colors.white70 : Colors.white24,
                          fontSize: 14,
                        ),
                      ),
                      if (filled && isLeader) ...[
                        const Spacer(),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFfbbf24).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Lider',
                            style: TextStyle(
                              color: Color(0xFFfbbf24),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: raid.id));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Oda kodu kopyalandı!')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.copy, color: Colors.white38, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Oda: ${raid.id.substring(0, 8).toUpperCase()}',
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (!raid.members.contains(widget.currentUserId) && !raid.isFull)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _joining ? null : () => _join(raid),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFfbbf24)),
                        foregroundColor: const Color(0xFFfbbf24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _joining
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFfbbf24),
                              ),
                            )
                          : const Text(
                              'Baskına Katıl',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ),
              if (_isLeader)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (!raid.canStart || _starting)
                        ? null
                        : () => _start(raid),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFfbbf24),
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.white12,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _starting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            raid.canStart
                                ? 'Baskını Başlat (${raid.members.length} kişi)'
                                : 'En az 2 kişi gerekli',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                )
              else
                const Center(
                  child: Text(
                    'Liderin başlatmasını bekliyorsunuz...',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
