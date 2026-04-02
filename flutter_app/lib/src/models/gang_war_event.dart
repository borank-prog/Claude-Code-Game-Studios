import 'package:cloud_firestore/cloud_firestore.dart';

class GangWarEvent {
  final String id;
  final String warId;
  final int turn;
  final String type;
  final String side;
  final String actorUid;
  final String actorName;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  const GangWarEvent({
    required this.id,
    required this.warId,
    required this.turn,
    required this.type,
    required this.side,
    required this.actorUid,
    required this.actorName,
    required this.payload,
    required this.createdAt,
  });

  static DateTime _toDateTime(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return DateTime.now();
  }

  factory GangWarEvent.fromFirestore(String id, Map<String, dynamic> d) {
    return GangWarEvent(
      id: id,
      warId: (d['warId'] as String? ?? '').trim(),
      turn: (d['turn'] as num?)?.toInt() ?? 0,
      type: (d['type'] as String? ?? 'note').trim(),
      side: (d['side'] as String? ?? '').trim(),
      actorUid: (d['actorUid'] as String? ?? '').trim(),
      actorName: (d['actorName'] as String? ?? '').trim(),
      payload: Map<String, dynamic>.from(
        d['payload'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      createdAt: _toDateTime(d['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'warId': warId,
        'turn': turn,
        'type': type,
        'side': side,
        'actorUid': actorUid,
        'actorName': actorName,
        'payload': payload,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
