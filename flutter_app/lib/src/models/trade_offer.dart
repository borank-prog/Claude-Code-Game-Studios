import 'package:cloud_firestore/cloud_firestore.dart';

enum TradeStatus { pending, accepted, rejected, failed, cancelled }

class TradeOffer {
  final String id;
  final String fromId;
  final String fromName;
  final String toId;
  final String toName;
  final int offerCash;
  final int requestCash;
  final String? offerItemId;
  final String? requestItemId;
  final TradeStatus status;
  final DateTime createdAt;

  const TradeOffer({
    required this.id,
    required this.fromId,
    required this.fromName,
    required this.toId,
    required this.toName,
    this.offerCash = 0,
    this.requestCash = 0,
    this.offerItemId,
    this.requestItemId,
    this.status = TradeStatus.pending,
    required this.createdAt,
  });

  factory TradeOffer.fromFirestore(String id, Map<String, dynamic> d) {
    return TradeOffer(
      id: id,
      fromId: d['fromId'] as String? ?? '',
      fromName: d['fromName'] as String? ?? '',
      toId: d['toId'] as String? ?? '',
      toName: d['toName'] as String? ?? '',
      offerCash: (d['offerCash'] as num?)?.toInt() ?? 0,
      requestCash: (d['requestCash'] as num?)?.toInt() ?? 0,
      offerItemId: d['offerItemId'] as String?,
      requestItemId: d['requestItemId'] as String?,
      status: TradeStatus.values.firstWhere(
        (s) => s.name == d['status'],
        orElse: () => TradeStatus.pending,
      ),
      createdAt: d['createdAt'] is Timestamp
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'fromId': fromId,
        'fromName': fromName,
        'toId': toId,
        'toName': toName,
        'offerCash': offerCash,
        'requestCash': requestCash,
        if (offerItemId != null) 'offerItemId': offerItemId,
        if (requestItemId != null) 'requestItemId': requestItemId,
        'status': status.name,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
