import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/static_data.dart';
import '../state/game_state.dart';
import '../widgets/game_background.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final TextEditingController _nameCtrl;
  String _selectedAvatarId = StaticData.avatarClasses.first.id;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<GameState>();
    final initialName = state.displayPlayerName;
    _nameCtrl = TextEditingController(
      text: (initialName == 'Oyuncu' || initialName == 'Player')
          ? ''
          : initialName,
    );
    _selectedAvatarId = state.selectedAvatarId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(GameState state) async {
    if (_saving) return;
    final name = _nameCtrl.text.trim();
    if (name.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.tt(
              'İsim en az 3 karakter olmalı.',
              'Name must be at least 3 characters.',
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    await state.completeOnboarding(name: name, avatarId: _selectedAvatarId);
    if (!mounted) return;
    setState(() => _saving = false);
  }

  _AvatarBalanceInfo _avatarBalanceInfo(GameState state, String avatarId) {
    final avatar = StaticData.avatarClasses.firstWhere(
      (a) => a.id == avatarId,
      orElse: () => StaticData.avatarClasses.first,
    );

    final powerDelta = ((avatar.powerMult - 1) * 100).round();
    final successDelta = (avatar.missionSuccessBonus * 100).round();
    final cashDelta = ((avatar.missionCashMult - 1) * 100).round();

    final pros = <String>[];
    final cons = <String>[];

    if (powerDelta > 0) {
      pros.add(
        state.tt('Savaş gücü +%$powerDelta', 'Combat power +$powerDelta%'),
      );
    } else if (powerDelta < 0) {
      cons.add(
        state.tt('Savaş gücü %$powerDelta', 'Combat power $powerDelta%'),
      );
    }

    if (successDelta > 0) {
      pros.add(
        state.tt(
          'Görev başarı şansı +%$successDelta',
          'Mission success chance +$successDelta%',
        ),
      );
    } else if (successDelta < 0) {
      cons.add(
        state.tt(
          'Görev başarı şansı %$successDelta',
          'Mission success chance $successDelta%',
        ),
      );
    }

    if (cashDelta > 0) {
      pros.add(
        state.tt(
          'Görev gelirleri +%$cashDelta',
          'Mission cash rewards +$cashDelta%',
        ),
      );
    } else if (cashDelta < 0) {
      cons.add(
        state.tt(
          'Görev gelirleri %$cashDelta',
          'Mission cash rewards $cashDelta%',
        ),
      );
    }

    if (avatar.id == 'silahsor') {
      pros
        ..clear()
        ..add(
          state.tt(
            'Dengeli başlangıç: tüm alanlarda cezasız.',
            'Balanced start: no penalties across core stats.',
          ),
        );
      cons
        ..clear()
        ..add(state.tt('Özel pasif bonusu yok.', 'No special passive bonus.'));
    }

    if (pros.isEmpty) {
      pros.add(
        state.tt('Belirgin bir güçlü yönü yok.', 'No standout strength.'),
      );
    }
    if (cons.isEmpty) {
      cons.add(
        state.tt('Belirgin bir zayıf yönü yok.', 'No standout weakness.'),
      );
    }

    return _AvatarBalanceInfo(pros: pros, cons: cons);
  }

  Widget _lineItem({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFFD1D5DB),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, state, _) {
        final canChangeAvatar = state.needsOnboarding || state.canChangeAvatar;
        final selectedAvatar = StaticData.avatarClasses.firstWhere(
          (a) => a.id == _selectedAvatarId,
          orElse: () => StaticData.avatarClasses.first,
        );
        final balanceInfo = _avatarBalanceInfo(state, selectedAvatar.id);
        return Scaffold(
          backgroundColor: const Color(0xFF050A16),
          body: SafeArea(
            child: GameBackground(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 520),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xD112213A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFBBF24)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.tt(
                            'Profilini Tamamla',
                            'Complete Your Profile',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          state.tt(
                            'Devam etmek için isim ve karakter seçimi zorunlu.',
                            'Name and character selection are required to continue.',
                          ),
                          style: const TextStyle(color: Color(0xFFD1D5DB)),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _nameCtrl,
                          maxLength: 20,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: state.tt('Oyuncu Adı', 'Player Name'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.tt('Karakter Seç', 'Choose Character'),
                          style: const TextStyle(
                            color: Color(0xFFFBBF24),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (!canChangeAvatar) ...[
                          const SizedBox(height: 4),
                          Text(
                            state.tt(
                              'Karakter seçimi kilitlendi ve değiştirilemez.',
                              'Character selection is locked and cannot be changed.',
                            ),
                            style: const TextStyle(
                              color: Color(0xFFFCA5A5),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final cardWidth = (constraints.maxWidth - 8) / 2;
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: StaticData.avatarClasses.map((c) {
                                final selected = _selectedAvatarId == c.id;
                                return SizedBox(
                                  width: cardWidth,
                                  child: InkWell(
                                    onTap: canChangeAvatar
                                        ? () {
                                            setState(
                                              () => _selectedAvatarId = c.id,
                                            );
                                          }
                                        : null,
                                    borderRadius: BorderRadius.circular(14),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Container(
                                        height: 96,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: selected
                                                ? const Color(0xFFFBBF24)
                                                : const Color(0x557F8EA8),
                                            width: selected ? 2 : 1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          color: const Color(0xFF0E1A30),
                                        ),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Image.asset(
                                              c.portraitAsset,
                                              fit: BoxFit.cover,
                                              alignment: Alignment.topCenter,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                    return Image.asset(
                                                      c.cardAsset,
                                                      fit: BoxFit.cover,
                                                      alignment:
                                                          Alignment.center,
                                                    );
                                                  },
                                            ),
                                            Positioned.fill(
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                    colors: [
                                                      Colors.transparent,
                                                      Colors.transparent,
                                                      const Color(0xCC060C18),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              left: 10,
                                              right: 10,
                                              bottom: 8,
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      c.name,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: selected
                                                            ? const Color(
                                                                0xFFFBBF24,
                                                              )
                                                            : Colors.white,
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                      ),
                                                    ),
                                                  ),
                                                  if (selected)
                                                    const Icon(
                                                      Icons.check_circle,
                                                      size: 18,
                                                      color: Color(0xFFFBBF24),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                          decoration: BoxDecoration(
                            color: const Color(0xBF0D1A2F),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x447F8EA8)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.tt(
                                  '${state.avatarName(selectedAvatar)} Özeti',
                                  '${state.avatarName(selectedAvatar)} Summary',
                                ),
                                style: const TextStyle(
                                  color: Color(0xFFFBBF24),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                state.tt('Avantajlar', 'Pros'),
                                style: const TextStyle(
                                  color: Color(0xFF34D399),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ...balanceInfo.pros.map(
                                (line) => _lineItem(
                                  icon: Icons.add_circle_outline,
                                  color: const Color(0xFF34D399),
                                  text: line,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                state.tt('Dezavantajlar', 'Cons'),
                                style: const TextStyle(
                                  color: Color(0xFFF87171),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ...balanceInfo.cons.map(
                                (line) => _lineItem(
                                  icon: Icons.remove_circle_outline,
                                  color: const Color(0xFFF87171),
                                  text: line,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _saving ? null : () => _submit(state),
                            child: Text(
                              state.tt('Devam Et', 'Continue'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AvatarBalanceInfo {
  const _AvatarBalanceInfo({required this.pros, required this.cons});

  final List<String> pros;
  final List<String> cons;
}
