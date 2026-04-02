import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';

import '../state/game_state.dart';
import 'achievements_screen.dart';
import 'login_screen.dart';
import 'city_screen.dart';
import 'market_screen.dart';
import 'profile_screen.dart';
import 'social_screen.dart';
import 'street_screen.dart';
import 'settings_screen.dart';
import 'inbox_screen.dart';
import '../widgets/game_background.dart';
import '../widgets/format.dart';
import '../widgets/attack_banner.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;
  bool _jailPromptVisible = false;
  int _jailPromptForUntil = 0;
  bool _hospitalPromptVisible = false;
  int _hospitalPromptForUntil = 0;
  Timer? _ticker;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _inboxUnreadSub;
  String _watchingInboxUid = '';
  int _inboxUnreadCount = 0;
  int _lastKnownUnread = 0;
  bool _inboxWatchPrimed = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showOfflineReportsIfAny();
      _maybeShowPenaltyPopup();
      context.read<GameState>().addListener(_onGameStateChanged);
      _ensureInboxWatcher();
    });
  }

  void _onGameStateChanged() {
    if (!mounted) return;
    final state = context.read<GameState>();
    if (state.pendingItemBrokenNotices.isEmpty) return;
    final notices = List<String>.from(state.pendingItemBrokenNotices);
    state.pendingItemBrokenNotices.clear();
    for (final name in notices) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF7F1D1D),
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const Icon(Icons.delete_forever, color: Color(0xFFFCA5A5), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.tt(
                    '$name tamamen eskidi ve çöpe atıldı!',
                    '$name wore out and was discarded!',
                  ),
                  style: const TextStyle(color: Color(0xFFFCA5A5), fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  void dispose() {
    if (mounted) {
      try { context.read<GameState>().removeListener(_onGameStateChanged); } catch (_) {}
    }
    _inboxUnreadSub?.cancel();
    _inboxUnreadSub = null;
    _ticker?.cancel();
    super.dispose();
  }

  void _ensureInboxWatcher() {
    if (!mounted) return;
    final state = context.read<GameState>();
    final uid = state.userId.trim();
    if (uid.isEmpty) {
      _inboxUnreadSub?.cancel();
      _inboxUnreadSub = null;
      _watchingInboxUid = '';
      _inboxUnreadCount = 0;
      _lastKnownUnread = 0;
      _inboxWatchPrimed = false;
      return;
    }
    if (_watchingInboxUid == uid && _inboxUnreadSub != null) return;

    _inboxUnreadSub?.cancel();
    _watchingInboxUid = uid;
    _inboxUnreadCount = 0;
    _lastKnownUnread = 0;
    _inboxWatchPrimed = false;

    _inboxUnreadSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('inbox')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snap) {
          if (!mounted) return;
          final unread = snap.docs.length;
          if (_inboxWatchPrimed && unread > _lastKnownUnread) {
            final incoming = unread - _lastKnownUnread;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: const Color(0xFF0B223E),
                duration: const Duration(seconds: 3),
                content: Row(
                  children: [
                    const Icon(
                      Icons.mark_email_unread_rounded,
                      color: Color(0xFFFBBF24),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.tt(
                          'Mesaj kutuna $incoming yeni bildirim geldi.',
                          '$incoming new inbox notification(s).',
                        ),
                        style: const TextStyle(
                          color: Color(0xFFE5E7EB),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                action: SnackBarAction(
                  label: state.tt('Aç', 'Open'),
                  textColor: const Color(0xFFFBBF24),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => InboxScreen(uid: uid)),
                    );
                  },
                ),
              ),
            );
          }
          _inboxWatchPrimed = true;
          _lastKnownUnread = unread;
          if (mounted) {
            setState(() => _inboxUnreadCount = unread);
          }
        });
  }

  Future<void> _showOfflineReportsIfAny() async {
    if (!mounted) return;
    final state = context.read<GameState>();
    final logs = state.takeSessionOfflineReports();
    if (logs.isEmpty) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF13233E),
        title: Text(
          state.tt(
            'Sen Yokken Sokaklarda Olanlar',
            'What Happened While You Were Away',
          ),
          style: const TextStyle(color: Color(0xFFFBBF24)),
        ),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: logs
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '• $e',
                        style: const TextStyle(color: Color(0xFFD1D5DB)),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(state.tt('Tamam', 'OK')),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBackNavigation() async {
    if (!mounted) return;
    if (tab != 0) {
      setState(() => tab = 0);
      return;
    }
    await SystemNavigator.pop();
  }

  void _maybeShowPenaltyPopup() {
    if (!mounted) return;
    final state = context.read<GameState>();
    if (state.jailSecondsLeft > 0) {
      if (_jailPromptVisible || _hospitalPromptVisible) return;
      if (_jailPromptForUntil == state.jailUntilEpoch) return;
      _jailPromptForUntil = state.jailUntilEpoch;
      _showJailPopup(state);
      return;
    }
    if (state.hospitalSecondsLeft <= 0) return;
    if (_hospitalPromptVisible || _jailPromptVisible) return;
    if (_hospitalPromptForUntil == state.hospitalUntilEpoch) return;
    _hospitalPromptForUntil = state.hospitalUntilEpoch;
    _showHospitalPopup(state);
  }

  Future<void> _showJailPopup(GameState state) async {
    if (!mounted) return;
    _jailPromptVisible = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            final cost = state.jailSkipGoldCost;
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xEE13233E),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFEF4444),
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.tt('YAKALANDIN!', 'YOU GOT CAUGHT!'),
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.asset(
                          'assets/art/ui/jail_bars_photo.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Image.asset(
                                'assets/art/ui/jail_bars_photo.png',
                                fit: BoxFit.cover,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      state.tt(
                        'Hemen çıkmak için $cost Altın öde, yoksa ${state.penaltyDurationMinutes} dakika bekle.',
                        'Pay $cost Gold to leave now, or wait ${state.penaltyDurationMinutes} minutes.',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFD1D5DB),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    StreamBuilder<int>(
                      stream: Stream<int>.periodic(
                        const Duration(seconds: 1),
                        (_) => DateTime.now().millisecondsSinceEpoch ~/ 1000,
                      ),
                      initialData:
                          DateTime.now().millisecondsSinceEpoch ~/ 1000,
                      builder: (context, snap) {
                        final nowEpoch =
                            snap.data ??
                            (DateTime.now().millisecondsSinceEpoch ~/ 1000);
                        final secLeft = math.max(
                          0,
                          state.jailUntilEpoch - nowEpoch,
                        );
                        if (secLeft <= 0) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          });
                        }
                        return Text(
                          '${state.tt('Kalan Süre', 'Time Left')}: ${secondsToClock(secLeft)}',
                          style: const TextStyle(
                            color: Color(0xFFFCA5A5),
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          final beforeGold = state.gold;
                          await state.payJailWithGold();
                          if (!mounted || !ctx.mounted) return;
                          if (state.jailSecondsLeft <= 0) {
                            Navigator.of(ctx).pop();
                            return;
                          }
                          if (state.gold == beforeGold) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  state.tt(
                                    'Yeterli altının yok!',
                                    'Not enough gold!',
                                  ),
                                ),
                              ),
                            );
                          }
                          setLocalState(() {});
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0B223E),
                          foregroundColor: const Color(0xFFE5E7EB),
                        ),
                        child: Text(
                          '$cost ${state.tt('Altın Öde ve Çık', 'Pay Gold and Exit')}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(
                          state.tt(
                            '${state.penaltyDurationMinutes} Dakika Bekle',
                            'Wait ${state.penaltyDurationMinutes} Minutes',
                          ),
                          style: const TextStyle(
                            color: Color(0xFFE5E7EB),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    _jailPromptVisible = false;
    if (mounted) {
      setState(() {});
      _maybeShowPenaltyPopup();
    }
  }

  Future<void> _showHospitalPopup(GameState state) async {
    if (!mounted) return;
    _hospitalPromptVisible = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            final cost = state.hospitalSkipGoldCost;
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xEE13233E),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFFB7185),
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.tt('HASTANELİK OLDUN!', 'YOU WERE HOSPITALIZED!'),
                      style: const TextStyle(
                        color: Color(0xFFFB7185),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.asset(
                          'assets/art/ui/hospital_injury_photo.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Image.asset(
                                'assets/art/ui/hospital_injury_photo.png',
                                fit: BoxFit.cover,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      state.tt(
                        'Hemen çıkmak için $cost Altın öde, yoksa ${state.penaltyDurationMinutes} dakika bekle.',
                        'Pay $cost Gold to leave now, or wait ${state.penaltyDurationMinutes} minutes.',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFD1D5DB),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    StreamBuilder<int>(
                      stream: Stream<int>.periodic(
                        const Duration(seconds: 1),
                        (_) => DateTime.now().millisecondsSinceEpoch ~/ 1000,
                      ),
                      initialData:
                          DateTime.now().millisecondsSinceEpoch ~/ 1000,
                      builder: (context, snap) {
                        final nowEpoch =
                            snap.data ??
                            (DateTime.now().millisecondsSinceEpoch ~/ 1000);
                        final secLeft = math.max(
                          0,
                          state.hospitalUntilEpoch - nowEpoch,
                        );
                        if (secLeft <= 0) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          });
                        }
                        return Text(
                          '${state.tt('Kalan Süre', 'Time Left')}: ${secondsToClock(secLeft)}',
                          style: const TextStyle(
                            color: Color(0xFFFCA5A5),
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          final beforeGold = state.gold;
                          await state.payHospitalWithGold();
                          if (!mounted || !ctx.mounted) return;
                          if (state.hospitalSecondsLeft <= 0) {
                            Navigator.of(ctx).pop();
                            return;
                          }
                          if (state.gold == beforeGold) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  state.tt(
                                    'Yeterli altının yok!',
                                    'Not enough gold!',
                                  ),
                                ),
                              ),
                            );
                          }
                          setLocalState(() {});
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0B223E),
                          foregroundColor: const Color(0xFFE5E7EB),
                        ),
                        child: Text(
                          '$cost ${state.tt('Altın Öde ve Çık', 'Pay Gold and Exit')}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(
                          state.tt(
                            '${state.penaltyDurationMinutes} Dakika Bekle',
                            'Wait ${state.penaltyDurationMinutes} Minutes',
                          ),
                          style: const TextStyle(
                            color: Color(0xFFE5E7EB),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    _hospitalPromptVisible = false;
    if (mounted) {
      setState(() {});
      _maybeShowPenaltyPopup();
    }
  }

  Widget _pageForTab() {
    switch (tab) {
      case 0:
        return const ProfileScreen();
      case 1:
        return const StreetScreen();
      case 2:
        return const CityScreen();
      case 3:
        return const MarketScreen();
      default:
        return const SocialScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    _ensureInboxWatcher();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeShowPenaltyPopup(),
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBackNavigation();
      },
      child: AttackBannerWrapper(
        child: Scaffold(
          backgroundColor: const Color(0xFF081428),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bodyWidth = math.min(430.0, constraints.maxWidth);
                return Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: bodyWidth,
                    height: constraints.maxHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const GameBackground(child: SizedBox.shrink()),
                        _pageForTab(),
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Consumer<GameState>(
                            builder: (context, state, child) => Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: _handleBackNavigation,
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xCC14233F),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: const Color(0x55FBBF24),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back_rounded,
                                    size: 20,
                                    color: Color(0xFFFBBF24),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: _languagePill(state),
                        ),
                        Positioned(
                          top: 56,
                          right: 8,
                          child: Semantics(
                            container: true,
                            button: true,
                            label: state.tt('Ayarlar', 'Settings'),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0xCC14233F),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0x55FBBF24),
                                ),
                              ),
                              child: IconButton(
                                tooltip: state.tt('Ayarlar', 'Settings'),
                                icon: const Icon(
                                  Icons.settings_outlined,
                                  size: 19,
                                  color: Color(0xFFFBBF24),
                                ),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const SettingsScreen(),
                                    ),
                                  );
                                },
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(42, 42),
                                  padding: EdgeInsets.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Achievement button
                        Positioned(
                          top: 104,
                          right: 8,
                          child: Semantics(
                            container: true,
                            button: true,
                            label: state.tt('Basarimlar', 'Achievements'),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0xCC14233F),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: state.unclaimedAchievementCount > 0
                                      ? const Color(0xAAFBBF24)
                                      : const Color(0x55FBBF24),
                                ),
                              ),
                              child: Stack(
                                children: [
                                  IconButton(
                                    tooltip: state.tt(
                                      'Basarimlar',
                                      'Achievements',
                                    ),
                                    icon: const Icon(
                                      Icons.emoji_events_outlined,
                                      size: 19,
                                      color: Color(0xFFFBBF24),
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const AchievementsScreen(),
                                        ),
                                      );
                                    },
                                    style: IconButton.styleFrom(
                                      minimumSize: const Size(42, 42),
                                      padding: EdgeInsets.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  if (state.unclaimedAchievementCount > 0)
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFEF4444),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${state.unclaimedAchievementCount}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Logout button
                        Positioned(
                          top: 152,
                          right: 8,
                          child: Semantics(
                            container: true,
                            button: true,
                            label: state.tt('Çıkış Yap', 'Log Out'),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0xCC3A1114),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0x55F87171),
                                ),
                              ),
                              child: IconButton(
                                tooltip: state.tt('Çıkış Yap', 'Log Out'),
                                icon: const Icon(
                                  Icons.logout,
                                  size: 18,
                                  color: Color(0xFFFCA5A5),
                                ),
                                onPressed: () async {
                                  final gs = context.read<GameState>();
                                  final nav = Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  );
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: const Color(0xFF111a2e),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      title: Text(
                                        gs.tt('Çıkış Yap', 'Log Out'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      content: Text(
                                        gs.tt(
                                          'Hesabından çıkmak istediğine emin misin?',
                                          'Are you sure you want to log out?',
                                        ),
                                        style: const TextStyle(
                                          color: Color(0xFF9ca3af),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(false),
                                          child: Text(
                                            gs.tt('Vazgeç', 'Cancel'),
                                            style: const TextStyle(
                                              color: Color(0xFF9ca3af),
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(true),
                                          child: Text(
                                            gs.tt('Çıkış Yap', 'Log Out'),
                                            style: const TextStyle(
                                              color: Color(0xFFEF4444),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed != true) return;
                                  await gs.logout();
                                  nav.pushAndRemoveUntil(
                                    MaterialPageRoute(
                                      builder: (_) => const LoginScreen(),
                                    ),
                                    (route) => false,
                                  );
                                },
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(42, 42),
                                  padding: EdgeInsets.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Inbox button
                        Positioned(
                          top: 200,
                          right: 8,
                          child: Semantics(
                            container: true,
                            button: true,
                            label: state.tt('Mesaj Kutusu', 'Inbox'),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0xCC14233F),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: _inboxUnreadCount > 0
                                      ? const Color(0xAAEF4444)
                                      : const Color(0x55FBBF24),
                                ),
                              ),
                              child: Stack(
                                children: [
                                  IconButton(
                                    tooltip: state.tt(
                                      'Mesaj Kutusu',
                                      'Inbox',
                                    ),
                                    icon: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: _inboxUnreadCount > 0
                                            ? const Color(0x55EF4444)
                                            : const Color(0x33FBBF24),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _inboxUnreadCount > 0
                                            ? Icons.mail_rounded
                                            : Icons.mark_email_read_rounded,
                                        size: 16,
                                        color: _inboxUnreadCount > 0
                                            ? Colors.white
                                            : const Color(0xFFFBBF24),
                                      ),
                                    ),
                                    onPressed: () {
                                      final uid = state.userId.trim();
                                      if (uid.isEmpty) return;
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => InboxScreen(uid: uid),
                                        ),
                                      );
                                    },
                                    style: IconButton.styleFrom(
                                      minimumSize: const Size(42, 42),
                                      padding: EdgeInsets.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  if (_inboxUnreadCount > 0)
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Container(
                                        constraints: const BoxConstraints(
                                          minWidth: 16,
                                          minHeight: 16,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 3,
                                        ),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFEF4444),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            _inboxUnreadCount > 99
                                                ? '99+'
                                                : '$_inboxUnreadCount',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          bottomNavigationBar: _buildModernBottomNav(context, state),
        ),
      ),
    );
  }

  Widget _languagePill(GameState state) {
    final isEn = state.languageCode == 'en';
    return Semantics(
      container: true,
      button: true,
      label: state.tt('Dili değiştir', 'Switch language'),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => state.setLanguage(isEn ? 'tr' : 'en'),
          child: Container(
            width: 52,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xCC14233F),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x55FBBF24)),
            ),
            child: Text(
              isEn ? 'EN' : 'TR',
              style: const TextStyle(
                color: Color(0xFFFBBF24),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernBottomNav(BuildContext context, GameState state) {
    final navItems = <_ShellNavItem>[
      _ShellNavItem(
        Icons.person_outline_rounded,
        state.tt('Profil', 'Profile'),
      ),
      _ShellNavItem(Icons.flash_on_rounded, state.tt('Sokak', 'Street')),
      _ShellNavItem(Icons.location_city_rounded, state.tt('Şehir', 'City')),
      _ShellNavItem(Icons.storefront_rounded, state.tt('Market', 'Market')),
      _ShellNavItem(Icons.groups_rounded, state.tt('Sosyal', 'Social')),
    ];

    final clampedTab = tab.clamp(0, navItems.length - 1);
    return SizedBox(
      height: 86,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: math.min(540.0, MediaQuery.of(context).size.width),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xE61A2C4E), Color(0xD0101C36)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0x558AA4CC),
                        width: 1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: const TextScaler.linear(1.0)),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                        child: Row(
                          children: List.generate(navItems.length, (i) {
                            final item = navItems[i];
                            final selected = i == clampedTab;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: Semantics(
                                  label: '${item.label} Tab',
                                  selected: selected,
                                  button: true,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () => setState(() => tab = i),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 220,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: selected ? 8 : 4,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          gradient: selected
                                              ? const LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    Color(0xFFE4B35B),
                                                    Color(0xFF7D6029),
                                                  ],
                                                )
                                              : null,
                                          color: selected
                                              ? null
                                              : const Color(0x18000000),
                                          border: Border.all(
                                            color: selected
                                                ? const Color(0x88FFE6AA)
                                                : const Color(0x335E759A),
                                            width: 1,
                                          ),
                                          boxShadow: selected
                                              ? const [
                                                  BoxShadow(
                                                    color: Color(0x44E4B35B),
                                                    blurRadius: 14,
                                                    offset: Offset(0, 2),
                                                  ),
                                                ]
                                              : const [],
                                        ),
                                        child: AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: 180,
                                          ),
                                          switchInCurve: Curves.easeOut,
                                          switchOutCurve: Curves.easeIn,
                                          child: selected
                                              ? Row(
                                                  key: ValueKey('selected_$i'),
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      item.icon,
                                                      size: 19,
                                                      color: const Color(
                                                        0xFF1A1A1A,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 5),
                                                    Flexible(
                                                      child: Text(
                                                        item.label,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          color: Color(
                                                            0xFF111111,
                                                          ),
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          letterSpacing: 0.15,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              : Icon(
                                                  item.icon,
                                                  key: ValueKey('icon_$i'),
                                                  size: 20,
                                                  color: const Color(
                                                    0xFFC6D4EA,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellNavItem {
  const _ShellNavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}
