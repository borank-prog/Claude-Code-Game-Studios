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

  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, state, _) {
        final canChangeAvatar = state.needsOnboarding || state.canChangeAvatar;
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
