import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config/firebase_bootstrap.dart';

class OnlineService {
  static const Duration _firestoreOpTimeout = Duration(seconds: 5);

  bool _initialized = false;
  bool _googleInitialized = false;
  String initError = '';

  bool get canUseGoogleSignIn => _initialized && !kIsWeb;

  bool get isInitialized => _initialized;
  User? get currentUser {
    if (!_initialized) return null;
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      await Firebase.initializeApp();
      if (kIsWeb) {
        try {
          await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
        } catch (_) {}
      }
      _initialized = true;
      initError = '';
      return true;
    } catch (e) {
      // google-services.json / firebase_options.dart yoksa manuel fallback dene.
      try {
        await Firebase.initializeApp(options: FirebaseBootstrap.currentOptions);
        if (kIsWeb) {
          try {
            await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
          } catch (_) {}
        }
        _initialized = true;
        initError = '';
        return true;
      } catch (fallbackError) {
        _initialized = false;
        final raw = fallbackError.toString();
        final lower = raw.toLowerCase();
        if (kIsWeb &&
            (!FirebaseBootstrap.hasWebRuntimeConfig ||
                lower.contains('web firebase ayari eksik'))) {
          initError =
              'Web Firebase ayarı eksik. FIREBASE_WEB_APP_ID ve FIREBASE_WEB_API_KEY değerlerini geçerek tekrar başlat.';
          return false;
        }
        if ((lower.contains('firebaseoptions') && lower.contains('resource')) ||
            lower.contains('default firebaseapp failed to initialize') ||
            lower.contains('no firebase app') ||
            lower.contains('no-app')) {
          initError =
              'Firebase yapılandırması eksik. Lütfen Firebase ayarlarını tamamla.';
        } else {
          final first = raw.split('\n').first.trim();
          initError = first.length > 140
              ? '${first.substring(0, 140)}...'
              : first;
        }
        return false;
      }
    }
  }

  Future<UserCredential> signInEmail(String email, String password) async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) {
        throw Exception(
          initError.isNotEmpty
              ? initError
              : 'Firebase başlatılamadı. Lütfen tekrar dene.',
        );
      }
    }
    final normalizedEmail = _normalizeEmail(email);
    final candidates = _passwordCandidates(password);
    FirebaseAuthException? lastAuthError;
    Object? lastError;

    for (final pass in candidates) {
      try {
        return await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: normalizedEmail,
          password: pass,
        );
      } on FirebaseAuthException catch (e) {
        debugPrint('[EmailLogin] code=${e.code} message=${e.message}');
        lastAuthError = e;
        lastError = e;
        // Konfigürasyon/ağ hatalarında tekrar denemek anlamsız.
        if (!_isRetryableCredentialError(e.code)) {
          rethrow;
        }
      } catch (e) {
        lastError = e;
        rethrow;
      }
    }

    if (lastAuthError != null) {
      throw lastAuthError;
    }
    throw Exception(lastError?.toString() ?? 'E-posta girişi başarısız.');
  }

  Future<UserCredential> signUpEmail(String email, String password) async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) {
        throw Exception(
          initError.isNotEmpty
              ? initError
              : 'Firebase başlatılamadı. Lütfen tekrar dene.',
        );
      }
    }
    final normalizedEmail = _normalizeEmail(email);
    final normalizedPassword = _normalizePasswordForCreate(password);
    try {
      return await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: normalizedPassword,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('[EmailRegister] code=${e.code} message=${e.message}');
      rethrow;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) {
        throw Exception(
          initError.isNotEmpty
              ? initError
              : 'Firebase başlatılamadı. Lütfen tekrar dene.',
        );
      }
    }
    final normalizedEmail = _normalizeEmail(email);
    await FirebaseAuth.instance.sendPasswordResetEmail(email: normalizedEmail);
  }

  String _normalizeEmail(String value) {
    return value.trim().toLowerCase();
  }

  String _normalizePasswordForCreate(String value) {
    final trimmed = value.trim();
    if (trimmed.length >= 6) {
      return trimmed;
    }
    return value;
  }

  List<String> _passwordCandidates(String raw) {
    final out = <String>[];
    if (raw.isNotEmpty) {
      out.add(raw);
    }
    final trimmed = raw.trim();
    if (trimmed.isNotEmpty && !out.contains(trimmed)) {
      out.add(trimmed);
    }
    if (out.isEmpty) {
      out.add(raw);
    }
    return out;
  }

  bool _isRetryableCredentialError(String code) {
    return code == 'invalid-credential' ||
        code == 'wrong-password' ||
        code == 'user-not-found' ||
        code == 'invalid-login-credentials';
  }

  Future<UserCredential?> signInGoogle() async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) {
        throw Exception(
          'Firebase başlatılamadı. Google girişi için önce Firebase bağlantısını düzelt.',
        );
      }
    }

    // Bu projede Google girişi sadece mobilde aktiftir.
    if (kIsWeb) {
      throw Exception('Google girişi sadece mobilde aktif.');
    }

    // Android/iOS için en stabil yol: google_sign_in plugin + Firebase credential.
    await _ensureGoogleInitialized();
    try {
      final GoogleSignInAccount account = await GoogleSignIn.instance
          .authenticate()
          .timeout(const Duration(seconds: 25));
      final GoogleSignInAuthentication auth = account.authentication;
      final credential = GoogleAuthProvider.credential(idToken: auth.idToken);
      if ((auth.idToken ?? '').isEmpty) {
        throw Exception(
          'Google kimlik bilgisi alınamadı. Google hesabını kaldırıp yeniden ekleyip tekrar dene.',
        );
      }
      return FirebaseAuth.instance
          .signInWithCredential(credential)
          .timeout(const Duration(seconds: 25));
    } catch (e) {
      debugPrint('[GoogleLogin] signIn error => $e');
      throw _mapGoogleError(e);
    }
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    final serverClientId = FirebaseBootstrap.googleServerClientId.trim();
    if (serverClientId.isNotEmpty) {
      await GoogleSignIn.instance.initialize(serverClientId: serverClientId);
    } else {
      await GoogleSignIn.instance.initialize();
    }
    _googleInitialized = true;
  }

  Exception _mapGoogleError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'operation-not-allowed':
          return Exception(
            'Firebase Console’da Google sağlayıcısı kapalı. Authentication > Sign-in method > Google bölümünü aç.',
          );
        case 'invalid-credential':
        case 'invalid-oauth-client-id':
          return Exception(
            'Google OAuth kimliği geçersiz. SHA-1/SHA-256 ve OAuth istemcini kontrol et.',
          );
        case 'network-request-failed':
          return Exception('Ağ hatası. İnterneti kontrol edip tekrar dene.');
      }
    }

    final raw = e.toString();
    final low = raw.toLowerCase();
    if (low.contains('developer_error') ||
        low.contains('api: 10') ||
        low.contains('status code: 10') ||
        low.contains('12500')) {
      return Exception(
        'Google giriş yapılandırması eksik (SHA-1/OAuth). Firebase ayarlarını kontrol et.',
      );
    }
    if (low.contains('invalid_app_id')) {
      return Exception(
        'Firebase App ID geçersiz. Bu proje için doğru google-services.json / firebase_options.dart eklenmeli.',
      );
    }
    if (low.contains('network_error') || low.contains('network')) {
      return Exception('Ağ hatası. İnterneti kontrol edip tekrar dene.');
    }
    if (low.contains('connection failed: 8') || low.contains('status 8')) {
      return Exception(
        'Google servisine bağlanılamadı. Kısa süre sonra tekrar dene.',
      );
    }
    if (low.contains('canceled') || low.contains('cancelled')) {
      return Exception('Google girişi iptal edildi.');
    }
    if (low.contains('timeout')) {
      return Exception(
        'Google giriş zaman aşımına uğradı. Bağlantıyı kontrol edip tekrar dene.',
      );
    }
    if (low.contains('serverclientid')) {
      return Exception(
        'Google giriş yapılandırması eksik (Web client ID/serverClientId).',
      );
    }
    return Exception(raw);
  }

  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut().timeout(const Duration(seconds: 4));
    } catch (_) {}
    try {
      await GoogleSignIn.instance.signOut().timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  Future<void> upsertUserProfile({
    required String uid,
    required String displayName,
    required int power,
    required int level,
    required int rank,
    int? cash,
    int? gold,
    int? xp,
    int? wins,
    int? gangWins,
    int? lastLoginEpoch,
    int? currentTp,
    int? maxTp,
    int? currentEnergy,
    int? maxEnergy,
    int? shieldUntilEpoch,
    int? vipShieldLastUseDayKey,
    String? status,
    int? statusUntilEpoch,
    int? attackEnergyCost,
    bool online = true,
    String? gangId,
    String? gangName,
    String? avatarId,
    String? equippedWeaponId,
    String? equippedKnifeId,
    String? equippedArmorId,
    String? equippedVehicleId,
    String? combatWeaponId,
  }) async {
    final payload = <String, dynamic>{
      'uid': uid,
      'name': displayName,
      'displayName': displayName,
      'power': power,
      'level': level,
      'rank': rank,
      'cash': cash ?? 0,
      'gold': gold ?? 0,
      'xp': xp ?? 0,
      'wins': wins ?? 0,
      'gangWins': gangWins ?? 0,
      if (lastLoginEpoch != null && lastLoginEpoch > 0)
        'lastLoginEpoch': lastLoginEpoch,
      'currentTp': currentTp ?? 0,
      'maxTp': maxTp ?? 0,
      'currentEnergy': currentEnergy ?? 0,
      'maxEnergy': maxEnergy ?? 0,
      'attackEnergyCost': attackEnergyCost ?? 20,
      'shieldUntilEpoch': shieldUntilEpoch ?? 0,
      'vipShieldLastUseDayKey': vipShieldLastUseDayKey ?? 0,
      'status': (status ?? 'active').trim().isEmpty ? 'active' : status,
      'statusUntilEpoch': statusUntilEpoch ?? 0,
      'avatarId': avatarId ?? '',
      'equippedWeaponId': equippedWeaponId ?? '',
      'equippedKnifeId': equippedKnifeId ?? '',
      'equippedArmorId': equippedArmorId ?? '',
      'equippedVehicleId': equippedVehicleId ?? '',
      'combatWeaponId': combatWeaponId ?? '',
      'online': online,
    };
    if (gangId != null) {
      payload['gangId'] = gangId;
    }
    if (gangName != null) {
      payload['gangName'] = gangName;
    }
    await FirebaseFunctions.instance
        .httpsCallable('secureSyncProfile')
        .call(payload)
        .timeout(_firestoreOpTimeout);
  }

  Future<Map<String, dynamic>> secureSkipPenalty({
    required String penalty,
    required int cost,
  }) async {
    final res = await FirebaseFunctions.instance
        .httpsCallable('secureSkipPenalty')
        .call({'penalty': penalty, 'cost': cost})
        .timeout(_firestoreOpTimeout);
    final raw = res.data;
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>?> fetchUserProfile(String uid) async {
    if (uid.trim().isEmpty) return null;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get()
        .timeout(_firestoreOpTimeout);
    if (!snap.exists) return null;
    return snap.data();
  }

  Future<Map<String, String>?> findGangByMember(String uid) async {
    final cleanUid = uid.trim();
    if (cleanUid.isEmpty) return null;

    final memberSnap = await FirebaseFirestore.instance
        .collectionGroup('members')
        .where('uid', isEqualTo: cleanUid)
        .limit(1)
        .get()
        .timeout(_firestoreOpTimeout);
    if (memberSnap.docs.isEmpty) return null;

    final memberDoc = memberSnap.docs.first;
    final gangRef = memberDoc.reference.parent.parent;
    if (gangRef == null) return null;

    final gangSnap = await gangRef.get().timeout(_firestoreOpTimeout);
    if (!gangSnap.exists) return null;

    final gangData = gangSnap.data() ?? <String, dynamic>{};
    final memberData = memberDoc.data();
    return {
      'gangId': gangRef.id,
      'gangName': (gangData['name'] as String? ?? '').trim(),
      'gangRole': (memberData['role'] as String? ?? 'Üye').trim(),
    };
  }

  Future<void> upsertCloudSave({
    required String uid,
    required Map<String, dynamic> payload,
    required int clientUpdatedAtEpoch,
  }) async {
    if (uid.trim().isEmpty) return;
    final doc = FirebaseFirestore.instance.collection('user_saves').doc(uid);
    await doc
        .set({
          'uid': uid,
          'clientUpdatedAtEpoch': clientUpdatedAtEpoch,
          'payload': payload,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true))
        .timeout(_firestoreOpTimeout);
  }

  Future<Map<String, dynamic>?> fetchCloudSave(String uid) async {
    if (uid.trim().isEmpty) return null;
    final snap = await FirebaseFirestore.instance
        .collection('user_saves')
        .doc(uid)
        .get()
        .timeout(_firestoreOpTimeout);
    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null || data.isEmpty) return null;
    return data;
  }

  Future<void> writePendingEvents(
    String uid,
    List<Map<String, dynamic>> events,
  ) async {
    if (events.isEmpty) return;
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('event_queue');

    final batch = FirebaseFirestore.instance.batch();
    for (final evt in events) {
      final id = (evt['id'] as String?) ?? '';
      if (id.isEmpty) continue;
      batch.set(col.doc(id), {
        ...evt,
        'serverTs': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit().timeout(_firestoreOpTimeout);
  }

  Future<List<Map<String, dynamic>>> fetchLeaderboard({int limit = 20}) async {
    final col = FirebaseFirestore.instance.collection('users');
    final byUid = <String, Map<String, dynamic>>{};

    void absorb(QuerySnapshot<Map<String, dynamic>> snap) {
      for (final doc in snap.docs) {
        final data = doc.data();
        final uid = doc.id.trim();
        if (uid.isEmpty) continue;
        byUid[uid] = {
          'uid': uid,
          'name': (data['name'] ?? data['displayName'] ?? 'Oyuncu').toString(),
          'displayName': (data['displayName'] ?? data['name'] ?? 'Oyuncu')
              .toString(),
          'level': (data['level'] as num?)?.toInt() ?? 1,
          'power': (data['power'] as num?)?.toInt() ?? 0,
          'cash': (data['cash'] as num?)?.toInt() ?? 0,
          'wins': (data['wins'] as num?)?.toInt() ?? 0,
          'gangWins': (data['gangWins'] as num?)?.toInt() ?? 0,
          'gangName': data['gangName'],
          'online': data['online'] == true,
          'status': (data['status'] ?? 'active').toString(),
          'statusUntilEpoch': (data['statusUntilEpoch'] as num?)?.toInt() ?? 0,
          'shieldUntilEpoch': (data['shieldUntilEpoch'] as num?)?.toInt() ?? 0,
          'currentTp': (data['currentTp'] as num?)?.toInt() ?? 100,
        };
      }
    }

    try {
      final ranked = await col
          .orderBy('power', descending: true)
          .limit(limit < 100 ? 100 : limit)
          .get()
          .timeout(_firestoreOpTimeout);
      absorb(ranked);
    } catch (_) {
      // Missing index/field scenario — fallback queries below.
    }

    if (byUid.length < limit) {
      try {
        final active = await col
            .orderBy('updatedAt', descending: true)
            .limit(limit < 120 ? 120 : (limit * 2))
            .get()
            .timeout(_firestoreOpTimeout);
        absorb(active);
      } catch (_) {}
    }

    if (byUid.length < limit) {
      try {
        final any = await col
            .limit(limit < 200 ? 200 : (limit * 3))
            .get()
            .timeout(_firestoreOpTimeout);
        absorb(any);
      } catch (_) {}
    }

    final rows = byUid.values.toList();
    rows.sort((a, b) {
      final scoreCompare = _leaderboardScore(b).compareTo(_leaderboardScore(a));
      if (scoreCompare != 0) return scoreCompare;
      final powerA = (a['power'] as num?)?.toInt() ?? 0;
      final powerB = (b['power'] as num?)?.toInt() ?? 0;
      final powerCompare = powerB.compareTo(powerA);
      if (powerCompare != 0) return powerCompare;
      final winsA = (a['wins'] as num?)?.toInt() ?? 0;
      final winsB = (b['wins'] as num?)?.toInt() ?? 0;
      return winsB.compareTo(winsA);
    });
    return rows.take(limit).toList(growable: false);
  }

  int _leaderboardScore(Map<String, dynamic> row) {
    final power = (row['power'] as num?)?.toInt() ?? 0;
    final cash = (row['cash'] as num?)?.toInt() ?? 0;
    final wins = (row['wins'] as num?)?.toInt() ?? 0;
    final gangWins = (row['gangWins'] as num?)?.toInt() ?? 0;
    return (power * 12) + (wins * 900) + (gangWins * 1200) + (cash ~/ 2000);
  }

  Future<List<Map<String, dynamic>>> fetchFriends(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('friends')
        .orderBy('displayName')
        .get()
        .timeout(_firestoreOpTimeout);
    final seenUids = <String>{};
    final seenNames = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final d in snap.docs) {
      final data = d.data();
      final friendUid = (data['uid'] as String?)?.trim() ?? d.id;
      final name = (data['displayName'] as String?)?.trim() ?? '';
      if (seenUids.add(friendUid) && (name.isEmpty || seenNames.add(name))) {
        result.add(data);
      }
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> fetchIncomingRequests(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('friend_requests')
        .where('toId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .get()
        .timeout(_firestoreOpTimeout);
    return snap.docs
        .map((d) => {'id': d.id, ...d.data()})
        .toList(growable: false);
  }

  Future<void> sendFriendRequest({
    required String fromId,
    required String fromName,
    required String toId,
  }) async {
    final reqId = '${fromId}_$toId';
    await FirebaseFirestore.instance
        .collection('friend_requests')
        .doc(reqId)
        .set({
          'fromId': fromId,
          'fromName': fromName,
          'toId': toId,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> acceptFriendRequest({
    required String myUid,
    required String requestId,
  }) async {
    final reqRef = FirebaseFirestore.instance
        .collection('friend_requests')
        .doc(requestId);
    final reqSnap = await reqRef.get();
    if (!reqSnap.exists) return;
    final data = reqSnap.data()!;
    final fromId = data['fromId'] as String? ?? '';
    final fromName = data['fromName'] as String? ?? 'Oyuncu';
    final toId = data['toId'] as String? ?? '';
    if (toId != myUid || fromId.isEmpty) return;

    final myDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(myUid)
        .get();
    final myName = myDoc.data()?['displayName'] as String? ?? 'Oyuncu';

    final batch = FirebaseFirestore.instance.batch();
    batch.set(
      FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .collection('friends')
          .doc(fromId),
      {
        'uid': fromId,
        'displayName': fromName,
        'addedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(
      FirebaseFirestore.instance
          .collection('users')
          .doc(fromId)
          .collection('friends')
          .doc(myUid),
      {
        'uid': myUid,
        'displayName': myName,
        'addedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.update(reqRef, {
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> rejectFriendRequest(String requestId) async {
    await FirebaseFirestore.instance
        .collection('friend_requests')
        .doc(requestId)
        .update({
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> sendInboxDirectMessage({
    required String toUid,
    required String text,
  }) async {
    final targetUid = toUid.trim();
    final body = text.trim();
    if (targetUid.isEmpty || body.isEmpty) {
      throw Exception('Geçerli bir mesaj ve alıcı gerekli.');
    }
    await FirebaseFunctions.instance
        .httpsCallable('sendInboxDirectMessage')
        .call({'toUid': targetUid, 'text': body})
        .timeout(_firestoreOpTimeout);
  }

  Future<void> removeFriend({
    required String myUid,
    required String friendUid,
  }) async {
    final cleanMyUid = myUid.trim();
    final cleanFriendUid = friendUid.trim();
    if (cleanMyUid.isEmpty || cleanFriendUid.isEmpty) return;
    if (cleanMyUid == cleanFriendUid) return;

    final batch = FirebaseFirestore.instance.batch();
    batch.delete(
      FirebaseFirestore.instance
          .collection('users')
          .doc(cleanMyUid)
          .collection('friends')
          .doc(cleanFriendUid),
    );
    batch.delete(
      FirebaseFirestore.instance
          .collection('users')
          .doc(cleanFriendUid)
          .collection('friends')
          .doc(cleanMyUid),
    );
    await batch.commit();
  }

  Future<Map<String, dynamic>> createGang({
    required String ownerUid,
    required String ownerName,
    required String gangName,
    required int ownerPower,
  }) async {
    final cleanOwnerUid = ownerUid.trim();
    final cleanOwnerName = ownerName.trim().isEmpty
        ? 'Oyuncu'
        : ownerName.trim();
    final cleanGangName = gangName.trim();
    if (cleanOwnerUid.isEmpty || cleanGangName.isEmpty) {
      throw Exception('Geçerli bir çete adı gerekli.');
    }

    final gangs = FirebaseFirestore.instance.collection('gangs');
    final gangRef = gangs.doc();
    final membersRef = gangRef.collection('members').doc(cleanOwnerUid);
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(cleanOwnerUid);
    final ownerProfileSeed = <String, dynamic>{
      'uid': cleanOwnerUid,
      'name': cleanOwnerName,
      'displayName': cleanOwnerName,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Legacy/stale saves may carry a gangId while the gang doc no longer exists.
    // Auto-clean that mismatch to avoid false "already in gang" blocks.
    final userSnap = await userRef.get().timeout(_firestoreOpTimeout);
    final existingGangId = (userSnap.data()?['gangId'] as String? ?? '').trim();
    if (existingGangId.isNotEmpty) {
      final existingGangSnap = await FirebaseFirestore.instance
          .collection('gangs')
          .doc(existingGangId)
          .get()
          .timeout(_firestoreOpTimeout);
      if (existingGangSnap.exists) {
        throw Exception('Zaten bir çetedesin.');
      }
      await userRef
          .set({
            ...ownerProfileSeed,
            'gangId': '',
            'gangName': '',
            'gangRole': '',
          }, SetOptions(merge: true))
          .timeout(_firestoreOpTimeout);
    }

    // Kullanıcı belgesi boş görünse bile aktif bir çete üyeliği varsa yeniden çete kurdurma.
    final recoveredGang = await findGangByMember(cleanOwnerUid);
    if (recoveredGang != null && (recoveredGang['gangId'] ?? '').isNotEmpty) {
      await userRef
          .set({
            ...ownerProfileSeed,
            'gangId': recoveredGang['gangId'],
            'gangName': recoveredGang['gangName'] ?? '',
            'gangRole': recoveredGang['gangRole'] ?? 'Üye',
          }, SetOptions(merge: true))
          .timeout(_firestoreOpTimeout);
      throw Exception('Zaten bir çetedesin.');
    }

    await FirebaseFirestore.instance
        .runTransaction((tx) async {
          final latestUserSnap = await tx.get(userRef);
          final latestGangId =
              (latestUserSnap.data()?['gangId'] as String? ?? '').trim();
          if (latestGangId.isNotEmpty) {
            throw Exception('Zaten bir çetedesin.');
          }

          tx.set(gangRef, {
            'id': gangRef.id,
            'name': cleanGangName,
            'ownerId': cleanOwnerUid,
            'ownerName': cleanOwnerName,
            'inviteOnly': false,
            'acceptJoinRequests': true,
            'gangRank': 1,
            'respectPoints': 0,
            'vault': 0,
            'memberCount': 1,
            'totalPower': ownerPower,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          tx.set(membersRef, {
            'uid': cleanOwnerUid,
            'displayName': cleanOwnerName,
            'role': 'Lider',
            'power': ownerPower,
            'joinedAt': FieldValue.serverTimestamp(),
          });
          tx.set(userRef, {
            ...ownerProfileSeed,
            'gangId': gangRef.id,
            'gangName': cleanGangName,
            'gangRole': 'Lider',
          }, SetOptions(merge: true));
        })
        .timeout(const Duration(seconds: 10));

    return {'id': gangRef.id, 'name': cleanGangName, 'role': 'Lider'};
  }

  Future<void> setGangJoinPolicy({
    required String gangId,
    required String leaderUid,
    required bool inviteOnly,
  }) async {
    final cleanGangId = gangId.trim();
    if (cleanGangId.isEmpty) return;
    final gangRef = FirebaseFirestore.instance
        .collection('gangs')
        .doc(cleanGangId);
    final gangSnap = await gangRef.get().timeout(_firestoreOpTimeout);
    if (!gangSnap.exists) {
      throw Exception('Çete bulunamadı.');
    }
    final ownerId = (gangSnap.data()?['ownerId'] as String? ?? '').trim();
    if (ownerId != leaderUid.trim()) {
      throw Exception('Sadece çete lideri bu ayarı değiştirebilir.');
    }
    await gangRef
        .update({
          'inviteOnly': inviteOnly,
          'acceptJoinRequests': !inviteOnly,
          'updatedAt': FieldValue.serverTimestamp(),
        })
        .timeout(_firestoreOpTimeout);
  }

  Future<void> sendGangJoinRequest({
    required String gangId,
    required String fromUid,
    required String fromName,
    required int fromPower,
  }) async {
    final cleanGangId = gangId.trim();
    final cleanFromUid = fromUid.trim();
    if (cleanGangId.isEmpty || cleanFromUid.isEmpty) return;

    final gangRef = FirebaseFirestore.instance
        .collection('gangs')
        .doc(cleanGangId);
    final gangSnap = await gangRef.get().timeout(_firestoreOpTimeout);
    if (!gangSnap.exists) {
      throw Exception('Çete bulunamadı.');
    }
    final gang = gangSnap.data()!;
    final ownerId = (gang['ownerId'] as String? ?? '').trim();
    if (ownerId.isEmpty) {
      throw Exception('Çete lideri bulunamadı.');
    }
    if (ownerId == cleanFromUid) {
      throw Exception('Kendi çetene katılım isteği gönderemezsin.');
    }
    final currentCount = (gang['memberCount'] as num?)?.toInt() ?? 0;
    if (currentCount >= 5) {
      throw Exception('Bu çete dolu. Maksimum 5 üye olabilir.');
    }
    final inviteOnly = gang['inviteOnly'] == true;
    final acceptJoinRequests = gang['acceptJoinRequests'] != false;
    if (inviteOnly || !acceptJoinRequests) {
      throw Exception('Bu çete sadece davet ile katılım kabul ediyor.');
    }

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(cleanFromUid);
    final userSnap = await userRef.get().timeout(_firestoreOpTimeout);
    final existingGang = (userSnap.data()?['gangId'] as String? ?? '').trim();
    if (existingGang.isNotEmpty) {
      throw Exception('Zaten bir çetedesin.');
    }

    final reqId = '${cleanGangId}_$cleanFromUid';
    final requestRef = FirebaseFirestore.instance
        .collection('gang_join_requests')
        .doc(reqId);
    final gangName = (gang['name'] as String? ?? 'Çete').trim();
    final ownerName = (gang['ownerName'] as String? ?? 'Lider').trim();
    await requestRef
        .set({
          'gangId': cleanGangId,
          'gangName': gangName.isEmpty ? 'Çete' : gangName,
          'leaderId': ownerId,
          'leaderName': ownerName.isEmpty ? 'Lider' : ownerName,
          'fromId': cleanFromUid,
          'fromName': fromName.trim().isEmpty ? 'Oyuncu' : fromName.trim(),
          'fromPower': fromPower,
          'status': 'pending',
          'message':
              '${fromName.trim().isEmpty ? 'Bir oyuncu' : fromName.trim()} çeteye katılmak istiyor.',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true))
        .timeout(_firestoreOpTimeout);
  }

  Future<List<Map<String, dynamic>>> fetchGangJoinRequestsForLeader(
    String leaderUid,
  ) async {
    final cleanLeaderUid = leaderUid.trim();
    if (cleanLeaderUid.isEmpty) return [];
    final snap = await FirebaseFirestore.instance
        .collection('gang_join_requests')
        .where('leaderId', isEqualTo: cleanLeaderUid)
        .where('status', isEqualTo: 'pending')
        .get()
        .timeout(_firestoreOpTimeout);
    final rows = snap.docs
        .map((d) => {'id': d.id, ...d.data()})
        .toList(growable: false);
    rows.sort((a, b) {
      final aTs = (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      final bTs = (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      return bTs.compareTo(aTs);
    });
    return rows;
  }

  Future<void> respondGangJoinRequest({
    required String leaderUid,
    required String requestId,
    required bool accept,
  }) async {
    final cleanRequestId = requestId.trim();
    final cleanLeaderUid = leaderUid.trim();
    if (cleanRequestId.isEmpty || cleanLeaderUid.isEmpty) return;
    final reqRef = FirebaseFirestore.instance
        .collection('gang_join_requests')
        .doc(cleanRequestId);

    await FirebaseFirestore.instance
        .runTransaction((tx) async {
          final reqSnap = await tx.get(reqRef);
          if (!reqSnap.exists) {
            throw Exception('Katılım isteği bulunamadı.');
          }
          final req = reqSnap.data()!;
          if ((req['leaderId'] as String? ?? '').trim() != cleanLeaderUid) {
            throw Exception('Bu isteği sadece lider yönetebilir.');
          }
          if ((req['status'] as String? ?? '') != 'pending') {
            throw Exception('Bu istek zaten işlenmiş.');
          }

          if (!accept) {
            tx.update(reqRef, {
              'status': 'rejected',
              'respondedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
            return;
          }

          final gangId = (req['gangId'] as String? ?? '').trim();
          final memberUid = (req['fromId'] as String? ?? '').trim();
          if (gangId.isEmpty || memberUid.isEmpty) {
            throw Exception('İstek verisi eksik.');
          }

          final gangRef = FirebaseFirestore.instance
              .collection('gangs')
              .doc(gangId);
          final memberRef = gangRef.collection('members').doc(memberUid);
          final userRef = FirebaseFirestore.instance
              .collection('users')
              .doc(memberUid);

          final gangSnap = await tx.get(gangRef);
          if (!gangSnap.exists) {
            throw Exception('Çete bulunamadı.');
          }
          final gang = gangSnap.data()!;
          if ((gang['ownerId'] as String? ?? '').trim() != cleanLeaderUid) {
            throw Exception('Lider bilgisi geçersiz.');
          }
          final currentMemberCount =
              (gang['memberCount'] as num?)?.toInt() ?? 0;
          if (currentMemberCount >= 5) {
            throw Exception('Çete dolu. Maksimum 5 üye olabilir.');
          }

          final userSnap = await tx.get(userRef);
          final userData = userSnap.data();
          if (!userSnap.exists) {
            throw Exception(
              'Oyuncu profili bulunamadı. Oyuncudan tekrar giriş yapmasını isteyin.',
            );
          }
          final existingGang = (userData?['gangId'] as String? ?? '').trim();
          if (existingGang.isNotEmpty && existingGang != gangId) {
            throw Exception('Oyuncu başka bir çetede.');
          }

          final memberSnap = await tx.get(memberRef);
          final alreadyMember = memberSnap.exists;
          final displayName =
              (userData?['displayName'] as String?)?.trim().isNotEmpty == true
              ? (userData!['displayName'] as String).trim()
              : ((req['fromName'] as String?)?.trim().isNotEmpty == true
                    ? (req['fromName'] as String).trim()
                    : 'Oyuncu');
          final power =
              (userData?['power'] as num?)?.toInt() ??
              (req['fromPower'] as num?)?.toInt() ??
              0;

          if (!alreadyMember) {
            tx.set(memberRef, {
              'uid': memberUid,
              'displayName': displayName,
              'role': 'Üye',
              'power': power,
              'joinedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            tx.update(gangRef, {
              'memberCount': FieldValue.increment(1),
              'totalPower': FieldValue.increment(power),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }

          tx.update(userRef, {
            'gangId': gangId,
            'gangName': (gang['name'] as String? ?? 'Çete'),
            'gangRole': 'Üye',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          tx.update(reqRef, {
            'status': 'accepted',
            'respondedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        })
        .timeout(const Duration(seconds: 10));
  }

  Future<void> assignGangMemberRole({
    required String gangId,
    required String targetUid,
    required String role,
  }) async {
    final cleanGangId = gangId.trim();
    final cleanTargetUid = targetUid.trim();
    final cleanRole = role.trim();
    if (cleanGangId.isEmpty || cleanTargetUid.isEmpty || cleanRole.isEmpty) {
      throw Exception('Geçersiz kartel rütbe isteği.');
    }
    await FirebaseFunctions.instance
        .httpsCallable('assignGangMemberRole')
        .call({
          'gangId': cleanGangId,
          'targetUid': cleanTargetUid,
          'role': cleanRole,
        })
        .timeout(const Duration(seconds: 10));
  }

  /// İsimle kullanıcı arar, UID döner. Bulunamazsa null.
  Future<String?> findUidByName(String displayName) async {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return null;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('name', isEqualTo: trimmed)
        .limit(1)
        .get()
        .timeout(_firestoreOpTimeout);
    if (snap.docs.isNotEmpty) return snap.docs.first.id;
    // displayName alanına da bak
    final snap2 = await FirebaseFirestore.instance
        .collection('users')
        .where('displayName', isEqualTo: trimmed)
        .limit(1)
        .get()
        .timeout(_firestoreOpTimeout);
    if (snap2.docs.isNotEmpty) return snap2.docs.first.id;
    return null;
  }

  Future<void> sendGangInvite({
    required String gangId,
    required String leaderUid,
    required String leaderName,
    required String toUid,
  }) async {
    final cleanGangId = gangId.trim();
    final cleanLeaderUid = leaderUid.trim();
    final cleanToUid = toUid.trim();
    if (cleanGangId.isEmpty || cleanLeaderUid.isEmpty || cleanToUid.isEmpty) {
      return;
    }
    if (cleanLeaderUid == cleanToUid) {
      throw Exception('Kendine davet gönderemezsin.');
    }

    final gangRef = FirebaseFirestore.instance
        .collection('gangs')
        .doc(cleanGangId);
    final gangSnap = await gangRef.get().timeout(_firestoreOpTimeout);
    if (!gangSnap.exists) {
      throw Exception('Çete bulunamadı.');
    }
    final gang = gangSnap.data()!;
    if ((gang['ownerId'] as String? ?? '').trim() != cleanLeaderUid) {
      throw Exception('Sadece lider davet gönderebilir.');
    }

    final targetRef = FirebaseFirestore.instance
        .collection('users')
        .doc(cleanToUid);
    final targetSnap = await targetRef.get().timeout(_firestoreOpTimeout);
    if (!targetSnap.exists) {
      throw Exception('Davet edilecek oyuncu bulunamadı.');
    }
    final targetGang = (targetSnap.data()?['gangId'] as String? ?? '').trim();
    if (targetGang.isNotEmpty) {
      throw Exception('Bu oyuncu zaten bir çetede.');
    }

    final inviteId = '${cleanGangId}_$cleanToUid';
    final inviteRef = FirebaseFirestore.instance
        .collection('gang_invites')
        .doc(inviteId);
    final gangName = (gang['name'] as String? ?? 'Çete').trim();
    await inviteRef
        .set({
          'gangId': cleanGangId,
          'gangName': gangName.isEmpty ? 'Çete' : gangName,
          'leaderId': cleanLeaderUid,
          'leaderName': leaderName.trim().isEmpty ? 'Lider' : leaderName.trim(),
          'toUid': cleanToUid,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true))
        .timeout(_firestoreOpTimeout);
  }

  Future<List<Map<String, dynamic>>> fetchIncomingGangInvites(
    String uid,
  ) async {
    final cleanUid = uid.trim();
    if (cleanUid.isEmpty) return [];
    final snap = await FirebaseFirestore.instance
        .collection('gang_invites')
        .where('toUid', isEqualTo: cleanUid)
        .where('status', isEqualTo: 'pending')
        .get()
        .timeout(_firestoreOpTimeout);
    final rows = snap.docs
        .map((d) => {'id': d.id, ...d.data()})
        .toList(growable: false);
    rows.sort((a, b) {
      final aTs = (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      final bTs = (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      return bTs.compareTo(aTs);
    });
    return rows;
  }

  Future<void> acceptGangInvite({
    required String uid,
    required String inviteId,
  }) async {
    final cleanUid = uid.trim();
    final cleanInviteId = inviteId.trim();
    if (cleanUid.isEmpty || cleanInviteId.isEmpty) return;

    final inviteRef = FirebaseFirestore.instance
        .collection('gang_invites')
        .doc(cleanInviteId);

    await FirebaseFirestore.instance
        .runTransaction((tx) async {
          final inviteSnap = await tx.get(inviteRef);
          if (!inviteSnap.exists) {
            throw Exception('Davet bulunamadı.');
          }
          final invite = inviteSnap.data()!;
          if ((invite['toUid'] as String? ?? '').trim() != cleanUid) {
            throw Exception('Bu davet sana ait değil.');
          }
          if ((invite['status'] as String? ?? '') != 'pending') {
            throw Exception('Bu davet zaten işlenmiş.');
          }

          final gangId = (invite['gangId'] as String? ?? '').trim();
          if (gangId.isEmpty) {
            throw Exception('Çete bilgisi eksik.');
          }

          final gangRef = FirebaseFirestore.instance
              .collection('gangs')
              .doc(gangId);
          final userRef = FirebaseFirestore.instance
              .collection('users')
              .doc(cleanUid);
          final memberRef = gangRef.collection('members').doc(cleanUid);

          final gangSnap = await tx.get(gangRef);
          if (!gangSnap.exists) {
            throw Exception('Çete bulunamadı.');
          }
          final gang = gangSnap.data()!;

          final userSnap = await tx.get(userRef);
          final userData = userSnap.data();
          final existingGang = (userData?['gangId'] as String? ?? '').trim();
          if (existingGang.isNotEmpty && existingGang != gangId) {
            throw Exception('Zaten başka bir çetedesin.');
          }

          final memberSnap = await tx.get(memberRef);
          final alreadyMember = memberSnap.exists;
          final displayName =
              (userData?['displayName'] as String?)?.trim().isNotEmpty == true
              ? (userData!['displayName'] as String).trim()
              : 'Oyuncu';
          final power = (userData?['power'] as num?)?.toInt() ?? 0;

          if (!alreadyMember) {
            tx.set(memberRef, {
              'uid': cleanUid,
              'displayName': displayName,
              'role': 'Üye',
              'power': power,
              'joinedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            tx.update(gangRef, {
              'memberCount': FieldValue.increment(1),
              'totalPower': FieldValue.increment(power),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }

          tx.set(userRef, {
            'uid': cleanUid,
            'name': displayName,
            'displayName': displayName,
            'gangId': gangId,
            'gangName': (gang['name'] as String? ?? 'Çete'),
            'gangRole': 'Üye',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          tx.update(inviteRef, {
            'status': 'accepted',
            'respondedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        })
        .timeout(const Duration(seconds: 10));
  }

  Future<void> rejectGangInvite({
    required String uid,
    required String inviteId,
  }) async {
    final cleanUid = uid.trim();
    final cleanInviteId = inviteId.trim();
    if (cleanUid.isEmpty || cleanInviteId.isEmpty) return;
    final inviteRef = FirebaseFirestore.instance
        .collection('gang_invites')
        .doc(cleanInviteId);
    final inviteSnap = await inviteRef.get().timeout(_firestoreOpTimeout);
    if (!inviteSnap.exists) return;
    final invite = inviteSnap.data()!;
    if ((invite['toUid'] as String? ?? '').trim() != cleanUid) {
      throw Exception('Bu davet sana ait değil.');
    }
    await inviteRef
        .update({
          'status': 'rejected',
          'respondedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        })
        .timeout(_firestoreOpTimeout);
  }

  Future<void> donateToGang({
    required String gangId,
    required String uid,
    required String displayName,
    required int amount,
    required int respectGain,
  }) async {
    if (gangId.isEmpty || amount <= 0) return;
    final gangRef = FirebaseFirestore.instance.collection('gangs').doc(gangId);
    final logRef = gangRef.collection('contributions').doc();

    final batch = FirebaseFirestore.instance.batch();
    batch.update(gangRef, {
      'vault': FieldValue.increment(amount),
      'respectPoints': FieldValue.increment(respectGain),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(logRef, {
      'uid': uid,
      'displayName': displayName,
      'amount': amount,
      'respectGain': respectGain,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> joinGang({
    required String uid,
    required String displayName,
    required String gangId,
    required int power,
  }) async {
    final cleanUid = uid.trim();
    final cleanGangId = gangId.trim();
    if (cleanUid.isEmpty || cleanGangId.isEmpty) {
      throw Exception('Eksik oyuncu veya çete bilgisi.');
    }

    final gangRef = FirebaseFirestore.instance
        .collection('gangs')
        .doc(cleanGangId);
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(cleanUid);
    final memberRef = gangRef.collection('members').doc(cleanUid);
    final inviteRef = FirebaseFirestore.instance
        .collection('gang_invites')
        .doc('${cleanGangId}_$cleanUid');

    await FirebaseFirestore.instance
        .runTransaction((tx) async {
          final gangSnap = await tx.get(gangRef);
          if (!gangSnap.exists) {
            throw Exception('Çete bulunamadı.');
          }
          final gangData = gangSnap.data()!;
          final gangName = gangData['name'] as String? ?? 'Çete';
          final inviteOnly = gangData['inviteOnly'] == true;
          final acceptJoinRequests = gangData['acceptJoinRequests'] != false;

          if (inviteOnly || !acceptJoinRequests) {
            final inviteSnap = await tx.get(inviteRef);
            if (!inviteSnap.exists) {
              throw Exception('Bu çeteye sadece davet ile katılabilirsin.');
            }
            final invite = inviteSnap.data()!;
            final status = (invite['status'] as String? ?? '').trim();
            if (status != 'pending' && status != 'accepted') {
              throw Exception('Davet geçersiz veya süresi dolmuş.');
            }
          }

          final userSnap = await tx.get(userRef);
          final userGangId = (userSnap.data()?['gangId'] as String? ?? '')
              .trim();
          if (userGangId.isNotEmpty && userGangId != cleanGangId) {
            throw Exception('Önce mevcut çetenden ayrılman gerekiyor.');
          }

          final memberSnap = await tx.get(memberRef);
          final alreadyMember = memberSnap.exists;
          if (!alreadyMember) {
            tx.set(memberRef, {
              'uid': cleanUid,
              'displayName': displayName,
              'role': 'Üye',
              'power': power,
              'joinedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            tx.update(gangRef, {
              'memberCount': FieldValue.increment(1),
              'totalPower': FieldValue.increment(power),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }

          tx.set(userRef, {
            'uid': cleanUid,
            'name': displayName,
            'displayName': displayName,
            'gangId': cleanGangId,
            'gangName': gangName,
            'gangRole': 'Üye',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        })
        .timeout(const Duration(seconds: 10));
  }

  Future<void> leaveGang({
    required String uid,
    required String gangId,
    required int power,
  }) async {
    final gangRef = FirebaseFirestore.instance.collection('gangs').doc(gangId);
    final memberRef = gangRef.collection('members').doc(uid);
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    // Üye sayısını kontrol et
    final gangSnap = await gangRef.get().timeout(_firestoreOpTimeout);
    final currentCount =
        (gangSnap.data()?['memberCount'] as num?)?.toInt() ?? 1;
    final ownerId = (gangSnap.data()?['ownerId'] as String? ?? '').trim();
    final isOwner = ownerId == uid.trim();

    final batch = FirebaseFirestore.instance.batch();
    batch.delete(memberRef);
    batch.set(userRef, {
      'uid': uid,
      'gangId': '',
      'gangName': '',
      'gangRole': '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Son üye veya lider çıkıyorsa çeteyi sil
    if (currentCount <= 1 || isOwner) {
      batch.delete(gangRef);
    } else {
      batch.update(gangRef, {
        'memberCount': FieldValue.increment(-1),
        'totalPower': FieldValue.increment(-power),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<Map<String, dynamic>?> fetchGang(String gangId) async {
    if (gangId.isEmpty) return null;
    final snap = await FirebaseFirestore.instance
        .collection('gangs')
        .doc(gangId)
        .get()
        .timeout(_firestoreOpTimeout);
    if (!snap.exists) return null;
    return snap.data();
  }

  Future<List<Map<String, dynamic>>> fetchGangMembers(String gangId) async {
    if (gangId.isEmpty) return [];
    final snap = await FirebaseFirestore.instance
        .collection('gangs')
        .doc(gangId)
        .collection('members')
        .orderBy('power', descending: true)
        .get()
        .timeout(_firestoreOpTimeout);
    // Dedupe: doc ID, uid alanı ve displayName bazlı
    final seenUids = <String>{};
    final seenNames = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final d in snap.docs) {
      final data = d.data();
      final memberUid = (data['uid'] as String?)?.trim() ?? d.id;
      final name = (data['displayName'] as String?)?.trim() ?? '';
      if (seenUids.add(memberUid) && (name.isEmpty || seenNames.add(name))) {
        result.add(data);
      }
    }
    return result;
  }

  Future<void> seedBotData() async {
    try {
      await FirebaseFunctions.instance.httpsCallable('seedBotData').call();
    } catch (_) {
      // Sessizce geç — kritik değil
    }
  }

  Future<List<Map<String, dynamic>>> fetchGangs({int limit = 20}) async {
    final col = FirebaseFirestore.instance.collection('gangs');
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await col
          .orderBy('memberCount', descending: true)
          .limit(limit)
          .get()
          .timeout(_firestoreOpTimeout);
    } catch (_) {
      snap = await col
          .orderBy('updatedAt', descending: true)
          .limit(limit)
          .get()
          .timeout(_firestoreOpTimeout);
    }
    final rows = snap.docs
        .map((d) {
          return {'id': d.id, ...d.data()};
        })
        .toList(growable: false);
    return _dedupeGangList(rows);
  }

  List<Map<String, dynamic>> _dedupeGangList(List<Map<String, dynamic>> rows) {
    final byOwner = <String, Map<String, dynamic>>{};
    final ownerless = <Map<String, dynamic>>[];
    int memberCountOf(Map<String, dynamic> g) =>
        (g['memberCount'] as num?)?.toInt() ?? 0;
    int powerOf(Map<String, dynamic> g) =>
        (g['totalPower'] as num?)?.toInt() ?? 0;

    for (final raw in rows) {
      final g = Map<String, dynamic>.from(raw);
      final ownerId = (g['ownerId'] as String? ?? '').trim();
      if (ownerId.isEmpty) {
        ownerless.add(g);
        continue;
      }
      final existing = byOwner[ownerId];
      if (existing == null) {
        byOwner[ownerId] = g;
        continue;
      }
      final betterByMembers = memberCountOf(g) > memberCountOf(existing);
      final betterByPower = powerOf(g) > powerOf(existing);
      if (betterByMembers || (!betterByMembers && betterByPower)) {
        byOwner[ownerId] = g;
      }
    }

    final byName = <String, Map<String, dynamic>>{};
    String normalizeName(String value) =>
        value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9çğıöşü]+'), '').trim();

    for (final g in [...ownerless, ...byOwner.values]) {
      final nameKey = normalizeName((g['name'] as String? ?? ''));
      if (nameKey.isEmpty) {
        byName['id:${g['id']?.toString() ?? ''}'] = g;
        continue;
      }
      final existing = byName[nameKey];
      if (existing == null) {
        byName[nameKey] = g;
        continue;
      }
      final betterByMembers = memberCountOf(g) > memberCountOf(existing);
      final betterByPower = powerOf(g) > powerOf(existing);
      if (betterByMembers || (!betterByMembers && betterByPower)) {
        byName[nameKey] = g;
      }
    }
    final deduped = byName.values.toList(growable: false);
    deduped.sort((a, b) {
      final mc = memberCountOf(b).compareTo(memberCountOf(a));
      if (mc != 0) return mc;
      return powerOf(b).compareTo(powerOf(a));
    });
    return deduped;
  }

  Future<void> deleteAccountAndData(String uid) async {
    final cleanUid = uid.trim();
    if (cleanUid.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('user_saves')
          .doc(cleanUid)
          .delete();
    } catch (_) {}
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(cleanUid)
          .delete();
    } catch (_) {}

    final current = FirebaseAuth.instance.currentUser;
    if (current != null) {
      await current.delete();
    }
  }
}
