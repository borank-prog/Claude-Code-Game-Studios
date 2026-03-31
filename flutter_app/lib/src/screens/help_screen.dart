import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/weapon_matchup_service.dart';
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

  List<_MatchType> _weaponTypes(GameState state) {
    return [
      _MatchType(label: state.tt('Yakın', 'Melee'), weaponId: 'pala'),
      _MatchType(label: state.tt('Tabanca', 'Pistol'), weaponId: 'altipatlar'),
      _MatchType(label: 'SMG', weaponId: 'uzi'),
      _MatchType(label: state.tt('Pompalı', 'Shotgun'), weaponId: 'pompali'),
      _MatchType(label: state.tt('Tüfek', 'Rifle'), weaponId: 'ak47'),
      _MatchType(
        label: state.tt('Keskin', 'Sniper'),
        weaponId: 'keskin_nisanci',
      ),
      _MatchType(
        label: state.tt('Patlayıcı', 'Explosive'),
        weaponId: 'roketatar',
      ),
    ];
  }

  Color _cellColor(int pct) {
    if (pct > 0) return const Color(0xFF34D399);
    if (pct < 0) return const Color(0xFFFB7185);
    return const Color(0xFF94A3B8);
  }

  String _fmtPct(int value) {
    if (value > 0) return '+$value';
    return '$value';
  }

  Widget _matchupMatrix(BuildContext context, GameState state) {
    final types = _weaponTypes(state);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.tt(
              'ÇAPRAZ TABLO (Silah vs Silah)',
              'MATCHUP MATRIX (Weapon vs Weapon)',
            ),
            style: const TextStyle(
              color: Color(0xFFFBBF24),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            state.tt(
              'Satır saldıran, sütun savunan oyuncudur. Değerler toplam yüzde avantajı gösterir.',
              'Rows are attackers, columns are defenders. Values show total percentage edge.',
            ),
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0x221E3A8A)),
              dataRowMinHeight: 34,
              dataRowMaxHeight: 40,
              horizontalMargin: 10,
              columnSpacing: 14,
              columns: [
                DataColumn(
                  label: Text(
                    state.tt('Saldıran', 'Attacker'),
                    style: const TextStyle(
                      color: Color(0xFFE5E7EB),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ...types.map(
                  (t) => DataColumn(
                    label: Text(
                      t.label,
                      style: const TextStyle(
                        color: Color(0xFFE5E7EB),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
              rows: types.map((attacker) {
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        attacker.label,
                        style: const TextStyle(
                          color: Color(0xFFE5E7EB),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    ...types.map((defender) {
                      final fx = WeaponMatchupService.evaluate(
                        attackerWeaponId: attacker.weaponId,
                        targetWeaponId: defender.weaponId,
                      );
                      return DataCell(
                        Text(
                          _fmtPct(fx.totalPct),
                          style: TextStyle(
                            color: _cellColor(fx.totalPct),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              Text(
                state.tt('Yeşil: avantaj', 'Green: advantage'),
                style: const TextStyle(color: Color(0xFF34D399), fontSize: 12),
              ),
              Text(
                state.tt('Kırmızı: dezavantaj', 'Red: disadvantage'),
                style: const TextStyle(color: Color(0xFFFB7185), fontSize: 12),
              ),
              Text(
                state.tt('Gri: nötr', 'Gray: neutral'),
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
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
                      'Sokakların kuralları: hızlı öğren, doğru ekipmanı kuşan, doğru hedefi seç.',
                      'Street rules: learn fast, equip smart, choose targets wisely.',
                    ),
                    style: const TextStyle(color: Color(0xFFD1D5DB)),
                  ),
                ),
                const SizedBox(height: 10),
                _matchupMatrix(context, state),
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
                          'Enerji: Saldırı/görev için harcanır. Enerji bitince saldırı yapamazsın.',
                          'Can ve enerji zamanla yenilenir; premium servisler anında toparlar.',
                        ],
                        bulletsEn: const [
                          'HP (TP) drops in fights. At 0 you are hospitalized.',
                          'Energy is consumed by actions. No energy means no attacks.',
                          'HP/Energy regenerate over time; premium services recover instantly.',
                        ],
                      ),
                      _section(
                        context,
                        titleTr: '⚔️ Çapraz Sistem Nasıl Çalışır?',
                        titleEn: '⚔️ How the Matchup System Works',
                        bulletsTr: const [
                          'Toplam etki = Silah etkisi + Yakın dövüş etkisi + Zırh/araç etkisi.',
                          'Silah etkisi: güç ve hız farkını birlikte hesaplar.',
                          'Zırh ve araç, karşı tarafın delme gücüne göre avantaj/dezavantaj üretir.',
                          'Sonuç yüzdesi yüksekse aynı güçte rakibe karşı daha çok kazanırsın.',
                        ],
                        bulletsEn: const [
                          'Total effect = Weapon edge + Melee edge + Armor/vehicle edge.',
                          'Weapon edge combines power and speed differences.',
                          'Armor and vehicle modify outcomes against penetration/mobility.',
                          'Higher total edge means better odds versus equal-power targets.',
                        ],
                      ),
                      _section(
                        context,
                        titleTr: '🛡️ Zırh ve Araç İpuçları',
                        titleEn: '🛡️ Armor & Vehicle Tips',
                        bulletsTr: const [
                          'Ağır zırh yüksek hasarı emer ama hızlı rakiplere karşı tek başına yetmeyebilir.',
                          'Araç mobilitesi saldırı temposunu ve pozisyon üstünlüğünü etkiler.',
                          'Silah + zırh + araç kombinasyonunu rakibe göre değiştirmen en iyi stratejidir.',
                        ],
                        bulletsEn: const [
                          'Heavy armor absorbs damage but may not be enough against fast builds.',
                          'Vehicle mobility affects combat tempo and positioning edge.',
                          'Best strategy is adapting weapon + armor + vehicle by target.',
                        ],
                      ),
                      _section(
                        context,
                        titleTr: '🏢 Şehir Haritası (PvE Görevler)',
                        titleEn: '🏢 City Map (PvE Missions)',
                        bulletsTr: const [
                          'Görevler enerji harcar ve nakit/XP kazandırır.',
                          'Kolay/Orta/Zor seviyelerinde risk ve ödül artar.',
                          'Hapis/hastane durumunda görev başlatılamaz.',
                        ],
                        bulletsEn: const [
                          'Missions consume energy and reward cash/XP.',
                          'Risk and rewards scale with Easy/Medium/Hard.',
                          'You cannot start missions while jailed/hospitalized.',
                        ],
                      ),
                      _section(
                        context,
                        titleTr: '🤝 Kartel (Çete Sistemi)',
                        titleEn: '🤝 Cartel (Gang System)',
                        bulletsTr: const [
                          'Çete kurabilir veya çeteye katılabilirsin.',
                          'Bağışlarla çete kasası ve saygınlık büyür.',
                          'Çete gücü, üyelerin toplam gücünden hesaplanır.',
                        ],
                        bulletsEn: const [
                          'You can create or join a gang.',
                          'Donations grow gang vault and respect.',
                          'Gang power is the sum of member powers.',
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

class _MatchType {
  const _MatchType({required this.label, required this.weaponId});

  final String label;
  final String weaponId;
}
