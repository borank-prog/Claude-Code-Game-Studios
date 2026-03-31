import 'package:flutter/material.dart';

class GameBackground extends StatelessWidget {
  const GameBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/art/backgrounds/game_bg_custom.png',
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (_, _, _) => Container(
            color: const Color(0xFF081428),
          ),
        ),
        Container(color: const Color(0x66020B18)),
        child,
      ],
    );
  }
}
