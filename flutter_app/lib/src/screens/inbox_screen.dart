import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/game_state.dart';
import '../widgets/glass_panel.dart';

enum _InboxTab { reports, messages, friendRequests }

class InboxScreen extends StatefulWidget {
  final String uid;

  const InboxScreen({super.key, required this.uid});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  _InboxTab _activeTab = _InboxTab.reports;

  Query<Map<String, dynamic>> get _query => FirebaseFirestore.instance
      .collection('users')
      .doc(widget.uid)
      .collection('inbox')
      .orderBy('createdAt', descending: true)
      .limit(200);

  Future<void> _markRead(
    DocumentReference<Map<String, dynamic>> reference,
  ) async {
    try {
      await reference.update({'isRead': true});
    } catch (_) {}
  }

  Future<void> _markAllRead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final unread = docs.where((d) => d.data()['isRead'] != true).toList();
    if (unread.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final d in unread) {
      batch.update(d.reference, {'isRead': true});
    }
    await batch.commit();
  }

  String _tabTitle(GameState state, _InboxTab tab) {
    switch (tab) {
      case _InboxTab.reports:
        return state.tt('Savaş Raporları', 'Battle Reports');
      case _InboxTab.messages:
        return state.tt('Mesajlar', 'Messages');
      case _InboxTab.friendRequests:
        return state.tt('İstekler', 'Requests');
    }
  }

  bool _isBattleReport(Map<String, dynamic> data) =>
      (data['type'] ?? '').toString().trim() == 'attack_report';

  bool _isFriendRequest(Map<String, dynamic> data) =>
      (data['type'] ?? '').toString().trim() == 'friend_request';

  bool _isGangJoinRequest(Map<String, dynamic> data) =>
      (data['type'] ?? '').toString().trim() == 'gang_join_request';

  IconData _resolveIcon(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString().trim();
    if (type == 'attack_report') {
      final attackType = (data['attackType'] ?? '').toString().trim();
      if (attackType == 'gang' || data['isGangRaid'] == true) {
        return Icons.groups_rounded;
      }
      final direction = (data['direction'] ?? '').toString().trim();
      return direction == 'outgoing'
          ? Icons.outbound_rounded
          : Icons.gps_fixed_rounded;
    }
    if (type == 'friend_request') return Icons.person_add_alt_1_rounded;
    if (type == 'gang_join_request') return Icons.how_to_reg_rounded;
    if (type == 'gang_invite') return Icons.groups_rounded;
    return Icons.mail_outline_rounded;
  }

  Color _resolveColor(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString().trim();
    if (type == 'attack_report') {
      final attackType = (data['attackType'] ?? '').toString().trim();
      if (attackType == 'gang' || data['isGangRaid'] == true) {
        return const Color(0xFF60A5FA);
      }
      return const Color(0xFFFBBF24);
    }
    if (type == 'friend_request') return const Color(0xFF34D399);
    if (type == 'gang_join_request') return const Color(0xFF60A5FA);
    if (type == 'gang_invite') return const Color(0xFFA78BFA);
    return const Color(0xFF94A3B8);
  }

  String _formatWhen(dynamic createdAt) {
    final created = createdAt is Timestamp
        ? createdAt.toDate()
        : DateTime.now();
    return '${created.day.toString().padLeft(2, '0')}.${created.month.toString().padLeft(2, '0')} ${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';
  }

  String _emptyText(GameState state, _InboxTab tab) {
    switch (tab) {
      case _InboxTab.reports:
        return state.tt('Savaş raporu yok.', 'No battle reports yet.');
      case _InboxTab.messages:
        return state.tt('Mesaj yok.', 'No messages yet.');
      case _InboxTab.friendRequests:
        return state.tt(
          'Arkadaş/çete isteği yok.',
          'No friend or gang requests.',
        );
    }
  }

  String _normalizeLookup(String raw) {
    return raw.trim().toLowerCase();
  }

  String _findFriendUidByName(GameState state, String name) {
    final key = _normalizeLookup(name);
    if (key.isEmpty) return '';
    for (final row in state.friends) {
      final friendName = _normalizeLookup(
        (row['displayName'] ?? row['name'] ?? '').toString(),
      );
      if (friendName == key) {
        return (row['uid'] ?? '').toString().trim();
      }
    }
    return '';
  }

  String _messagePeerUid(GameState state, Map<String, dynamic> data) {
    final myUid = state.userId.trim();
    final fromId = (data['fromId'] ?? '').toString().trim();
    final toId = (data['toId'] ?? '').toString().trim();
    if (fromId.isNotEmpty && fromId != myUid) return fromId;
    if (toId.isNotEmpty && toId != myUid) return toId;
    final fromName = (data['fromName'] ?? '').toString().trim();
    if (fromName.isNotEmpty) {
      final found = _findFriendUidByName(state, fromName);
      if (found.isNotEmpty) return found;
    }
    final title = (data['title'] ?? '').toString().trim();
    if (title.isNotEmpty) {
      final found = _findFriendUidByName(state, title);
      if (found.isNotEmpty) return found;
    }
    return '';
  }

  String _messagePeerName(GameState state, Map<String, dynamic> data) {
    final myUid = state.userId.trim();
    final fromId = (data['fromId'] ?? '').toString().trim();
    final toId = (data['toId'] ?? '').toString().trim();
    final fromName = (data['fromName'] ?? '').toString().trim();
    final toName = (data['toName'] ?? '').toString().trim();
    final title = (data['title'] ?? '').toString().trim();

    if (fromId == myUid && toName.isNotEmpty) return toName;
    if (toId == myUid && fromName.isNotEmpty) return fromName;
    if (title.isNotEmpty) return title;
    if (fromName.isNotEmpty) return fromName;
    if (toName.isNotEmpty) return toName;
    return state.tt('Oyuncu', 'Player');
  }

  Future<void> _openMessageReplySheet(
    BuildContext context,
    GameState state,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final peerUid = _messagePeerUid(state, data);
    final peerName = _messagePeerName(state, data);
    final initialBody = (data['body'] ?? '').toString().trim();
    final canReply = peerUid.isNotEmpty;

    final controller = TextEditingController();
    var sending = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1B33),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        final viewInsets = MediaQuery.of(sheetContext).viewInsets.bottom;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + viewInsets),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.mail_outline_rounded,
                          color: Color(0xFFFBBF24),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            peerName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x334B5563)),
                      ),
                      child: Text(
                        initialBody.isEmpty
                            ? state.tt(
                                'Mesaj içeriği yok.',
                                'No message content.',
                              )
                            : initialBody,
                        style: const TextStyle(
                          color: Color(0xFFD1D5DB),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      maxLength: 400,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: state.tt(
                          'Cevabını yaz...',
                          'Write your reply...',
                        ),
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0x334B5563),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0x334B5563),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: (!canReply || sending)
                            ? null
                            : () async {
                                final text = controller.text.trim();
                                if (text.isEmpty) return;
                                setSheetState(() => sending = true);
                                final error = await state.sendDirectMessage(
                                  toUid: peerUid,
                                  text: text,
                                  toName: peerName,
                                );
                                if (!context.mounted) return;
                                if (error == null) {
                                  if (ctx.mounted) Navigator.of(ctx).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        state.tt(
                                          'Mesaj gönderildi.',
                                          'Message sent.',
                                        ),
                                      ),
                                    ),
                                  );
                                } else {
                                  setSheetState(() => sending = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error)),
                                  );
                                }
                              },
                        child: sending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                canReply
                                    ? state.tt('Cevap Gönder', 'Send Reply')
                                    : state.tt(
                                        'Bu mesaja cevap verilemiyor',
                                        'Cannot reply to this message',
                                      ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    controller.dispose();
  }

  Future<void> _handleFriendRequestAction(
    GameState state,
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required bool accept,
  }) async {
    final data = doc.data();
    final requestId = (data['requestId'] ?? '').toString().trim();
    if (requestId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.tt('İstek kimliği bulunamadı.', 'Request id was not found.'),
          ),
        ),
      );
      return;
    }

    if (accept) {
      await state.acceptFriendRequest(requestId);
    } else {
      await state.rejectFriendRequest(requestId);
    }

    if (!mounted) return;
    await doc.reference.update({
      'isRead': true,
      'status': accept ? 'accepted' : 'rejected',
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          accept
              ? state.tt(
                  'Arkadaş isteği kabul edildi.',
                  'Friend request accepted.',
                )
              : state.tt(
                  'Arkadaş isteği reddedildi.',
                  'Friend request rejected.',
                ),
        ),
      ),
    );
  }

  Future<void> _handleGangJoinRequestAction(
    GameState state,
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required bool accept,
  }) async {
    final data = doc.data();
    final requestId = (data['requestId'] ?? '').toString().trim();
    if (requestId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.tt('İstek kimliği bulunamadı.', 'Request id was not found.'),
          ),
        ),
      );
      return;
    }

    if (accept) {
      await state.acceptGangJoinRequest(requestId);
    } else {
      await state.rejectGangJoinRequest(requestId);
    }
    if (!mounted) return;

    String requestStatus = 'pending';
    try {
      final reqSnap = await FirebaseFirestore.instance
          .collection('gang_join_requests')
          .doc(requestId)
          .get();
      requestStatus = (reqSnap.data()?['status'] ?? 'pending')
          .toString()
          .trim()
          .toLowerCase();
    } catch (_) {}

    final expectedStatus = accept ? 'accepted' : 'rejected';
    final success =
        requestStatus == expectedStatus ||
        (requestStatus != 'pending' && requestStatus.isNotEmpty);

    if (!success) {
      final fallback = accept
          ? state.tt(
              'Katılım isteği kabul edilemedi.',
              'Could not accept request.',
            )
          : state.tt(
              'Katılım isteği reddedilemedi.',
              'Could not reject request.',
            );
      final msg = state.lastAuthError.trim().isNotEmpty
          ? state.lastAuthError
          : fallback;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    await doc.reference.update({'isRead': true, 'status': expectedStatus});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          accept
              ? state.tt(
                  'Katılım isteği kabul edildi.',
                  'Join request accepted.',
                )
              : state.tt(
                  'Katılım isteği reddedildi.',
                  'Join request rejected.',
                ),
        ),
      ),
    );
  }

  Widget _tabButton(
    BuildContext context,
    GameState state, {
    required _InboxTab tab,
    required int unreadCount,
  }) {
    final selected = _activeTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFFBBF24).withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? const Color(0xFFFBBF24)
                  : const Color(0x334B5563),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  _tabTitle(state, tab),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFFFBBF24)
                        : const Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (unreadCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34D399),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      color: Color(0xFF06221A),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStandardCard(
    BuildContext context,
    GameState state,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final title = (data['title'] ?? '').toString().trim();
    final body = (data['body'] ?? '').toString().trim();
    final isRead = data['isRead'] == true;
    final when = _formatWhen(data['createdAt']);
    final icon = _resolveIcon(data);
    final iconColor = _resolveColor(data);

    return GestureDetector(
      onTap: () async {
        if (!isRead) {
          await _markRead(doc.reference);
        }
        if (_activeTab == _InboxTab.messages) {
          if (!context.mounted) return;
          await _openMessageReplySheet(context, state, doc);
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
  }

  Widget _buildFriendRequestCard(
    BuildContext context,
    GameState state,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final isFriendRequest = _isFriendRequest(data);
    final isGangJoin = _isGangJoinRequest(data);
    if (!isFriendRequest && !isGangJoin) {
      return _buildStandardCard(context, state, doc);
    }
    final title = (data['title'] ?? '').toString().trim();
    final body = (data['body'] ?? '').toString().trim();
    final fromName = (data['fromName'] ?? data['fromId'] ?? '-')
        .toString()
        .trim();
    final gangName = (data['gangName'] ?? '').toString().trim();
    final requestStatus = (data['status'] ?? 'pending')
        .toString()
        .trim()
        .toLowerCase();
    final isPending = requestStatus == 'pending';
    final isRead = data['isRead'] == true;
    final when = _formatWhen(data['createdAt']);

    return GestureDetector(
      onTap: () async {
        if (!isRead) {
          await _markRead(doc.reference);
        }
      },
      child: GlassPanel(
        margin: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color:
                        (isFriendRequest
                                ? const Color(0xFF34D399)
                                : const Color(0xFF60A5FA))
                            .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isFriendRequest
                        ? Icons.person_add_alt_1_rounded
                        : Icons.how_to_reg_rounded,
                    size: 18,
                    color: isFriendRequest
                        ? const Color(0xFF34D399)
                        : const Color(0xFF60A5FA),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title.isEmpty
                        ? (isFriendRequest
                              ? state.tt('Arkadaşlık isteği', 'Friend request')
                              : state.tt(
                                  'Çete katılım isteği',
                                  'Gang join request',
                                ))
                        : title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  when,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body.isEmpty
                  ? (isFriendRequest
                        ? state.tt(
                            '$fromName sana istek gönderdi.',
                            '$fromName sent you a request.',
                          )
                        : state.tt(
                            '$fromName, ${gangName.isEmpty ? state.tt('çetene', 'your gang') : gangName} katılmak istiyor.',
                            '$fromName wants to join ${gangName.isEmpty ? state.tt('your gang', 'your gang') : gangName}.',
                          ))
                  : body,
              style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 13),
            ),
            if (isPending) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => isFriendRequest
                          ? _handleFriendRequestAction(state, doc, accept: true)
                          : _handleGangJoinRequestAction(
                              state,
                              doc,
                              accept: true,
                            ),
                      child: Text(state.tt('Kabul Et', 'Accept')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => isFriendRequest
                          ? _handleFriendRequestAction(
                              state,
                              doc,
                              accept: false,
                            )
                          : _handleGangJoinRequestAction(
                              state,
                              doc,
                              accept: false,
                            ),
                      child: Text(state.tt('Reddet', 'Reject')),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                requestStatus == 'accepted'
                    ? state.tt('Durum: Kabul edildi', 'Status: Accepted')
                    : state.tt('Durum: Reddedildi', 'Status: Rejected'),
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();

    return Scaffold(
      appBar: AppBar(title: Text(state.tt('Mesaj Kutusu', 'Inbox'))),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _query.snapshots(),
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

          final docs =
              snap.data?.docs ??
              const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          final reports = docs.where((d) => _isBattleReport(d.data())).toList();
          final requests = docs
              .where(
                (d) =>
                    _isFriendRequest(d.data()) || _isGangJoinRequest(d.data()),
              )
              .toList();
          final messages = docs
              .where(
                (d) =>
                    !_isBattleReport(d.data()) &&
                    !_isFriendRequest(d.data()) &&
                    !_isGangJoinRequest(d.data()),
              )
              .toList();

          final unreadReports = reports
              .where((d) => d.data()['isRead'] != true)
              .length;
          final unreadMessages = messages
              .where((d) => d.data()['isRead'] != true)
              .length;
          final unreadRequests = requests
              .where((d) => d.data()['isRead'] != true)
              .length;

          final visibleDocs = switch (_activeTab) {
            _InboxTab.reports => reports,
            _InboxTab.messages => messages,
            _InboxTab.friendRequests => requests,
          };

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                child: Row(
                  children: [
                    _tabButton(
                      context,
                      state,
                      tab: _InboxTab.reports,
                      unreadCount: unreadReports,
                    ),
                    _tabButton(
                      context,
                      state,
                      tab: _InboxTab.messages,
                      unreadCount: unreadMessages,
                    ),
                    _tabButton(
                      context,
                      state,
                      tab: _InboxTab.friendRequests,
                      unreadCount: unreadRequests,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: visibleDocs.isEmpty
                        ? null
                        : () => _markAllRead(visibleDocs),
                    child: Text(
                      state.tt('Sekmeyi Okundu Yap', 'Mark Tab Read'),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: visibleDocs.isEmpty
                    ? Center(
                        child: Text(
                          _emptyText(state, _activeTab),
                          style: const TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 120),
                        itemCount: visibleDocs.length,
                        itemBuilder: (context, index) {
                          final doc = visibleDocs[index];
                          if (_activeTab == _InboxTab.friendRequests) {
                            return _buildFriendRequestCard(context, state, doc);
                          }
                          return _buildStandardCard(context, state, doc);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
