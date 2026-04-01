// ignore_for_file: curly_braces_in_flow_control_structures

part of 'game_state.dart';

mixin _GameStateSocial on _GameStateBase {
  Future<bool> _ensureFirebaseReadyForSocial() async {
    if (firebaseReady) return true;
    final ok = await _onlineService.initialize();
    firebaseReady = ok;
    firebaseStatus = ok
        ? tt('Firebase bağlı', 'Firebase connected')
        : _onlineService.initError;
    if (!ok) {
      lastAuthError = firebaseStatus.isNotEmpty
          ? firebaseStatus
          : tt(
              'Firebase bağlantısı hazır değil. Lütfen tekrar dene.',
              'Firebase is not ready. Please try again.',
            );
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<bool> sendFriendRequest(String targetUid) async {
    if (isActionLocked) {
      lastAuthError = actionLockMessage;
      notifyListeners();
      return false;
    }
    if (!firebaseReady || !online || authMode != 'firebase') return false;
    if (userId.isEmpty ||
        targetUid.trim().isEmpty ||
        targetUid.trim() == userId) {
      return false;
    }
    try {
      await _onlineService.sendFriendRequest(
        fromId: userId,
        fromName: playerName,
        toId: targetUid.trim(),
      );
      _addNews(
        tt('Arkadaş', 'Friend'),
        tt(
          '${targetUid.trim()} kullanıcısına istek gönderildi.',
          'Request sent to user ${targetUid.trim()}.',
        ),
      );
      await refreshSocialData();
      return true;
    } catch (e) {
      lastAuthError = _sanitizeError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> acceptFriendRequest(String requestId) async {
    if (isActionLocked) {
      lastAuthError = actionLockMessage;
      notifyListeners();
      return;
    }
    if (!firebaseReady || authMode != 'firebase' || userId.isEmpty) return;
    await _onlineService.acceptFriendRequest(
      myUid: userId,
      requestId: requestId,
    );
    await refreshSocialData();
    notifyListeners();
  }

  Future<void> rejectFriendRequest(String requestId) async {
    if (isActionLocked) {
      lastAuthError = actionLockMessage;
      notifyListeners();
      return;
    }
    if (!firebaseReady || authMode != 'firebase' || userId.isEmpty) return;
    await _onlineService.rejectFriendRequest(requestId);
    await refreshSocialData();
    notifyListeners();
  }

  Future<bool> removeFriend(String friendUid, {String friendName = ''}) async {
    if (isActionLocked) {
      lastAuthError = actionLockMessage;
      notifyListeners();
      return false;
    }
    if (!firebaseReady || authMode != 'firebase' || userId.isEmpty) return false;
    final cleanFriendUid = friendUid.trim();
    if (cleanFriendUid.isEmpty || cleanFriendUid == userId) return false;
    try {
      await _onlineService.removeFriend(
        myUid: userId,
        friendUid: cleanFriendUid,
      );
      _addNews(
        tt('Arkadaş', 'Friend'),
        tt(
          '${friendName.trim().isEmpty ? cleanFriendUid : friendName.trim()} arkadaş listesinden çıkarıldı.',
          '${friendName.trim().isEmpty ? cleanFriendUid : friendName.trim()} was removed from friends.',
        ),
      );
      await refreshSocialData();
      notifyListeners();
      return true;
    } catch (e) {
      lastAuthError = _sanitizeError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> createGang(String name) async {
    if (isActionLocked) {
      lastAuthError = actionLockMessage;
      notifyListeners();
      return false;
    }
    lastAuthError = '';
    final gangName = name.trim();
    if (gangName.isEmpty) {
      lastAuthError = tt('Önce bir çete adı yaz.', 'Enter a gang name first.');
      notifyListeners();
      return false;
    }
    if (gangId.isNotEmpty) {
      lastAuthError = tt('Zaten bir çetedesin.', 'You are already in a gang.');
      notifyListeners();
      return false;
    }
    if (!firebaseReady) {
      final authReady = await _ensureFirebaseReadyForSocial();
      if (!authReady) return false;
    }
    if (authMode != 'firebase') {
      final onlineUser = _onlineService.currentUser;
      if (onlineUser != null) {
        authMode = 'firebase';
        userId = onlineUser.uid;
      }
    }
    if (!firebaseReady || authMode != 'firebase' || userId.isEmpty) {
      lastAuthError = tt(
        'Çete kurmak için e-posta/Google hesabı ile giriş yapmalısın.',
        'You must sign in with email/Google to create a gang.',
      );
      notifyListeners();
      return false;
    }
    try {
      final result = await _onlineService.createGang(
        ownerUid: userId,
        ownerName: playerName,
        gangName: gangName,
        ownerPower: totalPower,
      );
      currentGang = {
        'id': result['id'],
        'name': result['name'],
        'role': result['role'],
      };
      gangRank = 1;
      gangRespectPoints = 0;
      gangVault = 0;
      await ensureOnlineProfile();
      await refreshSocialData();
      _addNews(
        tt('Çete', 'Gang'),
        tt('$gangName kuruldu.', '$gangName created.'),
      );
      await _save();
      notifyListeners();
      return true;
    } catch (e) {
      lastAuthError = _sanitizeError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> joinGang(String targetGangId) async {
    if (isActionLocked) {
      lastAuthError = actionLockMessage;
      notifyListeners();
      return false;
    }
    lastAuthError = '';
    final normalizedGangId = targetGangId.trim();
    if (normalizedGangId.isEmpty) {
      lastAuthError = tt(
        'Katılmak için bir Çete ID gir.',
        'Enter a Gang ID to join.',
      );
      notifyListeners();
      return false;
    }
    if (gangId.isNotEmpty) {
      lastAuthError = tt('Zaten bir çetedesin.', 'You are already in a gang.');
      notifyListeners();
      return false;
    }
    if (!firebaseReady) {
      final authReady = await _ensureFirebaseReadyForSocial();
      if (!authReady) return false;
    }
    if (authMode != 'firebase') {
      final onlineUser = _onlineService.currentUser;
      if (onlineUser != null) {
        authMode = 'firebase';
        userId = onlineUser.uid;
      }
    }
    if (!firebaseReady || authMode != 'firebase' || userId.isEmpty) {
      lastAuthError = tt(
        'Çeteye katılmak için e-posta/Google hesabı ile giriş yapmalısın.',
        'You must sign in with email/Google to join a gang.',
      );
      notifyListeners();
      return false;
    }
    try {
      await _onlineService.sendGangJoinRequest(
        gangId: normalizedGangId,
        fromUid: userId,
        fromName: playerName,
        fromPower: totalPower,
      );
      await refreshSocialData();
      _addNews(
        tt('Çete', 'Gang'),
        tt(
          '$normalizedGangId çetesine katılım isteği gönderdin.',
          'You sent a join request to $normalizedGangId.',
        ),
      );
      await _save();
      notifyListeners();
      return true;
    } catch (e) {
      lastAuthError = _sanitizeError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> setGangInviteOnly(bool inviteOnly) async {
    if (isActionLocked) {
      lastAuthError = actionLockMessage;
      notifyListeners();
      return false;
    }
    if (!firebaseReady || authMode != 'firebase' || userId.isEmpty)
      return false;
    if (!hasGang || !isGangLeader) return false;
    try {
      await _onlineService.setGangJoinPolicy(
        gangId: gangId,
        leaderUid: userId,
        inviteOnly: inviteOnly,
      );
      await refreshSocialData();
      _addNews(
        tt('Çete Ayarı', 'Gang Settings'),
        inviteOnly
            ? tt(
                'Katılım istekleri kapatıldı. Artık sadece davet ile giriş var.',
                'Join requests closed. New members can join only by invite.',
              )
            : tt('Katılım istekleri açıldı.', 'Join requests enabled.'),
      );
      await _save();
      notifyListeners();
      return true;
    } catch (e) {
      lastAuthError = _sanitizeError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendGangInvite(String targetUidOrName) async {
    if (isActionLocked) {
      lastAuthError = actionLockMessage;
      notifyListeners();
      return false;
    }
    if (!firebaseReady || authMode != 'firebase' || userId.isEmpty)
      return false;
    if (!hasGang || !isGangLeader) return false;
    final raw = targetUidOrName.trim();
    if (raw.isEmpty) return false;
    try {
      // UID gibi görünmüyorsa (kısa veya boşluk içeriyorsa) isimle ara
      String resolvedUid = raw;
      final looksLikeUid = raw.length >= 20 && !raw.contains(' ');
      if (!looksLikeUid) {
        final found = await _onlineService.findUidByName(raw);
        if (found == null) {
          lastAuthError = tt(
            '"$raw" adında oyuncu bulunamadı.',
            'No player found with name "$raw".',
          );
          notifyListeners();
          return false;
        }
        resolvedUid = found;
      }
      await _onlineService.sendGangInvite(
        gangId: gangId,
        leaderUid: userId,
        leaderName: playerName,
        toUid: resolvedUid,
      );
      _addNews(
        tt('Çete Daveti', 'Gang Invite'),
        tt(
          '$raw oyuncusuna davet gönderildi.',
          'Invite sent to $raw.',
        ),
      );
      await refreshSocialData();
      notifyListeners();
      return true;
    } catch (e) {
      lastAuthError = _sanitizeError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> acceptGangJoinRequest(String requestId) async {
    if (isActionLocked) {
      lastAuthError = actionLockMessage;
      notifyListeners();
      return;
    }
    if (!firebaseReady || authMode != 'firebase' || userId.isEmpty) return;
    if (!hasGang || !isGangLeader) return;
    try {
      await _onlineService.respondGangJoinRequest(
        leaderUid: userId,
        requestId: requestId.trim(),
        accept: true,
      );
      await refreshSocialData();
      notifyListeners();
    } catch (e) {
      lastAuthError = _sanitizeError(e);
      notifyListeners();
    }
  }

  Future<void> rejectGangJoinRequest(String requestId) async {
    if (isActionLocked) {
      lastAuthError = actionLockMessage;
      notifyListeners();
      return;
    }
    if (!firebaseReady || authMode != 'firebase' || userId.isEmpty) return;
    if (!hasGang || !isGangLeader) return;
    try {
      await _onlineService.respondGangJoinRequest(
        leaderUid: userId,
        requestId: requestId.trim(),
        accept: false,
      );
      await refreshSocialData();
      notifyListeners();
    } catch (e) {
      lastAuthError = _sanitizeError(e);
      notifyListeners();
    }
  }

  Future<void> acceptGangInvite(String inviteId) async {
    if (isActionLocked) {
      lastAuthError = actionLockMessage;
      notifyListeners();
      return;
    }
    if (!firebaseReady || authMode != 'firebase' || userId.isEmpty) return;
    if (gangId.isNotEmpty) return;
    try {
      await _onlineService.acceptGangInvite(
        uid: userId,
        inviteId: inviteId.trim(),
      );
      await refreshSocialData();
      _addNews(
        tt('Çete Daveti', 'Gang Invite'),
        tt(
          'Davet kabul edildi, çeteye katıldın.',
          'Invite accepted, you joined the gang.',
        ),
      );
      await _save();
      notifyListeners();
    } catch (e) {
      lastAuthError = _sanitizeError(e);
      notifyListeners();
    }
  }

  Future<void> rejectGangInvite(String inviteId) async {
    if (isActionLocked) {
      lastAuthError = actionLockMessage;
      notifyListeners();
      return;
    }
    if (!firebaseReady || authMode != 'firebase' || userId.isEmpty) return;
    try {
      await _onlineService.rejectGangInvite(
        uid: userId,
        inviteId: inviteId.trim(),
      );
      await refreshSocialData();
      notifyListeners();
    } catch (e) {
      lastAuthError = _sanitizeError(e);
      notifyListeners();
    }
  }

  Future<void> leaveGang() async {
    if (isActionLocked) {
      lastAuthError = actionLockMessage;
      notifyListeners();
      return;
    }
    if (!firebaseReady ||
        authMode != 'firebase' ||
        userId.isEmpty ||
        gangId.isEmpty)
      return;
    try {
      await _onlineService.leaveGang(
        uid: userId,
        gangId: gangId,
        power: totalPower,
      );
      currentGang = null;
      gangMembers.clear();
      gangJoinRequests.clear();
      gangRank = 1;
      gangRespectPoints = 0;
      gangVault = 0;
      await ensureOnlineProfile();
      await refreshSocialData();
      _addNews(
        tt('Çete', 'Gang'),
        tt('Çeteden ayrıldın.', 'You left the gang.'),
      );
      await _save();
      notifyListeners();
    } catch (e) {
      lastAuthError = _sanitizeError(e);
      notifyListeners();
    }
  }

  Future<bool> donateToGang({int amount = 1000}) async {
    if (isActionLocked) {
      lastAuthError = actionLockMessage;
      notifyListeners();
      return false;
    }
    if (!hasGang) return false;
    if (amount <= 0) return false;
    if (cash < amount) return false;

    cash -= amount;
    gangVault += amount;
    final respectGain = max(1, amount ~/ 250);
    gangRespectPoints += respectGain;
    _recomputeGangRank();

    if (firebaseReady &&
        online &&
        authMode == 'firebase' &&
        userId.isNotEmpty) {
      try {
        await _onlineService.donateToGang(
          gangId: gangId,
          uid: userId,
          displayName: playerName,
          amount: amount,
          respectGain: respectGain,
        );
      } catch (_) {}
    }

    _queueEvent('gang_donate', {
      'gangId': gangId,
      'amount': amount,
      'respect': respectGain,
    });
    _addNews(
      tt('Çete Kasası', 'Gang Vault'),
      tt(
        '\$$amount bağış yaptın. Saygınlık arttı.',
        'You donated \$$amount. Respect increased.',
      ),
    );
    await _save();
    _syncOnlineSoon();
    notifyListeners();
    return true;
  }
}
