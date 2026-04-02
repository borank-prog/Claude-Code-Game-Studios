import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/gang_war.dart';
import '../models/gang_war_event.dart';
import '../models/gang_war_participant.dart';
import '../models/gang_war_report.dart';

class GangWarService {
  static const int defaultParticipantLimit = 5;
  static const int defaultMinParticipants = 3;
  static const int defaultWarDurationMinutes = 30;
  static const int defaultPairCooldownMinutes = 30;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  GangWarService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance,
        _functions = FirebaseFunctions.instance;

  CollectionReference<Map<String, dynamic>> get _wars =>
      _db.collection('gang_wars');
  CollectionReference<Map<String, dynamic>> get _participants =>
      _db.collection('gang_war_participants');
  CollectionReference<Map<String, dynamic>> get _events =>
      _db.collection('gang_war_events');
  CollectionReference<Map<String, dynamic>> get _reports =>
      _db.collection('gang_war_reports');

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createWarByTargetGang({
    required String targetGangId,
  }) async {
    final cleanTargetGangId = targetGangId.trim();
    if (cleanTargetGangId.isEmpty) {
      throw Exception('Hedef kartel bulunamadı.');
    }
    try {
      final response = await _functions
          .httpsCallable('createGangWar')
          .call(<String, dynamic>{'targetGangId': cleanTargetGangId});
      return _asMap(response.data);
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Kartel savaşı başlatılamadı.');
    } catch (_) {
      throw Exception('Sunucuya ulaşılamadı, tekrar dene.');
    }
  }

  Future<Map<String, dynamic>> resolveWar({
    required String warId,
  }) async {
    final cleanWarId = warId.trim();
    if (cleanWarId.isEmpty) {
      throw Exception('Savaş bulunamadı.');
    }
    try {
      final response = await _functions
          .httpsCallable('resolveGangWar')
          .call(<String, dynamic>{'warId': cleanWarId});
      return _asMap(response.data);
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Kartel savaşı çözümlenemedi.');
    } catch (_) {
      throw Exception('Sunucuya ulaşılamadı, tekrar dene.');
    }
  }

  String participantDocId(String warId, String uid) => '${warId}_$uid';

  Future<GangWar> createWar({
    required String attackerGangId,
    required String attackerGangName,
    required String defenderGangId,
    required String defenderGangName,
    required String createdByUid,
    required String createdByName,
    required String createdByRole,
    required int creatorPowerSnapshot,
    required String weaponId,
    required String armorId,
    required String knifeId,
    required String vehicleId,
    int participantLimit = defaultParticipantLimit,
    int minParticipants = defaultMinParticipants,
    int durationMinutes = defaultWarDurationMinutes,
    int pairCooldownMinutes = defaultPairCooldownMinutes,
  }) async {
    final now = DateTime.now();
    final createdBy = createdByUid.trim();
    final attackerId = attackerGangId.trim();
    final defenderId = defenderGangId.trim();
    if (createdBy.isEmpty || attackerId.isEmpty || defenderId.isEmpty) {
      throw Exception('Eksik savaş verisi.');
    }
    if (attackerId == defenderId) {
      throw Exception('Aynı çeteye savaş açılamaz.');
    }

    final warRef = _wars.doc();
    final participant = GangWarParticipant(
      warId: warRef.id,
      uid: createdBy,
      displayName: createdByName.trim().isEmpty
          ? 'Oyuncu'
          : createdByName.trim(),
      gangId: attackerId,
      gangRole: createdByRole.trim().isEmpty ? 'Üye' : createdByRole.trim(),
      side: GangWarSide.attacker,
      status: GangWarParticipantStatus.active,
      powerSnapshot: creatorPowerSnapshot,
      weaponId: weaponId.trim(),
      armorId: armorId.trim(),
      knifeId: knifeId.trim(),
      vehicleId: vehicleId.trim(),
      ready: true,
      turnOrder: 0,
      joinedAt: now,
      updatedAt: now,
    );

    final war = GangWar(
      id: warRef.id,
      attackerGangId: attackerId,
      attackerGangName: attackerGangName.trim().isEmpty
          ? 'Saldıran Çete'
          : attackerGangName.trim(),
      defenderGangId: defenderId,
      defenderGangName: defenderGangName.trim().isEmpty
          ? 'Savunan Çete'
          : defenderGangName.trim(),
      createdByUid: createdBy,
      createdByRole: createdByRole.trim().isEmpty ? 'Lider' : createdByRole,
      participantLimit: participantLimit,
      minParticipants: minParticipants,
      attackerCount: 1,
      defenderCount: 0,
      attackerPowerSnapshot: creatorPowerSnapshot,
      defenderPowerSnapshot: 0,
      durationMinutes: durationMinutes,
      pairCooldownUntilEpoch:
          now.add(Duration(minutes: pairCooldownMinutes)).millisecondsSinceEpoch ~/
              1000,
      status: GangWarStatus.recruiting,
      result: GangWarResult.pending,
      winnerGangId: '',
      createdAt: now,
      startsAt: null,
      endsAt: null,
      resolvedAt: null,
      version: 1,
    );

    final batch = _db.batch();
    batch.set(warRef, war.toMap());
    batch.set(_participants.doc(participant.docId), participant.toMap());
    batch.set(_events.doc(), {
      'warId': war.id,
      'turn': 0,
      'type': 'war_created',
      'side': GangWarSide.attacker.name,
      'actorUid': createdBy,
      'actorName': participant.displayName,
      'payload': {
        'attackerGangId': attackerId,
        'defenderGangId': defenderId,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit().timeout(const Duration(seconds: 8));
    return war;
  }

  Future<void> joinWar({
    required String warId,
    required String uid,
    required String displayName,
    required String gangId,
    required String gangRole,
    required GangWarSide side,
    required int powerSnapshot,
    required String weaponId,
    required String armorId,
    required String knifeId,
    required String vehicleId,
  }) async {
    final cleanWarId = warId.trim();
    final cleanUid = uid.trim();
    final cleanGangId = gangId.trim();
    if (cleanWarId.isEmpty || cleanUid.isEmpty || cleanGangId.isEmpty) {
      throw Exception('Geçersiz katılım verisi.');
    }

    final warRef = _wars.doc(cleanWarId);
    final participantRef = _participants.doc(participantDocId(cleanWarId, cleanUid));
    await _db.runTransaction((tx) async {
      final warSnap = await tx.get(warRef);
      if (!warSnap.exists) {
        throw Exception('Savaş bulunamadı.');
      }
      final war = GangWar.fromFirestore(warSnap.id, warSnap.data()!);
      if (war.isFinished || war.status == GangWarStatus.active) {
        throw Exception('Bu savaşa artık katılamazsın.');
      }

      final expectedGangId = side == GangWarSide.attacker
          ? war.attackerGangId
          : war.defenderGangId;
      if (cleanGangId != expectedGangId) {
        throw Exception('Yanlış taraf için katılım isteği.');
      }

      final existing = await tx.get(participantRef);
      if (existing.exists) {
        tx.update(participantRef, {
          'status': GangWarParticipantStatus.active.name,
          'ready': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final participant = GangWarParticipant(
          warId: cleanWarId,
          uid: cleanUid,
          displayName: displayName.trim().isEmpty ? 'Oyuncu' : displayName.trim(),
          gangId: cleanGangId,
          gangRole: gangRole.trim().isEmpty ? 'Üye' : gangRole.trim(),
          side: side,
          status: GangWarParticipantStatus.active,
          powerSnapshot: powerSnapshot,
          weaponId: weaponId.trim(),
          armorId: armorId.trim(),
          knifeId: knifeId.trim(),
          vehicleId: vehicleId.trim(),
          ready: true,
          turnOrder: 0,
          joinedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        tx.set(participantRef, participant.toMap());
      }

      final nextAttackerCount = side == GangWarSide.attacker
          ? (war.attackerCount + 1).clamp(0, war.participantLimit)
          : war.attackerCount;
      final nextDefenderCount = side == GangWarSide.defender
          ? (war.defenderCount + 1).clamp(0, war.participantLimit)
          : war.defenderCount;
      final nextStatus = (nextAttackerCount >= war.minParticipants &&
              nextDefenderCount >= war.minParticipants)
          ? GangWarStatus.ready
          : GangWarStatus.recruiting;

      tx.update(warRef, {
        'attackerCount': nextAttackerCount,
        'defenderCount': nextDefenderCount,
        'status': nextStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }).timeout(const Duration(seconds: 10));
  }

  Future<void> leaveWar({
    required String warId,
    required String uid,
  }) async {
    final cleanWarId = warId.trim();
    final cleanUid = uid.trim();
    if (cleanWarId.isEmpty || cleanUid.isEmpty) return;

    final participantRef = _participants.doc(participantDocId(cleanWarId, cleanUid));
    await participantRef.update({
      'status': GangWarParticipantStatus.left.name,
      'ready': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }).timeout(const Duration(seconds: 8));
  }

  Future<void> markWarStarted({
    required String warId,
    required int attackerPowerSnapshot,
    required int defenderPowerSnapshot,
    int durationMinutes = defaultWarDurationMinutes,
  }) async {
    final now = DateTime.now();
    await _wars.doc(warId).update({
      'status': GangWarStatus.active.name,
      'startsAt': Timestamp.fromDate(now),
      'endsAt': Timestamp.fromDate(now.add(Duration(minutes: durationMinutes))),
      'attackerPowerSnapshot': attackerPowerSnapshot,
      'defenderPowerSnapshot': defenderPowerSnapshot,
      'updatedAt': FieldValue.serverTimestamp(),
    }).timeout(const Duration(seconds: 8));
  }

  Future<void> markWarResolved({
    required String warId,
    required GangWarResult result,
    required String winnerGangId,
  }) async {
    await _wars.doc(warId).update({
      'status': GangWarStatus.resolved.name,
      'result': result.name,
      'winnerGangId': winnerGangId.trim(),
      'resolvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }).timeout(const Duration(seconds: 8));
  }

  Future<void> appendEvent(GangWarEvent event) async {
    await _events.add({
      ...event.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    }).timeout(const Duration(seconds: 8));
  }

  Future<void> createReport(GangWarReport report) async {
    await _reports.add(report.toMap()).timeout(const Duration(seconds: 8));
  }

  Stream<GangWar?> watchWar(String warId) {
    return _wars.doc(warId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return GangWar.fromFirestore(snap.id, snap.data()!);
    });
  }

  Stream<List<GangWarParticipant>> watchParticipants(String warId) {
    return _participants
        .where('warId', isEqualTo: warId)
        .where('status', isEqualTo: GangWarParticipantStatus.active.name)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => GangWarParticipant.fromFirestore(d.data()))
              .toList(growable: false),
        );
  }

  Future<List<GangWar>> fetchRecentWarsForGang({
    required String gangId,
    int limit = 20,
  }) async {
    final cleanGangId = gangId.trim();
    if (cleanGangId.isEmpty) return const <GangWar>[];

    final attackerSnap = await _wars
        .where('attackerGangId', isEqualTo: cleanGangId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get()
        .timeout(const Duration(seconds: 8));
    final defenderSnap = await _wars
        .where('defenderGangId', isEqualTo: cleanGangId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get()
        .timeout(const Duration(seconds: 8));

    final byId = <String, GangWar>{};
    for (final d in attackerSnap.docs) {
      byId[d.id] = GangWar.fromFirestore(d.id, d.data());
    }
    for (final d in defenderSnap.docs) {
      byId[d.id] = GangWar.fromFirestore(d.id, d.data());
    }
    final list = byId.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.take(limit).toList(growable: false);
  }

  Stream<List<GangWarReport>> watchMyReports({
    required String uid,
    int limit = 20,
  }) {
    final cleanUid = uid.trim();
    if (cleanUid.isEmpty) return const Stream<List<GangWarReport>>.empty();
    return _reports
        .where('viewerUid', isEqualTo: cleanUid)
        .limit(limit)
        .snapshots()
        .map((snap) {
          final rows = snap.docs
              .map((d) => GangWarReport.fromFirestore(d.id, d.data()))
              .toList(growable: true);
          rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return rows;
        });
  }
}
