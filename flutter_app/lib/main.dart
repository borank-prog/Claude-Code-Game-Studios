import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';

import 'src/config/firebase_bootstrap.dart';
import 'src/screens/attack_history_screen.dart';
import 'src/screens/home_shell.dart';
import 'src/screens/login_screen.dart';
import 'src/screens/onboarding_screen.dart';
import 'src/state/game_state.dart';
import 'src/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase ve background handler'ı paralel başlat
  final firebaseFuture = _initializeFirebase();
  final gameState = GameState();
  // UI'ı hemen göster, Firebase arka planda tamamlansın
  runApp(CartelHoodFlutterApp(gameState: gameState));
  await firebaseFuture;
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await gameState.initialize();
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp();
    debugPrint('Firebase basariyla kuruldu.');
  } catch (e) {
    try {
      await Firebase.initializeApp(options: FirebaseBootstrap.currentOptions);
      debugPrint('Firebase basariyla kuruldu (fallback options).');
    } on StateError catch (cfg) {
      debugPrint('Firebase web config eksik: $cfg');
    } catch (fallbackError) {
      debugPrint('Firebase baslatilamadi: $fallbackError');
      debugPrint('Ilk hata: $e');
    }
  }
}

class CartelHoodFlutterApp extends StatefulWidget {
  const CartelHoodFlutterApp({super.key, required this.gameState});

  final GameState gameState;

  @override
  State<CartelHoodFlutterApp> createState() => _CartelHoodFlutterAppState();
}

class _CartelHoodFlutterAppState extends State<CartelHoodFlutterApp>
    with WidgetsBindingObserver {
  bool _wasLoggedIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wasLoggedIn = widget.gameState.loggedIn;
    widget.gameState.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    widget.gameState.removeListener(_onAuthChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onAuthChanged() {
    final loggedIn = widget.gameState.loggedIn;
    if (_wasLoggedIn && !loggedIn) {
      // Frame bittikten sonra navigate et — build sırasında çağrılmasın
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NotificationService.navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      });
    }
    _wasLoggedIn = loggedIn;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      widget.gameState.onAppBackground();
    } else if (state == AppLifecycleState.resumed) {
      widget.gameState.onAppForeground();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.gameState,
      child: MaterialApp(
        navigatorKey: NotificationService.navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'CartelHood Flutter',
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF081428),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFBBF24),
            brightness: Brightness.dark,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0x66101B31),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0x557F8EA8)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0x557F8EA8)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFBBF24)),
            ),
            labelStyle: const TextStyle(color: Color(0xFFD1D5DB)),
          ),
        ),
        onGenerateRoute: (settings) {
          if (settings.name == '/attack_detail') {
            return MaterialPageRoute(
              builder: (ctx) {
                final gs = ctx.read<GameState>();
                return AttackHistoryScreen(
                  uid: gs.userId,
                  playerName: gs.playerName,
                  playerPower: gs.totalPower,
                );
              },
            );
          }
          return null;
        },
        builder: kIsWeb
            ? (context, child) => _WebMobileFrame(child: child!)
            : null,
        home: Consumer<GameState>(
          builder: (context, state, child) {
            if (!state.loggedIn) return const LoginScreen();
            if (state.needsOnboarding) return const OnboardingScreen();
            return const HomeShell();
          },
        ),
      ),
    );
  }
}

/// Web'de uygulamayı telefon boyutuna (430px) kısıtlar.
/// MediaQuery'yi de override ederek tüm widget'ların dar ekran gördüğünü sağlar.
class _WebMobileFrame extends StatelessWidget {
  const _WebMobileFrame({required this.child});

  final Widget child;

  static const double _mobileWidth = 430.0;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    // Gerçek mobil tarayıcı — kısıtlama yapma
    if (mq.size.width <= _mobileWidth + 20) return child;

    // Masaüstü/tablet: ortala, MediaQuery'yi 430px olarak raporla
    final narrowMq = mq.copyWith(
      size: Size(_mobileWidth, mq.size.height),
    );

    return Container(
      color: const Color(0xFF030810),
      child: Center(
        child: SizedBox(
          width: _mobileWidth,
          height: mq.size.height,
          child: ClipRect(
            child: MediaQuery(
              data: narrowMq,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
