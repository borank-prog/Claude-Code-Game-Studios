import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/game_state.dart';
import '../widgets/game_background.dart';
import '../widgets/glass_panel.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const List<_LegalSection> _privacySections = [
    _LegalSection(
      titleTr: '1) Toplanan Veriler',
      titleEn: '1) Data We Collect',
      bodyTr:
          'Hesap oluşturma ve oyun hizmeti için oyuncu kimliği (UID), e-posta (varsa), oyuncu adı, karakter seçimi, oyun ilerlemesi, ekipman/veri kayıtları, cihazın teknik bilgileri (uygulama sürümü, hata kayıtları) ve bildirim izni verildiğinde FCM bildirimi anahtarı işlenebilir.',
      bodyEn:
          'To provide account and gameplay services, we may process player ID (UID), email (if provided), player name, character selection, game progress, inventory/equipment records, technical device info (app version, crash logs), and FCM notification token when notifications are enabled.',
    ),
    _LegalSection(
      titleTr: '2) Verilerin Kullanım Amaçları',
      titleEn: '2) Why We Use Data',
      bodyTr:
          'Veriler; giriş doğrulama, bulut kayıt senkronizasyonu, oyun ekonomisi ve PvP hesaplamaları, hile/istismar tespiti, müşteri desteği ve hizmet güvenliğini sağlamak için kullanılır.',
      bodyEn:
          'Data is used for authentication, cloud-save sync, game economy and PvP calculations, abuse/fraud prevention, customer support, and service security.',
    ),
    _LegalSection(
      titleTr: '3) Saklama Süresi',
      titleEn: '3) Retention',
      bodyTr:
          'Hesap verileri hesabın aktif kaldığı süre boyunca saklanır. Yasal zorunluluk bulunmayan veriler, hesap silme talebinden sonra makul süre içinde silinir veya anonimleştirilir.',
      bodyEn:
          'Account data is retained while your account is active. Data not required by law is deleted or anonymized within a reasonable period after an account deletion request.',
    ),
    _LegalSection(
      titleTr: '4) Üçüncü Taraf Hizmetler',
      titleEn: '4) Third-Party Services',
      bodyTr:
          'Altyapıda Firebase/Google Cloud gibi hizmet sağlayıcılar kullanılabilir. Bu sağlayıcılar verileri yalnızca hizmet sunumu amacıyla ve kendi güvenlik standartları çerçevesinde işler.',
      bodyEn:
          'Infrastructure providers such as Firebase/Google Cloud may be used. These providers process data only for service delivery and under their own security standards.',
    ),
    _LegalSection(
      titleTr: '5) Güvenlik',
      titleEn: '5) Security',
      bodyTr:
          'Veri güvenliği için erişim kontrolleri, kimlik doğrulama ve kayıt denetimleri uygulanır. Buna rağmen internet üzerinden hiçbir iletim yönteminin yüzde 100 güvenli olduğu garanti edilemez.',
      bodyEn:
          'We apply access controls, authentication, and logging safeguards. However, no internet transmission method can be guaranteed as 100% secure.',
    ),
    _LegalSection(
      titleTr: '6) Çocukların Gizliliği',
      titleEn: "6) Children's Privacy",
      bodyTr:
          'Uygulama ebeveyn gözetimi olmadan küçük yaştaki çocuklara yönelik tasarlanmamıştır. Yerel mevzuata göre gerekli durumlarda ebeveyn/onay sorumluluğu kullanıcıdadır.',
      bodyEn:
          'The app is not designed for unsupervised young children. Where required by local law, parental consent/supervision is the responsibility of the user.',
    ),
    _LegalSection(
      titleTr: '7) Haklarınız',
      titleEn: '7) Your Rights',
      bodyTr:
          'Hesap verilerine erişim, düzeltme ve silme taleplerini uygulama içi hesap silme seçeneği veya destek kanalı üzerinden iletebilirsiniz.',
      bodyEn:
          'You may request access, correction, or deletion of your account data via in-app account deletion tools or the support channel.',
    ),
    _LegalSection(
      titleTr: '8) İletişim',
      titleEn: '8) Contact',
      bodyTr: 'Gizlilikle ilgili talepler için: support@cartelhood.game',
      bodyEn: 'For privacy-related requests: support@cartelhood.game',
    ),
  ];

  static const List<_LegalSection> _termsSections = [
    _LegalSection(
      titleTr: '1) Kabul',
      titleEn: '1) Acceptance',
      bodyTr:
          'Uygulamayı indirerek, kurarak veya kullanarak bu Kullanım Koşullarını kabul etmiş olursunuz. Koşulları kabul etmiyorsanız hizmeti kullanmamalısınız.',
      bodyEn:
          'By downloading, installing, or using the app, you accept these Terms of Use. If you do not accept them, you should not use the service.',
    ),
    _LegalSection(
      titleTr: '2) Hesap Sorumluluğu',
      titleEn: '2) Account Responsibility',
      bodyTr:
          'Hesabınızdan yapılan işlemlerden siz sorumlusunuz. Giriş bilgilerinizin güvenliğini korumalı, şüpheli erişimleri destek ekibine bildirmelisiniz.',
      bodyEn:
          'You are responsible for activity under your account. You must protect your credentials and report suspicious access to support.',
    ),
    _LegalSection(
      titleTr: '3) Oyun İçi Para ve Eşyalar',
      titleEn: '3) Virtual Currency & Items',
      bodyTr:
          'Altın, nakit ve dijital eşyalar yalnızca oyun içi kullanım lisansı sağlar; gerçek dünyada parasal değer taşımaz. Oyun dengesi kapsamında içerikler değiştirilebilir.',
      bodyEn:
          'Gold, cash, and virtual items grant an in-game usage license only and have no real-world monetary value. Content may be changed for game balance.',
    ),
    _LegalSection(
      titleTr: '4) Yasaklı Davranışlar',
      titleEn: '4) Prohibited Conduct',
      bodyTr:
          'Hile, bot kullanımı, açık istismarı, yetkisiz yazılım, nefret söylemi, tehdit veya diğer oyuncuları rahatsız eden davranışlar yasaktır.',
      bodyEn:
          'Cheating, bots, exploit abuse, unauthorized software, hate speech, threats, or player harassment are prohibited.',
    ),
    _LegalSection(
      titleTr: '5) Yaptırımlar',
      titleEn: '5) Enforcement',
      bodyTr:
          'Kural ihlallerinde uyarı, geçici kısıtlama, veri geri alma, eşleşme engeli veya kalıcı hesap kapatma uygulanabilir.',
      bodyEn:
          'Violations may result in warnings, temporary restrictions, rollbacks, matchmaking blocks, or permanent account termination.',
    ),
    _LegalSection(
      titleTr: '6) Hizmet Değişikliği',
      titleEn: '6) Service Changes',
      bodyTr:
          'Hizmet, bakım veya teknik gereksinimler nedeniyle geçici olarak kesilebilir. Özellikler, görevler, ekonomi ve denge ayarları güncellemelerle değiştirilebilir.',
      bodyEn:
          'Service may be temporarily interrupted for maintenance or technical reasons. Features, missions, economy, and balance may change via updates.',
    ),
    _LegalSection(
      titleTr: '7) Fikri Mülkiyet',
      titleEn: '7) Intellectual Property',
      bodyTr:
          'Uygulama içindeki marka, görsel, metin, kod ve tasarımlar hak sahiplerine aittir. İzinsiz kopyalama, dağıtım veya tersine mühendislik yapılamaz.',
      bodyEn:
          'All trademarks, visuals, text, code, and designs in the app belong to their respective owners. Unauthorized copying, distribution, or reverse engineering is prohibited.',
    ),
    _LegalSection(
      titleTr: '8) Sorumluluk Sınırı',
      titleEn: '8) Limitation of Liability',
      bodyTr:
          'Uygulama mevcut haliyle sunulur. Hukukun izin verdiği ölçüde, dolaylı zararlar ve veri kaybı dahil olmak üzere sonuçlardan geliştirici sorumlu tutulamaz.',
      bodyEn:
          'The app is provided "as is." To the extent permitted by law, the developer is not liable for indirect damages, including data loss.',
    ),
    _LegalSection(
      titleTr: '9) İletişim',
      titleEn: '9) Contact',
      bodyTr: 'Kullanım koşulları hakkında: support@cartelhood.game',
      bodyEn: 'For terms-related questions: support@cartelhood.game',
    ),
  ];

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

  Future<void> _showLegalDoc(
    BuildContext context,
    GameState state, {
    required bool privacy,
  }) async {
    final title = privacy
        ? state.tt('Gizlilik Politikası', 'Privacy Policy')
        : state.tt('Kullanım Koşulları', 'Terms of Use');
    final sections = privacy ? _privacySections : _termsSections;
    final updatedAt = state.tt(
      'Son Güncelleme: 31 Mart 2026',
      'Last Updated: March 31, 2026',
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0F1E35),
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.84,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFFFBBF24),
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close, color: Color(0xFFD1D5DB)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0x223B82F6)),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        updatedAt,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...sections.map((s) {
                        final sectionTitle = state.tt(s.titleTr, s.titleEn);
                        final sectionBody = state.tt(s.bodyTr, s.bodyEn);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sectionTitle,
                                style: const TextStyle(
                                  color: Color(0xFFE5E7EB),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                sectionBody,
                                style: const TextStyle(
                                  color: Color(0xFFCBD5E1),
                                  height: 1.35,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFBBF24),
                      foregroundColor: const Color(0xFF0B1220),
                    ),
                    child: Text(state.tt('Kapat', 'Close')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                        leading: const Icon(
                          Icons.link,
                          color: Color(0xFFD1D5DB),
                        ),
                        title: Text(state.tt('Profili Bağla', 'Link Profile')),
                        subtitle: Text(
                          state.tt(
                            'İlerlemeni Google/E-posta hesabına bağla.',
                            'Link your progress to Google/Email.',
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
                          state.tt(
                            'Ses Efektleri (SFX)',
                            'Sound Effects (SFX)',
                          ),
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
                            _showLegalDoc(context, state, privacy: true),
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
                            _showLegalDoc(context, state, privacy: false),
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

class _LegalSection {
  const _LegalSection({
    required this.titleTr,
    required this.titleEn,
    required this.bodyTr,
    required this.bodyEn,
  });

  final String titleTr;
  final String titleEn;
  final String bodyTr;
  final String bodyEn;
}
