import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/game_state.dart';
import 'help_screen.dart';
import 'settings_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final nickCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  bool busy = false;
  bool registerMode = false;
  bool showAuthPanel = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<GameState>();
    final initialName = state.displayPlayerName;
    nickCtrl.text = (initialName == 'Oyuncu' || initialName == 'Player')
        ? ''
        : initialName;
  }

  @override
  void dispose() {
    nickCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<bool> _run(Future<bool> Function() action) async {
    if (busy) return false;
    setState(() => busy = true);
    bool ok = false;
    try {
      ok = await action();
      if (!mounted) return ok;
      final state = context.read<GameState>();
      if (!ok) {
        final text = state.lastAuthError.isNotEmpty
            ? state.lastAuthError
            : state.tt(
                'Kayıt/giriş tamamlanamadı. Bilgileri kontrol edip tekrar dene.',
                'Could not complete sign up/login. Check your details and try again.',
              );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(text)));
      }
      return ok;
    } catch (e) {
      if (!mounted) return false;
      final state = context.read<GameState>();
      final text = e.toString().trim().replaceFirst('Exception:', '').trim();
      state.lastAuthError = text.isNotEmpty
          ? text
          : state.tt('Beklenmeyen hata oluştu.', 'Unexpected error occurred.');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.lastAuthError)));
      return false;
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  void _toggleMode(GameState state, bool toRegister) {
    if (registerMode == toRegister) return;
    FocusScope.of(context).unfocus();
    state.clearAuthError();
    setState(() => registerMode = toRegister);
  }

  void _openAuthPanel(GameState state, {required bool toRegister}) {
    if (busy) return;
    FocusScope.of(context).unfocus();
    state.clearAuthError();
    setState(() {
      registerMode = toRegister;
      showAuthPanel = true;
    });
  }

  void _backToIntro(GameState state) {
    if (busy || !showAuthPanel) return;
    FocusScope.of(context).unfocus();
    state.clearAuthError();
    setState(() => showAuthPanel = false);
  }

  String _fallbackNickFromEmail(
    String email,
    GameState state, {
    String? typedNick,
  }) {
    final direct = (typedNick ?? nickCtrl.text).trim();
    if (direct.length >= 3) return direct;

    final raw = email.split('@').first.trim();
    final cleaned = raw.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    if (cleaned.length >= 3) {
      return cleaned.length > 20 ? cleaned.substring(0, 20) : cleaned;
    }
    return state.tt('Patron_local_', 'Boss_local_');
  }

  Future<void> _submitEmail(GameState state) async {
    final typedNick = nickCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final pass = passCtrl.text;
    final emailOk = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

    if (!emailOk || pass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.tt(
              'Geçerli e-posta ve en az 6 karakter şifre gir.',
              'Enter a valid email and a password with at least 6 characters.',
            ),
          ),
        ),
      );
      return;
    }

    final ok = await _run(() async {
      if (registerMode) {
        final created = await state.registerWithEmail(email, pass);
        if (!created) return false;
        final resolvedNick = _fallbackNickFromEmail(
          email,
          state,
          typedNick: typedNick,
        );
        await state.completeOnboarding(
          name: resolvedNick,
          avatarId: state.selectedAvatarId,
        );
        return true;
      }

      final logged = await state.loginWithEmail(email, pass);
      if (logged && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              state.tt('Tekrar hoş geldin Patron!', 'Welcome back, Boss!'),
            ),
          ),
        );
      }
      return logged;
    });

    if (!mounted) return;
    if (ok) {
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _forgotPassword(GameState state) async {
    final email = emailCtrl.text.trim();
    final ok = await _run(() => state.sendPasswordResetEmail(email));
    if (!ok || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text(
          state.tt(
            'Şifre sıfırlama bağlantısı e-posta adresine gönderildi.',
            'Password reset link sent to your email.',
          ),
        ),
      ),
    );
  }

  Future<void> _loginWithGoogle(GameState state) async {
    FocusScope.of(context).unfocus();
    await _run(state.loginWithGoogle);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    if (!showAuthPanel) {
      return _buildIntroScreen(context, state);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _backToIntro(state);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF070E1D),
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/art/backgrounds/login_bg.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xCC081327),
                      const Color(0xEE071021),
                      const Color(0xFF060D1B),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: math.min(
                        460,
                        MediaQuery.of(context).size.width,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _topIcon(
                              icon: Icons.arrow_back_rounded,
                              onTap: () => _backToIntro(state),
                              tooltip: state.tt(
                                'Giriş kapağına dön',
                                'Back to intro',
                              ),
                            ),
                            const SizedBox(width: 8),
                            _topIcon(
                              icon: Icons.settings_outlined,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SettingsScreen(),
                                  ),
                                );
                              },
                              tooltip: state.tt('Ayarlar', 'Settings'),
                            ),
                            const SizedBox(width: 8),
                            _topIcon(
                              icon: Icons.help_outline_rounded,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const HelpScreen(),
                                  ),
                                );
                              },
                              tooltip: state.tt('Yardım', 'Help'),
                            ),
                            const Spacer(),
                            _languagePill(state),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          state.tt('ŞEHRE HOŞ GELDİN', 'WELCOME TO THE CITY'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFFBBF24),
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          state.tt(
                            'Kartelini kur, bölgeni büyüt, gücünü yükselt.',
                            'Build your cartel, expand your turf, rise in power.',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFB8C6DD),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xD312213A),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: const Color(0x4D8AA4CC),
                              width: 1,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x66000000),
                                blurRadius: 18,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                          child: Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0x66182740),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0x446A80A3),
                                  ),
                                ),
                                padding: const EdgeInsets.all(4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _modeButton(
                                        label: state.tt('Giriş', 'Login'),
                                        selected: !registerMode,
                                        onTap: busy
                                            ? null
                                            : () => _toggleMode(state, false),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: _modeButton(
                                        label: state.tt('Kayıt', 'Register'),
                                        selected: registerMode,
                                        onTap: busy
                                            ? null
                                            : () => _toggleMode(state, true),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (registerMode) ...[
                                TextField(
                                  controller: nickCtrl,
                                  maxLength: 20,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    counterText: '',
                                    labelText: state.tt(
                                      'Nick (en az 3)',
                                      'Nickname (min 3)',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              TextField(
                                controller: emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: state.tt(
                                    'E-posta adresi',
                                    'Email address',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (!registerMode)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: busy
                                        ? null
                                        : () => _forgotPassword(state),
                                    child: Text(
                                      state.tt(
                                        'Şifremi Unuttum',
                                        'Forgot Password',
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              if (!registerMode)
                                Text(
                                  state.tt(
                                    'Sadece e-posta girerek şifre sıfırlayabilirsin.',
                                    'You can reset your password using only email.',
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: passCtrl,
                                obscureText: true,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: state.tt(
                                    'Şifre (min 6)',
                                    'Password (min 6)',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: busy
                                      ? null
                                      : () => _submitEmail(state),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFBBF24),
                                    foregroundColor: const Color(0xFF111827),
                                    minimumSize: const Size.fromHeight(52),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: busy
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            color: Color(0xFF111827),
                                          ),
                                        )
                                      : Text(
                                          registerMode
                                              ? state.tt(
                                                  'E-posta ile Kaydol',
                                                  'Register with Email',
                                                )
                                              : state.tt(
                                                  'E-posta ile Giriş',
                                                  'Login with Email',
                                                ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: (busy || kIsWeb)
                                      ? null
                                      : () => _loginWithGoogle(state),
                                  icon: const Icon(Icons.g_mobiledata_rounded),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF1F3559),
                                    foregroundColor: const Color(0xFFE6EEF8),
                                    minimumSize: const Size.fromHeight(46),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  label: Text(
                                    kIsWeb
                                        ? state.tt(
                                            'Google (Sadece Mobil)',
                                            'Google (Mobile Only)',
                                          )
                                        : state.tt(
                                            'Google ile Devam Et',
                                            'Continue with Google',
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (state.lastAuthError.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  state.lastAuthError,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                              if (!state.firebaseReady) ...[
                                const SizedBox(height: 6),
                                Text(
                                  state.firebaseStatus.isNotEmpty
                                      ? state.firebaseStatus
                                      : state.tt(
                                          'Firebase bağlantısı hazır değil.',
                                          'Firebase connection is not ready.',
                                        ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFFCA5A5),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroScreen(BuildContext context, GameState state) {
    return Scaffold(
      backgroundColor: const Color(0xFF070E1D),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/art/backgrounds/login_cover_main_v2.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (context, error, stackTrace) => Image.asset(
                'assets/art/backgrounds/login_bg.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0x7A040711),
                    const Color(0xCC050A16),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 18,
            child: _languagePill(state),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: math.min(460, MediaQuery.of(context).size.width),
                  ),
                  child: Column(
                    children: [
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        decoration: BoxDecoration(
                          color: const Color(0x5E0A1428),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0x447FA2D3)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x88000000),
                              blurRadius: 22,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFFF9EBC9),
                                    Color(0xFFE2C074),
                                    Color(0xFFC79743),
                                  ],
                                ),
                                border: Border.all(
                                  color: const Color(0xFFFCEAB8),
                                  width: 1.2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0xCC000000),
                                    blurRadius: 20,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () =>
                                      _openAuthPanel(state, toRegister: false),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: const Color(0xFF101522),
                                    shadowColor: Colors.transparent,
                                    minimumSize: const Size.fromHeight(60),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.login_rounded,
                                        size: 20,
                                        color: Color(0xFF101522),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        state.tt('GİRİŞ YAP', 'LOGIN'),
                                        style: const TextStyle(
                                          fontSize: 21,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xD61E2C45),
                                    Color(0xEE0E1628),
                                  ],
                                ),
                                border: Border.all(
                                  color: const Color(0x88F1CB79),
                                  width: 1,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x88000000),
                                    blurRadius: 14,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: SizedBox(
                                width: 240,
                                child: ElevatedButton(
                                  onPressed: () =>
                                      _openAuthPanel(state, toRegister: true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: const Color(0xFFF5DB9E),
                                    shadowColor: Colors.transparent,
                                    minimumSize: const Size.fromHeight(46),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.person_add_alt_1_rounded,
                                        size: 17,
                                        color: Color(0xFFF5DB9E),
                                      ),
                                      const SizedBox(width: 7),
                                      Text(
                                        state.tt('KAYDOL', 'REGISTER'),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.6,
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topIcon({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x7F101C30),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x556D82A8)),
        ),
        child: IconButton(
          icon: Icon(icon, size: 18, color: const Color(0xFFE5E7EB)),
          onPressed: onTap,
          style: IconButton.styleFrom(
            minimumSize: const Size(38, 38),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );
  }

  Widget _languagePill(GameState state) {
    final en = state.languageCode == 'en';
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: busy ? null : () => state.setLanguage(en ? 'tr' : 'en'),
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0x7F101C30),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x556D82A8)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          en ? 'EN' : 'TR',
          style: const TextStyle(
            color: Color(0xFFF8FAFC),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }

  Widget _modeButton({
    required String label,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE6B55A), Color(0xFF7B5E2A)],
                  )
                : null,
            color: selected ? null : const Color(0x1F000000),
            border: Border.all(
              color: selected
                  ? const Color(0x88FFE6AA)
                  : const Color(0x335E759A),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected
                  ? const Color(0xFF111827)
                  : const Color(0xFFD1D9E8),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
