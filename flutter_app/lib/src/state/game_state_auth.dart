// ignore_for_file: curly_braces_in_flow_control_structures

part of 'game_state.dart';

mixin _GameStateAuth on _GameStateBase {
  Future<bool> loginGuest({String? name}) async {
    loggedIn = true;
    authMode = 'guest';
    userId = userId.isEmpty
        ? 'guest_${DateTime.now().millisecondsSinceEpoch}'
        : userId;
    playerName = (name == null || name.trim().isEmpty)
        ? tt('Patron_local_', 'Boss_local_')
        : name.trim();
    avatarLocked = true;
    onboardingCompleted = true;
    nicknameChosen = true;
    _addNews(
      tt('Yeni Patron', 'New Boss'),
      tt('$playerName şehre giriş yaptı.', '$playerName entered the city.'),
    );
    _handlePlayerLogin();
    await _save();
    notifyListeners();
    return true;
  }

  void clearAuthError() {
    if (lastAuthError.isEmpty) return;
    lastAuthError = '';
    notifyListeners();
  }

  Future<bool> loginWithEmail(String email, String password) async {
    lastAuthError = '';
    final authReady = await _ensureFirebaseReadyForAuth();
    if (!authReady) return false;
    try {
      final cred = await _onlineService.signInEmail(email, password);
      final u = cred.user;
      if (u == null) {
        lastAuthError = tt(
          'Kullanıcı bilgisi alınamadı.',
          'User data not found.',
        );
        return false;
      }
      loggedIn = true;
      authMode = 'firebase';
      userId = u.uid;
      playerName = u.displayName ?? u.email?.split('@').first ?? playerName;
      onboardingCompleted = _isCustomPlayerName(playerName);
      avatarLocked = onboardingCompleted;
      nicknameChosen = onboardingCompleted;
      _handlePlayerLogin();
      await _runAuthPostStep(
        '[EmailLogin] cloud save attach',
        _pullOrCreateCloudSaveAfterAuth,
      );
      unawaited(_runAuthPostStep('[EmailLogin] post warmup', _postLoginWarmup));
      await _save();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[EmailLogin] final error in GameState => $e');
      lastAuthError = _sanitizeError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    lastAuthError = '';
    final authReady = await _ensureFirebaseReadyForAuth();
    if (!authReady) return false;
    final normalized = email.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized)) {
      lastAuthError = tt('Geçerli bir e-posta gir.', 'Enter a valid email.');
      notifyListeners();
      return false;
    }
    try {
      await _onlineService.sendPasswordReset(normalized);
      notifyListeners();
      return true;
    } catch (e) {
      lastAuthError = _sanitizeError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> registerWithEmail(String email, String password) async {
    lastAuthError = '';
    final authReady = await _ensureFirebaseReadyForAuth();
    if (!authReady) return false;
    try {
      final cred = await _onlineService.signUpEmail(email, password);
      final u = cred.user;
      if (u == null) {
        lastAuthError = tt(
          'Hesap oluşturulamadı.',
          'Could not create account.',
        );
        return false;
      }
      loggedIn = true;
      authMode = 'firebase';
      userId = u.uid;
      playerName = u.email?.split('@').first ?? playerName;
      avatarLocked = false;
      onboardingCompleted = false;
      nicknameChosen = false;
      _handlePlayerLogin();
      await _runAuthPostStep(
        '[EmailRegister] cloud save attach',
        _pullOrCreateCloudSaveAfterAuth,
      );
      unawaited(
        _runAuthPostStep('[EmailRegister] post warmup', _postLoginWarmup),
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

  Future<bool> loginWithGoogle() async {
    lastAuthError = '';
    final authReady = await _ensureFirebaseReadyForAuth();
    if (!authReady) return false;
    try {
      final cred = await _onlineService.signInGoogle();
      if (cred == null || cred.user == null) {
        lastAuthError = tt(
          'Google girişi iptal edildi.',
          'Google sign-in was canceled.',
        );
        notifyListeners();
        return false;
      }
      final u = cred.user!;
      loggedIn = true;
      authMode = 'firebase';
      userId = u.uid;
      playerName = u.displayName ?? u.email?.split('@').first ?? playerName;
      onboardingCompleted = _isCustomPlayerName(playerName);
      avatarLocked = onboardingCompleted;
      // Google'dan gelen ad sadece öneri; nick seçimini bir kez zorunlu tut.
      nicknameChosen = false;
      _handlePlayerLogin();
      await _runAuthPostStep(
        '[GoogleLogin] cloud save attach',
        _pullOrCreateCloudSaveAfterAuth,
      );
      unawaited(
        _runAuthPostStep('[GoogleLogin] post warmup', _postLoginWarmup),
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

  Future<bool> _ensureFirebaseReadyForAuth() async {
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
              'Firebase bağlantısı hazır değil. Lütfen daha sonra tekrar dene.',
              'Firebase is not ready. Please try again later.',
            );
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<void> _runAuthPostStep(
    String label,
    Future<void> Function() step,
  ) async {
    try {
      await step().timeout(_GameStateBase._authPostStepTimeout);
    } catch (e) {
      debugPrint('$label failed => $e');
    }
  }

  Future<void> logout() async {
    lastLogoutEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Önce UI'ı hemen güncelle — Firebase işlemleri beklemesin
    final savedAuthMode = authMode;
    final savedUserId = userId;
    loggedIn = false;
    playerOnline = false;
    authMode = 'local';
    userId = '';
    friends.clear();
    incomingRequests.clear();
    incomingGangInvites.clear();
    gangJoinRequests.clear();
    leaderboardRows.clear();
    discoverableGangs.clear();
    gangMembers.clear();
    currentGang = null;
    gangRank = 1;
    gangRespectPoints = 0;
    _sessionOfflineReports.clear();
    notifyListeners();
    unawaited(_save());

    // Firebase işlemleri arka planda tamamlansın
    if (savedAuthMode == 'firebase' && firebaseReady && savedUserId.isNotEmpty) {
      try { await NotificationService.clearToken(savedUserId); } catch (_) {}
      try {
        await _onlineService.upsertUserProfile(
          uid: savedUserId,
          displayName: playerName,
          power: totalPower,
          level: level,
          rank: rank,
          cash: cash,
          wins: wins,
          gangWins: gangWins,
          lastLoginEpoch: lastLoginEpoch,
          currentTp: currentTP,
          maxTp: maxTP,
          currentEnergy: currentEnerji,
          maxEnergy: maxEnerji,
          shieldUntilEpoch: shieldUntilEpoch,
          online: false,
          gangId: currentGang?['id']?.toString() ?? '',
          gangName: currentGang?['name']?.toString() ?? '',
          avatarId: selectedAvatarId,
          equippedWeaponId: equippedWeaponId,
          equippedKnifeId: equippedKnifeId,
          equippedArmorId: equippedArmorId,
          equippedVehicleId: equippedVehicleId,
          combatWeaponId: equippedCombatWeaponId,
        );
      } catch (_) {}
      await _onlineService.signOut();
    }
  }

  Future<void> setOnline(bool value) async {
    // Kept for backward compatibility. Manual toggle is disabled.
    online = true;
    playerOnline = loggedIn;
    if (loggedIn) {
      _handlePlayerLogin();
    }
    await replayPendingQueue();
    await ensureOnlineProfile();
    await refreshSocialData();
    await _save();
    notifyListeners();
  }

  Future<void> selectAvatar(String avatarId) async {
    if (!StaticData.avatarClasses.any((a) => a.id == avatarId)) return;
    if (avatarLocked && avatarId != selectedAvatarId) return;
    selectedAvatarId = avatarId;
    await _save();
    _syncOnlineSoon();
    notifyListeners();
  }

  Future<void> completeOnboarding({
    required String name,
    required String avatarId,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (!StaticData.avatarClasses.any((a) => a.id == avatarId)) return;

    playerName = trimmed;
    if (!avatarLocked || !onboardingCompleted || !nicknameChosen) {
      selectedAvatarId = avatarId;
    }
    avatarLocked = true;
    onboardingCompleted = true;
    nicknameChosen = true;
    await _save();
    unawaited(ensureOnlineProfile());
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    final next = (code == 'en') ? 'en' : 'tr';
    if (languageCode == next) return;
    languageCode = next;
    if (playerName == 'Oyuncu' || playerName == 'Player') {
      playerName = tt('Oyuncu', 'Player');
    }
    if (firebaseReady) {
      firebaseStatus = tt('Firebase bağlı', 'Firebase connected');
    }
    await _save();
    notifyListeners();
  }

  Future<void> toggleLanguage() async {
    await setLanguage(isEnglish ? 'tr' : 'en');
  }

  Future<void> setMusicEnabled(bool value) async {
    musicEnabled = value;
    await _save();
    notifyListeners();
  }

  Future<void> setSfxEnabled(bool value) async {
    sfxEnabled = value;
    await _save();
    notifyListeners();
  }

  Future<void> setNotifyEnergyFull(bool value) async {
    notifyEnergyFull = value;
    await _save();
    notifyListeners();
  }

  Future<void> setNotifyHospitalReady(bool value) async {
    notifyHospitalReady = value;
    await _save();
    notifyListeners();
  }

  Future<void> setNotifyUnderAttack(bool value) async {
    notifyUnderAttack = value;
    await _save();
    notifyListeners();
  }

  Future<void> setNotifyGangMessages(bool value) async {
    notifyGangMessages = value;
    await _save();
    notifyListeners();
  }

  Future<String> renamePlayer(String nextName) async {
    final trimmed = nextName.trim();
    if (trimmed.length < 3) {
      return tt(
        'İsim en az 3 karakter olmalı.',
        'Name must be at least 3 characters.',
      );
    }
    if (trimmed == playerName) {
      return tt(
        'Yeni isim eski isimle aynı.',
        'New name is same as current name.',
      );
    }
    final cost = nameChangeCount == 0 ? 0 : 50;
    if (gold < cost) {
      return tt(
        'İsim değiştirmek için $cost Altın gerekli.',
        '$cost Gold is required to rename.',
      );
    }
    if (cost > 0) gold -= cost;
    playerName = trimmed;
    nameChangeCount += 1;
    _addNews(
      tt('Profil Güncellendi', 'Profile Updated'),
      tt('İsim değişti: $playerName', 'Name changed: $playerName'),
    );
    await _save();
    _syncOnlineSoon();
    notifyListeners();
    return tt('İsim güncellendi.', 'Name updated.');
  }

  Future<String> deleteLinkedAccount() async {
    if (authMode != 'firebase' || !firebaseReady || userId.isEmpty) {
      return tt(
        'Sadece bağlı hesap silinebilir.',
        'Only linked accounts can be deleted.',
      );
    }
    try {
      final uid = userId;
      await _onlineService.deleteAccountAndData(uid);
      await _onlineService.signOut();
      _resetProgressForFreshProfile();
      loggedIn = false;
      authMode = 'local';
      userId = '';
      saveOwnerUid = '';
      await _save();
      notifyListeners();
      return tt('Hesap silindi.', 'Account deleted.');
    } catch (e) {
      return _sanitizeError(e);
    }
  }
}
