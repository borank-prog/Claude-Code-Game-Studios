// ignore_for_file: curly_braces_in_flow_control_structures

part of 'game_state.dart';

mixin _GameStateSocial on _GameStateBase {
  Future<bool> sendFriendRequest(String targetUid) async {
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
    if (!firebaseReady || authMode != 'firebase' || userId.isEmpty) return;
    await _onlineService.acceptFriendRequest(
      myUid: userId,
      requestId: requestId,
    );
    await refreshSocialData();
    notifyListeners();
  }

  Future<void> rejectFriendRequest(String requestId) async {
    if (!firebaseReady || authMode != 'firebase' || userId.isEmpty) return;
    await _onlineService.rejectFriendRequest(requestId);
    await refreshSocialData();
    notifyListeners();
  }

  Future<bool> createGang(String name) async {
    if (!firebaseReady || authMode != 'firebase' || userId.isEmpty)
      return false;
    if (name.trim().isEmpty) return false;
    if (gangId.isNotEmpty) return false;
    try {
      final result = await _onlineService.createGang(
        ownerUid: userId,
        ownerName: playerName,
        gangName: name.trim(),
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
        tt('${name.trim()} kuruldu.', '${name.trim()} created.'),
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
    if (!firebaseReady || authMode != 'firebase' || userId.isEmpty)
      return false;
    if (targetGangId.trim().isEmpty) return false;
    if (gangId.isNotEmpty) return false;
    try {
      final normalizedGangId = targetGangId.trim();
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

  Future<bool> sendGangInvite(String targetUid) async {
    if (!firebaseReady || authMode != 'firebase' || userId.isEmpty)
      return false;
    if (!hasGang || !isGangLeader) return false;
    final cleanTargetUid = targetUid.trim();
    if (cleanTargetUid.isEmpty) return false;
    try {
      await _onlineService.sendGangInvite(
        gangId: gangId,
        leaderUid: userId,
        leaderName: playerName,
        toUid: cleanTargetUid,
      );
      _addNews(
        tt('Çete Daveti', 'Gang Invite'),
        tt(
          '$cleanTargetUid oyuncusuna davet gönderildi.',
          'Invite sent to $cleanTargetUid.',
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
