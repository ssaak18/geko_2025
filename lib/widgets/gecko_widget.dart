import 'package:flutter/material.dart';
import 'dart:math';

class GeckoWidget extends StatelessWidget {
  final AnimationController controller;
  final AnimationController tongueController;

  const GeckoWidget({
    super.key,
    required this.controller,
    required this.tongueController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, tongueController]),
      builder: (context, child) {
        final breathingScale = 1.0 + (sin(controller.value * 2 * pi) * 0.05);
        final showTongue = tongueController.value > 0;
        
        return Transform.scale(
          scale: breathingScale,
          child: SizedBox(
            width: 200,
            height: 150,
            child: Image.asset(
              showTongue 
                ? 'assets/images/gecko_tongue.png'
                : 'assets/images/gecko_normal.png',
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }
}