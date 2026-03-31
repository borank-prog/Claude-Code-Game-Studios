import 'package:cloud_firestore/cloud_firestore.dart';

enum RaidStatus { waiting, ready, started, completed }

class GangRaid {
  final String id;
  final String leaderId;
  final String targetId;
  final List<String> members;
  final Map<String, String> memberNames;
  final RaidStatus status;
  final DateTime createdAt;

  const GangRaid({
    required this.id,
    required this.leaderId,
    required this.targetId,
    required this.members,
    required this.memberNames,
    required this.status,
    required this.createdAt,
  });

  static const int maxMembers = 4;
  static const int minMembersToStart = 2;

  bool get isFull => members.length >= maxMembers;
  bool get canStart => members.length >= minMembersToStart;

  factory GangRaid.fromFirestore(String id, Map<String, dynamic> d) {
    final rawNames = d['memberNames'] as Map<String, dynamic>? ?? {};
    return GangRaid(
      id: id,
      leaderId: d['leaderId'] as String,
      targetId: d['targetId'] as String,
      members: List<String>.from(d['members'] ?? []),
      memberNames: rawNames.map((k, v) => MapEntry(k, v.toString())),
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
        'memberNames': memberNames,
        'status': status.name,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
