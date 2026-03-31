import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/game_state.dart';
import '../widgets/game_background.dart';
import '../widgets/glass_panel.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Widget _metalLanguageSwitch(GameState state) {
    Widget langBtn(String code, String label) {
      final active = state.languageCode == code;
      return Expanded(
        child: GestureDetector(
          onTap: () => state.setLanguage(code),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 7),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              gradient: active
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFF7E08D),
                        Color(0xFFD4AF37),
                        Color(0xFF9B7A21),
                      ],
                    )
                  : const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF2A3A57), Color(0xFF17243B)],
                    ),
              border: Border.all(
                color: active
                    ? const Color(0xFFFDE68A)
                    : const Color(0x668CA0BF),
              ),
              boxShadow: [
                BoxShadow(
                  color: active
                      ? const Color(0x66B8860B)
                      : const Color(0x55000000),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                color: active
                    ? const Color(0xFF0B1220)
                    : const Color(0xFFD1D5DB),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 128,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4A5261), Color(0xFF1A1F2A)],
        ),
        border: Border.all(color: const Color(0xFF8D95A3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          langBtn('tr', 'TR'),
          const SizedBox(width: 5),
          langBtn('en', 'EN'),
        ],
      ),
    );
  }

  Future<void> _renameDialog(BuildContext context, GameState state) async {
    final ctrl = TextEditingController(text: state.playerName);
    final msg = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13233E),
        title: Text(state.tt('İsim Değiştir', 'Rename')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: state.tt('Yeni isim', 'New name'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(state.tt('Vazgeç', 'Cancel')),
          ),
          FilledButton(
            onPressed: () async {
              final result = await state.renamePlayer(ctrl.text);
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop(result);
            },
            child: Text(state.tt('Kaydet', 'Save')),
          ),
        ],
      ),
    );
    if (msg != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    GameState state,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13233E),
        title: Text(state.tt('Hesabı Sil', 'Delete Account')),
        content: Text(
          state.tt(
            'Bu işlem geri alınamaz. Devam etmek istiyor musun?',
            'This action cannot be undone. Continue?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(state.tt('Vazgeç', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: Text(state.tt('Sil', 'Delete')),
          ),
        ],
      ),
    );

    if (ok != true || !context.mounted) return;
    final msg = await state.deleteLinkedAccount();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    if (!state.loggedIn && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  void _showLink(BuildContext context, String link) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(link)));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, state, _) {
        final canDelete = state.authMode == 'firebase' && state.loggedIn;
        final renameCostText = state.nameChangeCount == 0
            ? state.tt('İlk değişim ücretsiz', 'First rename is free')
            : state.tt('Sonraki değişim: 50 Altın', 'Next rename: 50 Gold');

        return Scaffold(
          backgroundColor: const Color(0xFF081428),
          appBar: AppBar(
            title: Text(state.tt('AYARLAR', 'SETTINGS')),
            backgroundColor: Colors.black87,
          ),
          body: GameBackground(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
              children: [
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.tt('HESAP YÖNETİMİ', 'ACCOUNT'),
                      style: const TextStyle(
                        color: Color(0xFFFBBF24),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.link, color: Color(0xFFD1D5DB)),
                      title: Text(state.tt('Profili Bağla', 'Link Profile')),
                      subtitle: Text(
                        state.tt(
                          'Misafir ilerlemesini Google/E-posta hesabına bağla.',
                          'Link guest progress to Google/Email.',
                        ),
                      ),
                      onTap: () async {
                        await state.logout();
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.badge_outlined,
                        color: Color(0xFFD1D5DB),
                      ),
                      title: Text(state.tt('İsim Değiştir', 'Rename')),
                      subtitle: Text(renameCostText),
                      onTap: () => _renameDialog(context, state),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.logout,
                        color: Color(0xFFD1D5DB),
                      ),
                      title: Text(state.tt('Çıkış Yap', 'Log Out')),
                      onTap: () async {
                        await state.logout();
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.delete_forever,
                        color: Color(0xFFEF4444),
                      ),
                      title: Text(
                        state.tt('Hesabı Sil', 'Delete Account'),
                        style: const TextStyle(color: Color(0xFFEF4444)),
                      ),
                      subtitle: Text(
                        canDelete
                            ? state.tt(
                                'Mağaza gereği hesap silme butonu.',
                                'Required account deletion control.',
                              )
                            : state.tt(
                                'Sadece bağlı hesaplarda aktif.',
                                'Only available for linked accounts.',
                              ),
                      ),
                      onTap: canDelete
                          ? () => _confirmDeleteAccount(context, state)
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.tt('SES VE MÜZİK', 'AUDIO'),
                      style: const TextStyle(
                        color: Color(0xFFFBBF24),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SwitchListTile(
                      value: state.musicEnabled,
                      title: Text(
                        state.tt('Arka Plan Müziği', 'Background Music'),
                      ),
                      onChanged: (v) => state.setMusicEnabled(v),
                    ),
                    SwitchListTile(
                      value: state.sfxEnabled,
                      title: Text(
                        state.tt('Ses Efektleri (SFX)', 'Sound Effects (SFX)'),
                      ),
                      onChanged: (v) => state.setSfxEnabled(v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.tt('BİLDİRİMLER', 'NOTIFICATIONS'),
                      style: const TextStyle(
                        color: Color(0xFFFBBF24),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SwitchListTile(
                      value: state.notifyEnergyFull,
                      title: Text(
                        state.tt(
                          'Enerji dolduğunda bildir',
                          'Notify when energy is full',
                        ),
                      ),
                      onChanged: (v) => state.setNotifyEnergyFull(v),
                    ),
                    SwitchListTile(
                      value: state.notifyHospitalReady,
                      title: Text(
                        state.tt(
                          'Hastaneden çıkınca bildir',
                          'Notify when hospital timer ends',
                        ),
                      ),
                      onChanged: (v) => state.setNotifyHospitalReady(v),
                    ),
                    SwitchListTile(
                      value: state.notifyUnderAttack,
                      title: Text(
                        state.tt(
                          'Saldırı aldığımda bildir',
                          'Notify when attacked',
                        ),
                      ),
                      onChanged: (v) => state.setNotifyUnderAttack(v),
                    ),
                    SwitchListTile(
                      value: state.notifyGangMessages,
                      title: Text(
                        state.tt(
                          'Çete mesajlarını bildir',
                          'Notify gang messages',
                        ),
                      ),
                      onChanged: (v) => state.setNotifyGangMessages(v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.tt('DİĞER', 'OTHER'),
                      style: const TextStyle(
                        color: Color(0xFFFBBF24),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.language,
                        color: Color(0xFFD1D5DB),
                      ),
                      title: Text(state.tt('Dil Seçimi', 'Language')),
                      subtitle: Text(state.isEnglish ? 'English' : 'Türkçe'),
                      trailing: _metalLanguageSwitch(state),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.privacy_tip_outlined,
                        color: Color(0xFFD1D5DB),
                      ),
                      title: Text(
                        state.tt('Gizlilik Politikası', 'Privacy Policy'),
                      ),
                      onTap: () =>
                          _showLink(context, 'https://example.com/privacy'),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.description_outlined,
                        color: Color(0xFFD1D5DB),
                      ),
                      title: Text(
                        state.tt('Kullanım Koşulları', 'Terms of Use'),
                      ),
                      onTap: () =>
                          _showLink(context, 'https://example.com/terms'),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.support_agent,
                        color: Color(0xFFD1D5DB),
                      ),
                      title: Text(state.tt('Müşteri Hizmetleri', 'Support')),
                      subtitle: const Text('support@cartelhood.game'),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        state.tt('Sürüm: v1.0.0', 'Version: v1.0.0'),
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ],
            ),
          ),
        );
      },
    );
  }
}
