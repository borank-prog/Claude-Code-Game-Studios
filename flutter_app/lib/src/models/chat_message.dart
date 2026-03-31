import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, system, attack }

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final MessageType type;
  final DateTime timestamp;
  final bool isRead;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });

  factory ChatMessage.fromFirestore(String docId, Map<String, dynamic> d) {
    return ChatMessage(
      id: docId,
      senderId: d['senderId'] as String,
      senderName: d['senderName'] as String? ?? 'Anonim',
      text: d['text'] as String? ?? '',
      type: MessageType.values.firstWhere(
        (t) => t.name == d['type'],
        orElse: () => MessageType.text,
      ),
      timestamp: (d['timestamp'] as Timestamp).toDate(),
      isRead: d['isRead'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'senderName': senderName,
        'text': text,
        'type': type.name,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      };
}
