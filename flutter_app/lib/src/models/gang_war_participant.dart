import 'package:cloud_firestore/cloud_firestore.dart';

enum GangWarSide { attacker, defender }

enum GangWarParticipantStatus { active, left, knocked, unavailable }

class GangWarParticipant {
  final String warId;
  final String uid;
  final String displayName;
  final String gangId;
  final String gangRole;
  final GangWarSide side;
  final GangWarParticipantStatus status;
  final int powerSnapshot;
  final String weaponId;
  final String armorId;
  final String knifeId;
  final String vehicleId;
  final bool ready;
  final int turnOrder;
  final DateTime joinedAt;
  final DateTime? updatedAt;

  const GangWarParticipant({
    required this.warId,
    required this.uid,
    required this.displayName,
    required this.gangId,
    required this.gangRole,
    required this.side,
    required this.status,
    required this.powerSnapshot,
    required this.weaponId,
    required this.armorId,
    required this.knifeId,
    required this.vehicleId,
    required this.ready,
    required this.turnOrder,
    required this.joinedAt,
    required this.updatedAt,
  });

  String get docId => '${warId}_$uid';

  static DateTime? _toDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }

  factory GangWarParticipant.fromFirestore(Map<String, dynamic> d) {
    return GangWarParticipant(
      warId: (d['warId'] as String? ?? '').trim(),
      uid: (d['uid'] as String? ?? '').trim(),
      displayName: (d['displayName'] as String? ?? 'Oyuncu').trim(),
      gangId: (d['gangId'] as String? ?? '').trim(),
      gangRole: (d['gangRole'] as String? ?? 'Üye').trim(),
      side: GangWarSide.values.firstWhere(
        (s) => s.name == d['side'],
        orElse: () => GangWarSide.attacker,
      ),
      status: GangWarParticipantStatus.values.firstWhere(
        (s) => s.name == d['status'],
        orElse: () => GangWarParticipantStatus.active,
      ),
      powerSnapshot: (d['powerSnapshot'] as num?)?.toInt() ?? 0,
      weaponId: (d['weaponId'] as String? ?? '').trim(),
      armorId: (d['armorId'] as String? ?? '').trim(),
      knifeId: (d['knifeId'] as String? ?? '').trim(),
      vehicleId: (d['vehicleId'] as String? ?? '').trim(),
      ready: d['ready'] == true,
      turnOrder: (d['turnOrder'] as num?)?.toInt() ?? 0,
      joinedAt: _toDateTime(d['joinedAt']) ?? DateTime.now(),
      updatedAt: _toDateTime(d['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'warId': warId,
        'uid': uid,
        'displayName': displayName,
        'gangId': gangId,
        'gangRole': gangRole,
        'side': side.name,
        'status': status.name,
        'powerSnapshot': powerSnapshot,
        'weaponId': weaponId,
        'armorId': armorId,
        'knifeId': knifeId,
        'vehicleId': vehicleId,
        'ready': ready,
        'turnOrder': turnOrder,
        'joinedAt': Timestamp.fromDate(joinedAt),
        'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      };
}
