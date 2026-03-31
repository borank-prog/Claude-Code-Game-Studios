import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/game_state.dart';
import '../widgets/glass_panel.dart';

class InboxScreen extends StatelessWidget {
  final String uid;

  const InboxScreen({super.key, required this.uid});

  Future<void> _markAllRead() async {
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('inbox');
    final snap = await col.where('isRead', isEqualTo: false).limit(200).get();
    if (snap.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final d in snap.docs) {
      batch.update(d.reference, {'isRead': true});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final query = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('inbox')
        .orderBy('createdAt', descending: true)
        .limit(200);

    return Scaffold(
      appBar: AppBar(
        title: Text(state.tt('Mesaj Kutusu', 'Inbox')),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: Text(state.tt('Tümünü Okundu Yap', 'Mark all read')),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text(
                state.tt(
                  'Mesajlar yüklenemedi.',
                  'Messages could not be loaded.',
                ),
              ),
            );
          }
          final docs = snap.data?.docs ?? const [];
          if (docs.isEmpty) {
            return Center(
              child: Text(
                state.tt('Mesaj kutun boş.', 'Your inbox is empty.'),
                style: const TextStyle(color: Color(0xFF94A3B8)),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final title = (data['title'] ?? '').toString().trim();
              final body = (data['body'] ?? '').toString().trim();
              final type = (data['type'] ?? '').toString().trim();
              final isRead = data['isRead'] == true;
              final createdAt = data['createdAt'];
              final created = createdAt is Timestamp
                  ? createdAt.toDate()
                  : DateTime.now();
              final when =
                  '${created.day.toString().padLeft(2, '0')}.${created.month.toString().padLeft(2, '0')} ${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';

              IconData icon = Icons.notifications_rounded;
              Color iconColor = const Color(0xFF94A3B8);
              if (type == 'attack_report') {
                icon = Icons.gps_fixed_rounded;
                iconColor = const Color(0xFFFBBF24);
              } else if (type == 'friend_request') {
                icon = Icons.person_add_alt_1_rounded;
                iconColor = const Color(0xFF34D399);
              }

              return GestureDetector(
                onTap: () async {
                  if (!isRead) {
                    await doc.reference.update({'isRead': true});
                  }
                },
                child: GlassPanel(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, size: 18, color: iconColor),
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
                                    title.isEmpty
                                        ? state.tt('Bildirim', 'Notification')
                                        : title,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: isRead
                                          ? FontWeight.w600
                                          : FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  when,
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            if (body.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                body,
                                style: const TextStyle(
                                  color: Color(0xFFD1D5DB),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!isRead) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.brightness_1_rounded,
                          size: 10,
                          color: Color(0xFF34D399),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
