import 'package:cloud_firestore/cloud_firestore.dart';

import 'gang_war.dart';

class GangWarReport {
  final String id;
  final String warId;
  final String viewerUid;
  final String gangId;
  final GangWarResult result;
  final String title;
  final String summary;
  final int attackerScore;
  final int defenderScore;
  final int cashDelta;
  final int xpDelta;
  final DateTime createdAt;

  const GangWarReport({
    required this.id,
    required this.warId,
    required this.viewerUid,
    required this.gangId,
    required this.result,
    required this.title,
    required this.summary,
    required this.attackerScore,
    required this.defenderScore,
    required this.cashDelta,
    required this.xpDelta,
    required this.createdAt,
  });

  static DateTime _toDateTime(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return DateTime.now();
  }

  factory GangWarReport.fromFirestore(String id, Map<String, dynamic> d) {
    return GangWarReport(
      id: id,
      warId: (d['warId'] as String? ?? '').trim(),
      viewerUid: (d['viewerUid'] as String? ?? '').trim(),
      gangId: (d['gangId'] as String? ?? '').trim(),
      result: GangWarResult.values.firstWhere(
        (r) => r.name == d['result'],
        orElse: () => GangWarResult.pending,
      ),
      title: (d['title'] as String? ?? '').trim(),
      summary: (d['summary'] as String? ?? '').trim(),
      attackerScore: (d['attackerScore'] as num?)?.toInt() ?? 0,
      defenderScore: (d['defenderScore'] as num?)?.toInt() ?? 0,
      cashDelta: (d['cashDelta'] as num?)?.toInt() ?? 0,
      xpDelta: (d['xpDelta'] as num?)?.toInt() ?? 0,
      createdAt: _toDateTime(d['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'warId': warId,
        'viewerUid': viewerUid,
        'gangId': gangId,
        'result': result.name,
        'title': title,
        'summary': summary,
        'attackerScore': attackerScore,
        'defenderScore': defenderScore,
        'cashDelta': cashDelta,
        'xpDelta': xpDelta,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
