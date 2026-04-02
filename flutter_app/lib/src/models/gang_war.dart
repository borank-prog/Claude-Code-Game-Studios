import 'package:cloud_firestore/cloud_firestore.dart';

enum GangWarStatus { recruiting, ready, active, resolved, cancelled }

enum GangWarResult { pending, attackerWin, defenderWin, draw }

class GangWar {
  final String id;
  final String attackerGangId;
  final String attackerGangName;
  final String defenderGangId;
  final String defenderGangName;
  final String createdByUid;
  final String createdByRole;
  final int participantLimit;
  final int minParticipants;
  final int attackerCount;
  final int defenderCount;
  final int attackerPowerSnapshot;
  final int defenderPowerSnapshot;
  final int durationMinutes;
  final int pairCooldownUntilEpoch;
  final GangWarStatus status;
  final GangWarResult result;
  final String winnerGangId;
  final DateTime createdAt;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? resolvedAt;
  final int version;

  const GangWar({
    required this.id,
    required this.attackerGangId,
    required this.attackerGangName,
    required this.defenderGangId,
    required this.defenderGangName,
    required this.createdByUid,
    required this.createdByRole,
    required this.participantLimit,
    required this.minParticipants,
    required this.attackerCount,
    required this.defenderCount,
    required this.attackerPowerSnapshot,
    required this.defenderPowerSnapshot,
    required this.durationMinutes,
    required this.pairCooldownUntilEpoch,
    required this.status,
    required this.result,
    required this.winnerGangId,
    required this.createdAt,
    required this.startsAt,
    required this.endsAt,
    required this.resolvedAt,
    required this.version,
  });

  bool get canStart =>
      attackerCount >= minParticipants &&
      defenderCount >= minParticipants &&
      (status == GangWarStatus.recruiting || status == GangWarStatus.ready);

  bool get isFinished =>
      status == GangWarStatus.resolved || status == GangWarStatus.cancelled;

  static DateTime? _toDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }

  factory GangWar.fromFirestore(String id, Map<String, dynamic> d) {
    return GangWar(
      id: id,
      attackerGangId: (d['attackerGangId'] as String? ?? '').trim(),
      attackerGangName: (d['attackerGangName'] as String? ?? '').trim(),
      defenderGangId: (d['defenderGangId'] as String? ?? '').trim(),
      defenderGangName: (d['defenderGangName'] as String? ?? '').trim(),
      createdByUid: (d['createdByUid'] as String? ?? '').trim(),
      createdByRole: (d['createdByRole'] as String? ?? 'Lider').trim(),
      participantLimit: (d['participantLimit'] as num?)?.toInt() ?? 5,
      minParticipants: (d['minParticipants'] as num?)?.toInt() ?? 3,
      attackerCount: (d['attackerCount'] as num?)?.toInt() ?? 0,
      defenderCount: (d['defenderCount'] as num?)?.toInt() ?? 0,
      attackerPowerSnapshot:
          (d['attackerPowerSnapshot'] as num?)?.toInt() ?? 0,
      defenderPowerSnapshot:
          (d['defenderPowerSnapshot'] as num?)?.toInt() ?? 0,
      durationMinutes: (d['durationMinutes'] as num?)?.toInt() ?? 30,
      pairCooldownUntilEpoch:
          (d['pairCooldownUntilEpoch'] as num?)?.toInt() ?? 0,
      status: GangWarStatus.values.firstWhere(
        (s) => s.name == d['status'],
        orElse: () => GangWarStatus.recruiting,
      ),
      result: GangWarResult.values.firstWhere(
        (r) => r.name == d['result'],
        orElse: () => GangWarResult.pending,
      ),
      winnerGangId: (d['winnerGangId'] as String? ?? '').trim(),
      createdAt: _toDateTime(d['createdAt']) ?? DateTime.now(),
      startsAt: _toDateTime(d['startsAt']),
      endsAt: _toDateTime(d['endsAt']),
      resolvedAt: _toDateTime(d['resolvedAt']),
      version: (d['version'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() => {
        'attackerGangId': attackerGangId,
        'attackerGangName': attackerGangName,
        'defenderGangId': defenderGangId,
        'defenderGangName': defenderGangName,
        'createdByUid': createdByUid,
        'createdByRole': createdByRole,
        'participantLimit': participantLimit,
        'minParticipants': minParticipants,
        'attackerCount': attackerCount,
        'defenderCount': defenderCount,
        'attackerPowerSnapshot': attackerPowerSnapshot,
        'defenderPowerSnapshot': defenderPowerSnapshot,
        'durationMinutes': durationMinutes,
        'pairCooldownUntilEpoch': pairCooldownUntilEpoch,
        'status': status.name,
        'result': result.name,
        'winnerGangId': winnerGangId,
        'createdAt': Timestamp.fromDate(createdAt),
        'startsAt': startsAt == null ? null : Timestamp.fromDate(startsAt!),
        'endsAt': endsAt == null ? null : Timestamp.fromDate(endsAt!),
        'resolvedAt':
            resolvedAt == null ? null : Timestamp.fromDate(resolvedAt!),
        'version': version,
      };
}
