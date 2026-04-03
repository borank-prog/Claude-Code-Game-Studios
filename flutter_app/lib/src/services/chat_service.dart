import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message.dart';

class ChatService {
  final _db = FirebaseFirestore.instance;
  static final Set<String> _markReadDeniedRooms = <String>{};

  CollectionReference<Map<String, dynamic>> _col(String roomId) =>
      _db.collection('gang_chats').doc(roomId).collection('messages');

  Stream<List<ChatMessage>> watchMessages(String roomId) {
    return _col(roomId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ChatMessage.fromFirestore(d.id, d.data()))
              .toList(),
        );
  }

  Future<List<ChatMessage>> loadMore(
    String roomId,
    DocumentSnapshot lastDoc,
  ) async {
    final snap = await _col(roomId)
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
    required String roomId,
    required String senderId,
    required String senderName,
    required String text,
    MessageType type = MessageType.text,
    bool updateGangMeta = true,
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

    await _col(roomId).add(msg.toMap()).timeout(const Duration(seconds: 6));

    if (updateGangMeta) {
      await _db
          .collection('gangs')
          .doc(roomId)
          .update({
            'lastMessage': text.trim(),
            'lastMessageAt': FieldValue.serverTimestamp(),
            'lastMessageSender': senderName,
          })
          .timeout(const Duration(seconds: 6));
    }
  }

  Future<void> sendSystemMessage({
    required String roomId,
    required String text,
  }) async {
    await _col(roomId)
        .add({
          'senderId': 'system',
          'senderName': 'Sistem',
          'text': text,
          'type': MessageType.system.name,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        })
        .timeout(const Duration(seconds: 6));
  }

  Stream<int> unreadCount(String roomId, String uid) {
    return _col(roomId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map(
          (s) => s.docs.where((d) {
            final senderId = (d.data()['senderId'] as String?) ?? '';
            return senderId != uid;
          }).length,
        );
  }

  Future<void> markMessagesRead(String roomId, String uid) async {
    if (_markReadDeniedRooms.contains(roomId)) return;
    try {
      final snap = await _col(roomId)
          .where('isRead', isEqualTo: false)
          .limit(50)
          .get()
          .timeout(const Duration(seconds: 6));
      final unreadFromOthers = snap.docs.where((doc) {
        final senderId = (doc.data()['senderId'] as String?) ?? '';
        return senderId != uid;
      }).toList();
      if (unreadFromOthers.isEmpty) return;
      final batch = _db.batch();
      for (final doc in unreadFromOthers) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      _markReadDeniedRooms.add(roomId);
    }
  }
}
