import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat_message.dart';

class ChatService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String gangId) =>
      _db.collection('gang_chats').doc(gangId).collection('messages');

  Stream<List<ChatMessage>> watchMessages(String gangId) {
    return _col(gangId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ChatMessage.fromFirestore(d.id, d.data()))
            .toList());
  }

  Future<List<ChatMessage>> loadMore(
    String gangId,
    DocumentSnapshot lastDoc,
  ) async {
    final snap = await _col(gangId)
        .orderBy('timestamp', descending: true)
        .startAfterDocument(lastDoc)
        .limit(30)
        .get()
        .timeout(const Duration(seconds: 8));

    return snap.docs
        .map((d) => ChatMessage.fromFirestore(d.id, d.data()))
        .toList();
  }

  Future<void> sendMessage({
    required String gangId,
    required String senderId,
    required String senderName,
    required String text,
    MessageType type = MessageType.text,
  }) async {
    if (text.trim().isEmpty) return;

    final msg = ChatMessage(
      id: '',
      senderId: senderId,
      senderName: senderName,
      text: text.trim(),
      type: type,
      timestamp: DateTime.now(),
    );

    await _col(gangId).add(msg.toMap()).timeout(const Duration(seconds: 6));

    await _db.collection('gangs').doc(gangId).update({
      'lastMessage': text.trim(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSender': senderName,
    }).timeout(const Duration(seconds: 6));
  }

  Future<void> sendSystemMessage({
    required String gangId,
    required String text,
  }) async {
    await _col(gangId).add({
      'senderId': 'system',
      'senderName': 'Sistem',
      'text': text,
      'type': MessageType.system.name,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    }).timeout(const Duration(seconds: 6));
  }

  Stream<int> unreadCount(String gangId, String uid) {
    return _col(gangId)
        .where('isRead', isEqualTo: false)
        .where('senderId', isNotEqualTo: uid)
        .snapshots()
        .map((s) => s.docs.length);
  }

  Future<void> markMessagesRead(String gangId, String uid) async {
    final snap = await _col(gangId)
        .where('isRead', isEqualTo: false)
        .where('senderId', isNotEqualTo: uid)
        .limit(50)
        .get()
        .timeout(const Duration(seconds: 6));
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }
}
