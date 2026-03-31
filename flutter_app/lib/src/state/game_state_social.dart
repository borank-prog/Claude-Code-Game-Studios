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
      await _onlineService.joinGang(
        uid: userId,
        displayName: playerName,
        gangId: normalizedGangId,
        power: totalPower,
      );
      final joinedGang = await _onlineService.fetchGang(normalizedGangId);
      currentGang = {
        'id': normalizedGangId,
        'name': (joinedGang?['name']?.toString() ?? '').trim().isEmpty
            ? normalizedGangId
            : joinedGang!['name'],
        'role': 'Üye',
      };
      gangRank = 1;
      gangRespectPoints = 0;
      gangVault = 0;
      await ensureOnlineProfile();
      await refreshSocialData();
      _addNews(
        tt('Çete', 'Gang'),
        tt(
          '${currentGang?['name'] ?? normalizedGangId} çetesine katıldın.',
          'You joined gang ${currentGang?['name'] ?? normalizedGangId}.',
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
