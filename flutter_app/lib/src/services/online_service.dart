import 'package:cloud_firestore/cloud_firestore.dart';
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
              'Firebase yapılandırması eksik. Misafir girişi ile devam edebilirsin.';
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
    await FirebaseAuth.instance.signOut();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }

  Future<void> upsertUserProfile({
    required String uid,
    required String displayName,
    required int power,
    required int level,
    required int rank,
    int? currentTp,
    int? maxTp,
    int? currentEnergy,
    int? maxEnergy,
    int? shieldUntilEpoch,
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
    final doc = FirebaseFirestore.instance.collection('users').doc(uid);
    final payload = <String, dynamic>{
      'uid': uid,
      'displayName': displayName,
      'power': power,
      'level': level,
      'rank': rank,
      'currentTp': currentTp ?? 0,
      'maxTp': maxTp ?? 0,
      'currentEnergy': currentEnergy ?? 0,
      'maxEnergy': maxEnergy ?? 0,
      'attackEnergyCost': attackEnergyCost ?? 20,
      'shieldUntilEpoch': shieldUntilEpoch ?? 0,
      'avatarId': avatarId ?? '',
      'equippedWeaponId': equippedWeaponId ?? '',
      'equippedKnifeId': equippedKnifeId ?? '',
      'equippedArmorId': equippedArmorId ?? '',
      'equippedVehicleId': equippedVehicleId ?? '',
      'combatWeaponId': combatWeaponId ?? '',
      'online': online,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (gangId != null) {
      payload['gangId'] = gangId;
    }
    if (gangName != null) {
      payload['gangName'] = gangName;
    }
    await doc
        .set(payload, SetOptions(merge: true))
        .timeout(_firestoreOpTimeout);
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
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .orderBy('power', descending: true)
        .limit(limit)
        .get()
        .timeout(_firestoreOpTimeout);
    return snap.docs.map((d) => d.data()).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> fetchFriends(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('friends')
        .orderBy('displayName')
        .get()
        .timeout(_firestoreOpTimeout);
    return snap.docs.map((d) => d.data()).toList(growable: false);
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

  Future<Map<String, dynamic>> createGang({
    required String ownerUid,
    required String ownerName,
    required String gangName,
    required int ownerPower,
  }) async {
    final gangs = FirebaseFirestore.instance.collection('gangs');
    final gangRef = gangs.doc();
    final membersRef = gangRef.collection('members').doc(ownerUid);
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(ownerUid);

    final batch = FirebaseFirestore.instance.batch();
    batch.set(gangRef, {
      'id': gangRef.id,
      'name': gangName,
      'ownerId': ownerUid,
      'ownerName': ownerName,
      'gangRank': 1,
      'respectPoints': 0,
      'vault': 0,
      'memberCount': 1,
      'totalPower': ownerPower,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(membersRef, {
      'uid': ownerUid,
      'displayName': ownerName,
      'role': 'Lider',
      'power': ownerPower,
      'joinedAt': FieldValue.serverTimestamp(),
    });
    batch.set(userRef, {
      'gangId': gangRef.id,
      'gangName': gangName,
      'gangRole': 'Lider',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();

    return {'id': gangRef.id, 'name': gangName, 'role': 'Lider'};
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
    final gangRef = FirebaseFirestore.instance.collection('gangs').doc(gangId);
    final gangSnap = await gangRef.get();
    if (!gangSnap.exists) {
      throw Exception('Çete bulunamadı.');
    }

    final gangData = gangSnap.data()!;
    final gangName = gangData['name'] as String? ?? 'Çete';

    final memberRef = gangRef.collection('members').doc(uid);
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    final batch = FirebaseFirestore.instance.batch();
    batch.set(memberRef, {
      'uid': uid,
      'displayName': displayName,
      'role': 'Üye',
      'power': power,
      'joinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.update(gangRef, {
      'memberCount': FieldValue.increment(1),
      'totalPower': FieldValue.increment(power),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(userRef, {
      'gangId': gangId,
      'gangName': gangName,
      'gangRole': 'Üye',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> leaveGang({
    required String uid,
    required String gangId,
    required int power,
  }) async {
    final gangRef = FirebaseFirestore.instance.collection('gangs').doc(gangId);
    final memberRef = gangRef.collection('members').doc(uid);
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    final batch = FirebaseFirestore.instance.batch();
    batch.delete(memberRef);
    batch.update(gangRef, {
      'memberCount': FieldValue.increment(-1),
      'totalPower': FieldValue.increment(-power),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(userRef, {
      'gangId': '',
      'gangName': '',
      'gangRole': '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
    return snap.docs.map((d) => d.data()).toList(growable: false);
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
    return snap.docs
        .map((d) {
          return {'id': d.id, ...d.data()};
        })
        .toList(growable: false);
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
