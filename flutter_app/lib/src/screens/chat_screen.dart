import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/game_state.dart';
import '../widgets/glass_panel.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, state, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
          children: [
            GlassPanel(
              child: Text(
                state.tt('ŞEHİR TELSİZİ', 'CITY RADIO'),
                style: TextStyle(
                  color: Color(0xFFFBBF24),
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...state.news
                .take(30)
                .map(
                  (line) => GlassPanel(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      line,
                      style: const TextStyle(color: Color(0xFFD1D5DB)),
                    ),
                  ),
                ),
            if (state.news.isEmpty)
              GlassPanel(
                child: Text(
                  state.tt('Henüz yayın yok.', 'No broadcasts yet.'),
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
          ],
        );
      },
    );
  }
}
