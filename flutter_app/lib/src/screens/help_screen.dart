import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/game_state.dart';
import '../widgets/game_background.dart';
import '../widgets/glass_panel.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  Widget _section(
    BuildContext context, {
    required String titleTr,
    required String titleEn,
    required List<String> bulletsTr,
    required List<String> bulletsEn,
  }) {
    final state = context.read<GameState>();
    final title = state.tt(titleTr, titleEn);
    final bullets = state.isEnglish ? bulletsEn : bulletsTr;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFFBBF24),
          fontWeight: FontWeight.w800,
        ),
      ),
      children: bullets
          .map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.circle,
                      size: 7,
                      color: Color(0xFF34D399),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      line,
                      style: const TextStyle(
                        color: Color(0xFFD1D5DB),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, state, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF081428),
          appBar: AppBar(
            title: Text(state.tt('YARDIM / REHBER', 'HELP / GUIDE')),
            backgroundColor: Colors.black87,
          ),
          body: GameBackground(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
              children: [
              GlassPanel(
                child: Text(
                  state.tt(
                    'Sokakların Kuralları: Kısa ve net. Ne yaparsan ne kazanırsın burada.',
                    'Street Rules: Clear and quick. What you do and what you gain.',
                  ),
                  style: const TextStyle(color: Color(0xFFD1D5DB)),
                ),
              ),
              const SizedBox(height: 10),
              GlassPanel(
                child: Column(
                  children: [
                    _section(
                      context,
                      titleTr: '🩸 Temel Durumlar (Can ve Enerji)',
                      titleEn: '🩸 Core Stats (HP & Energy)',
                      bulletsTr: const [
                        'Can (TP): Çatışmalarda düşer. 0 olursa hastanelik olursun.',
                        'Enerji: Saldırı/görev için harcanır. Her saldırı 20 enerji tüketir.',
                        'Can ve enerji zamanla yenilenir; VIP Tedavi/Adrenalin ile anında dolabilir.',
                      ],
                      bulletsEn: const [
                        'HP (TP) drops in fights. At 0 you are hospitalized.',
                        'Energy is consumed by actions. Each attack costs 20 energy.',
                        'HP/Energy regenerate over time or can be instantly restored via premium actions.',
                      ],
                    ),
                    _section(
                      context,
                      titleTr: '⚔️ Sokaklar (PvP)',
                      titleEn: '⚔️ Streets (PvP)',
                      bulletsTr: const [
                        'Savaş hesabı: Toplam Güç + Şans.',
                        'Kazanınca para çalarsın, kaybedince hasar ve para cezası yiyebilirsin.',
                        'Çevrimdışı olsan da savunman çalışır, saldırı kayıtları rapora düşer.',
                      ],
                      bulletsEn: const [
                        'Combat formula: Total Power + Luck.',
                        'Win: steal cash. Lose: take heavy damage and penalties.',
                        'Offline defense is active; battle logs are stored for later.',
                      ],
                    ),
                    _section(
                      context,
                      titleTr: '🏢 Şehir Haritası (PvE Görevler)',
                      titleEn: '🏢 City Map (PvE Missions)',
                      bulletsTr: const [
                        'Görevler enerji harcar ve nakit/XP kazandırır.',
                        'Kolay/Orta/Zor risk seviyeleri farklı ödül ve ceza verir.',
                        'Hapis/hastane durumlarında görev yapılamaz.',
                      ],
                      bulletsEn: const [
                        'Missions consume energy and grant cash/XP.',
                        'Easy/Medium/Hard have different risk/reward.',
                        'You cannot run missions while jailed/hospitalized.',
                      ],
                    ),
                    _section(
                      context,
                      titleTr: '💼 Kara Borsa ve Ekonomi',
                      titleEn: '💼 Black Market & Economy',
                      bulletsTr: const [
                        'Nakit (\$): Görevler ve çatışmalardan kazanılır.',
                        'Altın: Premium para birimi, hızlandırma ve VIP eşya için kullanılır.',
                        'VIP silahlar daha yüksek güç verir; güç farkını belirgin artırır.',
                      ],
                      bulletsEn: const [
                        'Cash (\$): Earned via missions and fights.',
                        'Gold: Premium currency for skips and VIP gear.',
                        'VIP items offer larger power spikes.',
                      ],
                    ),
                    _section(
                      context,
                      titleTr: '🤝 Kartel (Çete Sistemi)',
                      titleEn: '🤝 Cartel (Gang System)',
                      bulletsTr: const [
                        'Çete kurabilir veya bir çeteye katılabilirsin.',
                        'Bağış yaparak çete kasasını/saygınlığı büyütürsün.',
                        'Çete gücü, üye güçlerinin toplamından oluşur.',
                      ],
                      bulletsEn: const [
                        'Create or join a gang.',
                        'Donations increase gang vault/respect.',
                        'Gang power is the sum of member powers.',
                      ],
                    ),
                    _section(
                      context,
                      titleTr: '🎭 Sınıflar ve Avantajlar',
                      titleEn: '🎭 Classes & Perks',
                      bulletsTr: const [
                        'Fırsatçı: Görev kazançlarında avantajlı.',
                        'Silahşör: Silah ekipmanından daha iyi verim alır.',
                        'Zorba: Daha yüksek dayanıklılık/TP ile öne çıkar.',
                        'Baron/Baba: Çete yönetiminde ve ekonomi döngüsünde avantajlıdır.',
                      ],
                      bulletsEn: const [
                        'Opportunist: Better mission income efficiency.',
                        'Gunslinger: Better gains from weapon equipment.',
                        'Brute: Higher survivability/HP.',
                        'Baron/Boss: Better gang/economy utility.',
                      ],
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
