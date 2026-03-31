import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/attack_history_screen.dart';
import '../state/game_state.dart';

class AttackBannerWrapper extends StatefulWidget {
  final Widget child;
  const AttackBannerWrapper({super.key, required this.child});

  @override
  State<AttackBannerWrapper> createState() => _AttackBannerWrapperState();
}

class _AttackBannerWrapperState extends State<AttackBannerWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  RemoteMessage? _pending;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    FirebaseMessaging.onMessage.listen((msg) {
      if (msg.data['type'] == 'attacked' || msg.data['type'] == 'defeat') {
        setState(() => _pending = msg);
        _ctrl.forward();
        Future.delayed(const Duration(seconds: 4), () {
          if (!mounted) return;
          _ctrl.reverse().then((_) {
            if (mounted) setState(() => _pending = null);
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _bannerColor {
    final type = _pending?.data['type'];
    return type == 'defeat'
        ? const Color(0xFFf87171)
        : const Color(0xFFfbbf24);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_pending != null)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: false,
              child: SlideTransition(
                position: _slide,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      _ctrl.reverse();
                      final state = context.read<GameState>();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AttackHistoryScreen(
                            uid: state.userId,
                            playerName: state.playerName,
                            playerPower: state.totalPower,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 320,
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1A2E),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _bannerColor.withValues(alpha: 0.6),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _bannerColor.withValues(alpha: 0.25),
                            blurRadius: 22,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: _bannerColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _bannerColor,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              _pending?.data['type'] == 'defeat'
                                  ? Icons.local_hospital_rounded
                                  : Icons.warning_amber_rounded,
                              color: _bannerColor,
                              size: 36,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _pending?.notification?.title ?? '',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _bannerColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _pending?.notification?.body ?? '',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
