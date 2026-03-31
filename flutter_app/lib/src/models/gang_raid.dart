import 'package:cloud_firestore/cloud_firestore.dart';

enum RaidStatus { waiting, ready, started, completed }

class GangRaid {
  final String id;
  final String leaderId;
  final String targetId;
  final List<String> members;
  final RaidStatus status;
  final DateTime createdAt;

  const GangRaid({
    required this.id,
    required this.leaderId,
    required this.targetId,
    required this.members,
    required this.status,
    required this.createdAt,
  });

  bool get isFull => members.length >= 4;
  bool get canStart => members.length >= 2;

  factory GangRaid.fromFirestore(String id, Map<String, dynamic> d) {
    return GangRaid(
      id: id,
      leaderId: d['leaderId'] as String,
      targetId: d['targetId'] as String,
      members: List<String>.from(d['members'] ?? []),
      status: RaidStatus.values.firstWhere(
        (s) => s.name == d['status'],
        orElse: () => RaidStatus.waiting,
      ),
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'leaderId': leaderId,
        'targetId': targetId,
        'members': members,
        'status': status.name,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
