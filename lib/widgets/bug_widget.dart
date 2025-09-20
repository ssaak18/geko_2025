import 'package:flutter/material.dart';
import 'dart:math';

class BugWidget extends StatefulWidget {
  final String suggestion;
  final VoidCallback onTap;

  const BugWidget({
    super.key,
    required this.suggestion,
    required this.onTap,
  });

  @override
  State<BugWidget> createState() => _BugWidgetState();
}

class _BugWidgetState extends State<BugWidget> with TickerProviderStateMixin {
  late AnimationController _wiggleController;
  late AnimationController _scaleController;
  bool _isBeingEaten = false;

  @override
  void initState() {
    super.initState();
    _wiggleController = AnimationController(
      duration: Duration(milliseconds: 1000 + Random().nextInt(500)),
      vsync: this,
    )..repeat(reverse: true);
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _wiggleController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTap() async {
    setState(() => _isBeingEaten = true);
    
    // Scale up then down (being eaten effect)
    await _scaleController.forward();
    await _scaleController.reverse();
    
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_wiggleController, _scaleController]),
      builder: (context, child) {
        final wiggleOffset = sin(_wiggleController.value * 2 * pi) * 1.5;
        final scale = _isBeingEaten 
            ? 1.0 - _scaleController.value 
            : 1.0 + (_scaleController.value * 0.1);
        
        return Transform.translate(
          offset: Offset(wiggleOffset, -wiggleOffset.abs() * 0.5),
          child: Transform.scale(
            scale: scale,
            child: GestureDetector(
              onTap: _isBeingEaten ? null : _handleTap,
              child: SizedBox(
                width: 130,
                height: 150,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Bigger worm image
                    Container(
                      width: 90,
                      height: 90,
                      child: Image.asset(
                        'assets/images/worm.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Suggestion text without border
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        widget.suggestion,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          fontFamily: 'Comic Sans MS',
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getBugColor() {
    final colors = [
      const Color(0xFFE57373), // Coral red like gecko spots
      const Color(0xFF81C784), // Light green
      const Color(0xFF64B5F6), // Light blue  
      const Color(0xFFFFB74D), // Orange
      const Color(0xFFBA68C8), // Purple
      const Color(0xFF4DB6AC), // Teal
    ];
    return colors[widget.suggestion.hashCode % colors.length];
  }
}

class ModernBugPainter extends CustomPainter {
  final Color color;

  ModernBugPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Bug body - rounded rectangle like the gecko style
    paint.color = color;
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.6),
        width: size.width * 0.5,
        height: size.height * 0.6,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(bodyRect, paint);

    // Bug head - smaller rounded rectangle
    paint.color = color;
    final headRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.3),
        width: size.width * 0.35,
        height: size.height * 0.25,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(headRect, paint);

    // Body spots - small geometric shapes
    paint.color = Colors.white.withOpacity(0.8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width * 0.45, size.height * 0.55),
          width: 4,
          height: 4,
        ),
        const Radius.circular(2),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width * 0.55, size.height * 0.65),
          width: 4,
          height: 4,
        ),
        const Radius.circular(2),
      ),
      paint,
    );

    // Eyes - small white ovals
    paint.color = Colors.white;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.42, size.height * 0.28),
        width: 4,
        height: 5,
      ),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.58, size.height * 0.28),
        width: 4,
        height: 5,
      ),
      paint,
    );

    // Eye pupils - tiny black dots
    paint.color = Colors.black;
    canvas.drawCircle(Offset(size.width * 0.42, size.height * 0.28), 1, paint);
    canvas.drawCircle(Offset(size.width * 0.58, size.height * 0.28), 1, paint);

    // Antennae - simple rounded lines
    paint.strokeWidth = 1.5;
    paint.style = PaintingStyle.stroke;
    paint.strokeCap = StrokeCap.round;
    paint.color = color;
    
    canvas.drawLine(
      Offset(size.width * 0.4, size.height * 0.2),
      Offset(size.width * 0.35, size.height * 0.1),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.6, size.height * 0.2),
      Offset(size.width * 0.65, size.height * 0.1),
      paint,
    );

    // Antenna tips
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.1), 1.5, paint);
    canvas.drawCircle(Offset(size.width * 0.65, size.height * 0.1), 1.5, paint);

    // Wings - rounded rectangles with transparency
    paint.color = color.withOpacity(0.4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width * 0.35, size.height * 0.5),
          width: size.width * 0.2,
          height: size.height * 0.3,
        ),
        const Radius.circular(4),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width * 0.65, size.height * 0.5),
          width: size.width * 0.2,
          height: size.height * 0.3,
        ),
        const Radius.circular(4),
      ),
      paint,
    );

    // Legs - simple rounded rectangles
    paint.color = color;
    paint.style = PaintingStyle.fill;
    
    // Left legs
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width * 0.25, size.height * 0.7),
          width: 8,
          height: 2,
        ),
        const Radius.circular(1),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width * 0.2, size.height * 0.8),
          width: 8,
          height: 2,
        ),
        const Radius.circular(1),
      ),
      paint,
    );
    
    // Right legs
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width * 0.75, size.height * 0.7),
          width: 8,
          height: 2,
        ),
        const Radius.circular(1),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width * 0.8, size.height * 0.8),
          width: 8,
          height: 2,
        ),
        const Radius.circular(1),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}