import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'narration_service.dart';

enum GuideStageType {
  luggage,
  tawaf,
  say,
  ihram,
  cemarat,
}

/// An interactive, visually rich animated stage shown above guide sections.
/// Allows pilgrims to watch the real-time simulation (luggage packing, Kaaba tawaf,
/// Safa-Marwa sa'y, etc.) synchronized with narration and persistent steps below.
class GuideStageAnimator extends StatefulWidget {
  const GuideStageAnimator({
    super.key,
    required this.stageType,
    required this.items,
    this.initialIndex = 0,
    this.onItemChanged,
    this.audioAsset,
    this.audioTitle,
    this.narration,
  });

  final GuideStageType stageType;
  final List<String> items;
  final int initialIndex;
  final ValueChanged<int>? onItemChanged;
  final String? audioAsset;
  final String? audioTitle;
  final NarrationService? narration;

  @override
  State<GuideStageAnimator> createState() => GuideStageAnimatorState();
}

class GuideStageAnimatorState extends State<GuideStageAnimator>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late final AnimationController _animController;
  bool _isAutoPlaying = false;
  NarrationService? get _narration => widget.narration;

  int get currentIndex => _currentIndex;

  bool get _isTesting =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(
      0,
      math.max(0, widget.items.length - 1),
    );
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_isAutoPlaying) {
          if (_currentIndex < widget.items.length - 1) {
            selectItem(_currentIndex + 1);
            _animController.forward(from: 0.0);
          } else {
            setState(() => _isAutoPlaying = false);
          }
        } else if (!_isTesting) {
          _animController.repeat();
        }
      }
    });

    if (!_isTesting) {
      _animController.repeat();
    }
    _narration?.addListener(_onNarrationUpdate);
  }

  @override
  void didUpdateWidget(covariant GuideStageAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex &&
        widget.initialIndex != _currentIndex) {
      selectItem(widget.initialIndex);
    }
  }

  @override
  void dispose() {
    _narration?.removeListener(_onNarrationUpdate);
    _animController.dispose();
    super.dispose();
  }

  void _onNarrationUpdate() {
    final narration = _narration;
    if (!mounted || narration == null || widget.audioAsset == null) return;
    final state = narration.state;
    final isMyAudioPlaying = state.asset == widget.audioAsset &&
        state.status == NarrationStatus.playing;
    if (isMyAudioPlaying && !_isAutoPlaying) {
      setState(() => _isAutoPlaying = true);
      if (!_animController.isAnimating) {
        _animController.forward(from: 0.0);
      }
    } else if (!isMyAudioPlaying && _isAutoPlaying && state.status != NarrationStatus.paused) {
      setState(() => _isAutoPlaying = false);
    }
  }

  void selectItem(int index) {
    if (widget.items.isEmpty) return;
    final newIndex = index.clamp(0, widget.items.length - 1);
    if (newIndex != _currentIndex) {
      setState(() {
        _currentIndex = newIndex;
      });
      widget.onItemChanged?.call(_currentIndex);
      _animController.forward(from: 0.0);
    }
  }

  void _stepPrevious() {
    if (_currentIndex > 0) {
      selectItem(_currentIndex - 1);
    }
  }

  void _stepNext() {
    if (_currentIndex < widget.items.length - 1) {
      selectItem(_currentIndex + 1);
    }
  }

  Future<void> _togglePlayback() async {
    final narration = _narration;
    if (widget.audioAsset != null && narration != null) {
      final state = narration.state;
      if (state.asset == widget.audioAsset &&
          state.status == NarrationStatus.playing) {
        await narration.pause();
        setState(() => _isAutoPlaying = false);
      } else if (state.asset == widget.audioAsset &&
          state.status == NarrationStatus.paused) {
        await narration.resume();
        setState(() => _isAutoPlaying = true);
      } else {
        await narration.playAsset(
          widget.audioAsset!,
          title: widget.audioTitle ?? 'Rehber Anlatımı',
        );
        setState(() => _isAutoPlaying = true);
      }
    } else {
      setState(() {
        _isAutoPlaying = !_isAutoPlaying;
        if (_isAutoPlaying) {
          _animController.forward(from: 0.0);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final currentItemText = widget.items.isNotEmpty
        ? widget.items[_currentIndex]
        : '';
    final progressFraction = widget.items.isNotEmpty
        ? (_currentIndex + 1) / widget.items.length
        : 1.0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0D1714) : const Color(0xFF0F2620),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: RehberTheme.emerald.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Stage Viewport
            SizedBox(
              height: 200,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Ambient Canvas Background
                  AnimatedBuilder(
                    animation: _animController,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _buildStagePainter(
                          _animController.value,
                          _currentIndex,
                          progressFraction,
                        ),
                      );
                    },
                  ),

                  // Top Badges
                  Positioned(
                    top: 12,
                    left: 14,
                    right: 14,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: RehberTheme.goldLight.withValues(alpha: 0.4),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _stageIcon(widget.stageType),
                                  size: 14,
                                  color: RehberTheme.goldLight,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _stageTitle(widget.stageType),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: RehberTheme.emerald.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_currentIndex + 1} / ${widget.items.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Center Floating Callout for Active Item
                  Positioned(
                    bottom: 12,
                    left: 14,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: RehberTheme.emerald.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: RehberTheme.emerald.withValues(alpha: 0.25),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              size: 14,
                              color: RehberTheme.goldLight,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              currentItemText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Controls & Progress Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: dark
                    ? const Color(0xFF091210)
                    : const Color(0xFF0B1F1A),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Previous Step
                    IconButton(
                      onPressed: _currentIndex > 0 ? _stepPrevious : null,
                      icon: const Icon(Icons.skip_previous_rounded),
                      color: Colors.white70,
                      disabledColor: Colors.white24,
                      tooltip: 'Önceki',
                      iconSize: 22,
                    ),

                    // Play / Pause Simulation
                    FilledButton.tonal(
                      onPressed: _togglePlayback,
                      style: FilledButton.styleFrom(
                        backgroundColor: RehberTheme.emerald,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isAutoPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isAutoPlaying ? 'Duraklat' : 'Canlı İzle',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Next Step
                    IconButton(
                      onPressed: _currentIndex < widget.items.length - 1
                          ? _stepNext
                          : null,
                      icon: const Icon(Icons.skip_next_rounded),
                      color: Colors.white70,
                      disabledColor: Colors.white24,
                      tooltip: 'Sonraki',
                      iconSize: 22,
                    ),

                    const SizedBox(width: 14),

                    // Progress Dots Indicator
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < widget.items.length; i++)
                          GestureDetector(
                            onTap: () => selectItem(i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(horizontal: 2.5),
                              width: i == _currentIndex ? 16 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: i == _currentIndex
                                    ? RehberTheme.goldLight
                                    : (i < _currentIndex
                                        ? RehberTheme.emerald
                                        : Colors.white24),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  CustomPainter _buildStagePainter(
    double animValue,
    int itemIndex,
    double progress,
  ) {
    switch (widget.stageType) {
      case GuideStageType.luggage:
        return _LuggageStagePainter(
          animValue: animValue,
          itemIndex: itemIndex,
          progress: progress,
        );
      case GuideStageType.tawaf:
        return _TawafStagePainter(
          animValue: animValue,
          shawtIndex: itemIndex,
        );
      case GuideStageType.say:
        return _SayStagePainter(
          animValue: animValue,
          lapIndex: itemIndex,
        );
      case GuideStageType.ihram:
        return _IhramStagePainter(
          animValue: animValue,
          stepIndex: itemIndex,
        );
      case GuideStageType.cemarat:
        return _CemaratStagePainter(
          animValue: animValue,
          targetIndex: itemIndex,
        );
    }
  }

  IconData _stageIcon(GuideStageType type) {
    switch (type) {
      case GuideStageType.luggage:
        return Icons.luggage_rounded;
      case GuideStageType.tawaf:
        return Icons.rotate_left_rounded;
      case GuideStageType.say:
        return Icons.swap_horiz_rounded;
      case GuideStageType.ihram:
        return Icons.accessibility_new_rounded;
      case GuideStageType.cemarat:
        return Icons.location_on_rounded;
    }
  }

  String _stageTitle(GuideStageType type) {
    switch (type) {
      case GuideStageType.luggage:
        return 'Valiz & Hazırlık Simülasyonu';
      case GuideStageType.tawaf:
        return 'Canlı Kâbe Tavaf Simülasyonu';
      case GuideStageType.say:
        return 'Safâ - Merve Sa‘y Yolu';
      case GuideStageType.ihram:
        return 'Mîkāt & İhram Hazırlığı';
      case GuideStageType.cemarat:
        return 'Cemarat (Taşlama) Simülasyonu';
    }
  }
}

// ==========================================
// 1. VALİZ VE HAZIRLIK RESMİ PAINTER'I
// ==========================================
class _LuggageStagePainter extends CustomPainter {
  const _LuggageStagePainter({
    required this.animValue,
    required this.itemIndex,
    required this.progress,
  });

  final double animValue;
  final int itemIndex;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background gradient glow
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.2, 0.2),
        radius: 0.85,
        colors: [
          const Color(0xFF1B4332).withValues(alpha: 0.75),
          const Color(0xFF081C15),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // Grid Floor Perspective Lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;
    for (double x = 0; x < w; x += 35) {
      canvas.drawLine(Offset(x, h * 0.7), Offset(x + (x - w / 2) * 0.4, h), gridPaint);
    }
    canvas.drawLine(Offset(0, h * 0.7), Offset(w, h * 0.7), gridPaint);

    // Draw Traveler (Adam) on Left (x: 55, y: h * 0.45)
    _drawTraveler(canvas, Offset(w * 0.18, h * 0.48), animValue);

    // Draw Open Suitcase on Right (center: w * 0.72, h * 0.52)
    final suitcaseRect = Rect.fromCenter(
      center: Offset(w * 0.68, h * 0.54),
      width: 130,
      height: 85,
    );
    _drawSuitcase(canvas, suitcaseRect, progress);

    // Animated Flying / Floating Item from Traveler to Suitcase
    final startPt = Offset(w * 0.26, h * 0.38);
    final endPt = Offset(w * 0.68, h * 0.48);

    // Parabolic motion curve
    final t = (animValue * 1.5).clamp(0.0, 1.0);
    final curveT = Curves.easeOutCubic.transform(t);
    final currentX = startPt.dx + (endPt.dx - startPt.dx) * curveT;
    final arcHeight = -38 * math.sin(curveT * math.pi);
    final currentY = startPt.dy + (endPt.dy - startPt.dy) * curveT + arcHeight;

    if (t < 0.96) {
      _drawFlyingItem(canvas, Offset(currentX, currentY), itemIndex, animValue);
    } else {
      // Gentle settle bounce inside luggage
      final settleOffset = Offset(
        endPt.dx + (math.sin(animValue * math.pi * 4) * 2),
        endPt.dy + (math.cos(animValue * math.pi * 4) * 2),
      );
      _drawPackSuccessGlow(canvas, settleOffset);
    }
  }

  void _drawTraveler(Canvas canvas, Offset pos, double anim) {
    final headY = pos.dy - 38 + (math.sin(anim * math.pi * 2) * 1.5);
    final bodyPaint = Paint()..color = const Color(0xFFC4E053);
    final skinPaint = Paint()..color = const Color(0xFFFFD1A9);

    // Head
    canvas.drawCircle(Offset(pos.dx, headY), 10, skinPaint);

    // Body (White pilgrim shirt/robe)
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(pos.dx, headY + 22), width: 22, height: 26),
      const Radius.circular(6),
    );
    canvas.drawRRect(bodyRect, bodyPaint);

    // Hand reaching toward suitcase
    final handPaint = Paint()
      ..color = const Color(0xFFFFD1A9)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(pos.dx + 8, headY + 18),
      Offset(pos.dx + 22, headY + 12 - (math.sin(anim * math.pi) * 4)),
      handPaint,
    );
  }

  void _drawSuitcase(Canvas canvas, Rect rect, double fillFraction) {
    // Suitcase Body (Modern Emerald Case)
    final casePaint = Paint()
      ..color = const Color(0xFF2D6A4F)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = RehberTheme.goldLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      casePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      borderPaint,
    );

    // Suitcase Inner Compartment
    final innerRect = rect.deflate(7);
    final innerPaint = Paint()..color = const Color(0xFF1B4332);
    canvas.drawRRect(
      RRect.fromRectAndRadius(innerRect, const Radius.circular(6)),
      innerPaint,
    );

    // Fill level gauge inside suitcase
    if (fillFraction > 0) {
      final fillHeight = innerRect.height * fillFraction;
      final fillRect = Rect.fromLTWH(
        innerRect.left,
        innerRect.bottom - fillHeight,
        innerRect.width,
        fillHeight,
      );
      final fillPaint = Paint()
        ..color = RehberTheme.emerald.withValues(alpha: 0.65);
      canvas.drawRRect(
        RRect.fromRectAndRadius(fillRect, const Radius.circular(5)),
        fillPaint,
      );
    }

    // Straps and Handle
    final handlePaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(rect.center.dx, rect.top - 2),
        width: 26,
        height: 14,
      ),
      math.pi,
      math.pi,
      false,
      handlePaint,
    );

    // Luggage Corner Protectors (Gold)
    final goldCorner = Paint()..color = RehberTheme.goldLight;
    canvas.drawCircle(rect.topLeft + const Offset(5, 5), 3, goldCorner);
    canvas.drawCircle(rect.topRight + const Offset(-5, 5), 3, goldCorner);
    canvas.drawCircle(rect.bottomLeft + const Offset(5, -5), 3, goldCorner);
    canvas.drawCircle(rect.bottomRight + const Offset(-5, -5), 3, goldCorner);
  }

  void _drawFlyingItem(Canvas canvas, Offset pos, int index, double anim) {
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(pos + const Offset(0, 10), 12, shadowPaint);

    final itemBg = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final itemStroke = Paint()
      ..color = RehberTheme.goldLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(pos, 14, itemBg);
    canvas.drawCircle(pos, 14, itemStroke);

    // Draw Iconic Glyphs
    final glyphPaint = Paint()
      ..color = const Color(0xFF1B4332)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    switch (index % 5) {
      case 0: // İhram Kumaşı (Two horizontal layers)
        canvas.drawLine(pos + const Offset(-7, -3), pos + const Offset(7, -3), glyphPaint);
        canvas.drawLine(pos + const Offset(-7, 3), pos + const Offset(7, 3), glyphPaint);
        break;
      case 1: // Kokusuz Sabun / Şişe
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: pos, width: 10, height: 14),
            const Radius.circular(2),
          ),
          glyphPaint,
        );
        break;
      case 2: // Sandalet / Patik
        canvas.drawLine(pos + const Offset(-6, 4), pos + const Offset(6, 4), glyphPaint);
        canvas.drawArc(
          Rect.fromCenter(center: pos + const Offset(0, 1), width: 10, height: 8),
          math.pi,
          math.pi,
          false,
          glyphPaint,
        );
        break;
      case 3: // İlaç / İlk Yardım Artı
        canvas.drawLine(pos + const Offset(0, -6), pos + const Offset(0, 6), glyphPaint);
        canvas.drawLine(pos + const Offset(-6, 0), pos + const Offset(6, 0), glyphPaint);
        break;
      default: // Pasaport / Dua Kitabı
        canvas.drawRect(
          Rect.fromCenter(center: pos, width: 12, height: 15),
          glyphPaint,
        );
        break;
    }
  }

  void _drawPackSuccessGlow(Canvas canvas, Offset pos) {
    final glow = Paint()
      ..color = const Color(0xFF2D6A4F).withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(pos, 16, glow);
  }

  @override
  bool shouldRepaint(covariant _LuggageStagePainter oldDelegate) =>
      oldDelegate.animValue != animValue ||
      oldDelegate.itemIndex != itemIndex ||
      oldDelegate.progress != progress;
}

// ==========================================
// 2. CANLI KÂBE TAVAF SİMÜLASYONU PAINTER'I
// ==========================================
class _TawafStagePainter extends CustomPainter {
  const _TawafStagePainter({
    required this.animValue,
    required this.shawtIndex,
  });

  final double animValue;
  final int shawtIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.50);
    final radiusX = size.width * 0.32;
    final radiusY = size.height * 0.34;

    // Background Mataf Marble
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.9,
        colors: [
          const Color(0xFF142B24),
          const Color(0xFF091410),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Marble Floor Concentric Rings
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (double r = 40; r <= radiusX + 30; r += 24) {
      canvas.drawOval(
        Rect.fromCenter(center: center, width: r * 2, height: r * 1.5),
        ringPaint,
      );
    }

    // Hacerü'l-Esved Virtual Green Alignment Laser Line (Bottom-Right)
    final greenLaser = Paint()
      ..color = const Color(0xFF00FF88).withValues(alpha: 0.85)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2);
    final esvedCorner = center + const Offset(18, 18);
    final laserEnd = center + const Offset(120, 85);
    canvas.drawLine(esvedCorner, laserEnd, greenLaser);

    // Green Line Label
    final laserText = TextPainter(
      text: const TextSpan(
        text: 'Hacerü’l-Esved Hizası (Başlangıç/Bitiş)',
        style: TextStyle(
          color: Color(0xFF00FF88),
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    laserText.paint(canvas, laserEnd + const Offset(-70, 4));

    // Hatîm (Hicr-i İsmail) Crescent Wall (Top-Left)
    final hatimPaint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawArc(
      Rect.fromCenter(center: center + const Offset(-28, -6), width: 34, height: 38),
      math.pi * 0.65,
      math.pi * 0.70,
      false,
      hatimPaint,
    );

    // Hatîm Outer Safety Boundary (Dotted Arc)
    final hatimDotted = Paint()
      ..color = RehberTheme.goldLight.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawArc(
      Rect.fromCenter(center: center + const Offset(-36, -6), width: 48, height: 52),
      math.pi * 0.60,
      math.pi * 0.80,
      false,
      hatimDotted,
    );

    // Makam-ı İbrahim (Golden Dome Symbol)
    final makamPaint = Paint()..color = RehberTheme.gold;
    canvas.drawCircle(center + const Offset(36, -12), 4.5, makamPaint);

    // THE HOLY KAABA (Center Black Cube with Gold Kiswah)
    final kaabaRect = Rect.fromCenter(center: center, width: 44, height: 44);
    final kaabaPaint = Paint()..color = const Color(0xFF111111);
    canvas.drawRect(kaabaRect, kaabaPaint);

    // Gold Kiswah Band
    final goldBand = Paint()
      ..color = RehberTheme.goldLight
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawRect(kaabaRect.deflate(6), goldBand);

    // Hacerü'l-Esved Silver Casing at Corner
    final esvedPaint = Paint()..color = const Color(0xFFC0C0C0);
    canvas.drawCircle(kaabaRect.bottomRight + const Offset(-2, -2), 3.5, esvedPaint);

    // COUNTER-CLOCKWISE PILGRIM ORBIT
    // Tawaf strictly proceeds counter-clockwise with Kaaba on left shoulder.
    final angle = -(animValue * 2 * math.pi) + (math.pi * 0.35);
    final pilgrimPos = Offset(
      center.dx + (radiusX * math.cos(angle)),
      center.dy + (radiusY * math.sin(angle)),
    );

    // Pilgrim Light Aura Trail
    final auraPaint = Paint()
      ..color = RehberTheme.goldLight.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawCircle(pilgrimPos, 14, auraPaint);

    // Pilgrim Dot
    final pilgrimPaint = Paint()..color = Colors.white;
    canvas.drawCircle(pilgrimPos, 5, pilgrimPaint);

    // Shawt Badge
    final shawtNo = (shawtIndex + 1).clamp(1, 7);
    final badgeText = TextPainter(
      text: TextSpan(
        text: '$shawtNo. Şavt',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    badgeText.paint(canvas, pilgrimPos + const Offset(8, -14));

    // İstimlâm Flash when crossing start line
    final isNearStartLine = (angle % (2 * math.pi)).abs() < 0.25;
    if (isNearStartLine) {
      final flashText = TextPainter(
        text: const TextSpan(
          text: 'İstimlâm: Bismillahi Allahu Ekber',
          style: TextStyle(
            color: Color(0xFF00FF88),
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      flashText.paint(canvas, center + const Offset(-80, 72));
    }
  }

  @override
  bool shouldRepaint(covariant _TawafStagePainter oldDelegate) =>
      oldDelegate.animValue != animValue ||
      oldDelegate.shawtIndex != shawtIndex;
}

// ==========================================
// 3. SAFÂ - MERVE SA'Y YOLU PAINTER'I
// ==========================================
class _SayStagePainter extends CustomPainter {
  const _SayStagePainter({
    required this.animValue,
    required this.lapIndex,
  });

  final double animValue;
  final int lapIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background
    final bgPaint = Paint()..color = const Color(0xFF0B1F1A);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // Safa Hill (Left) & Merve Hill (Right)
    final safaPaint = Paint()..color = const Color(0xFF4A3E2D);
    final mervePaint = Paint()..color = const Color(0xFF3D3528);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(10, h * 0.35, 50, h * 0.45),
        const Radius.circular(10),
      ),
      safaPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w - 60, h * 0.35, 50, h * 0.45),
        const Radius.circular(10),
      ),
      mervePaint,
    );

    // Labels
    final textStyle = const TextStyle(
      color: Colors.white,
      fontSize: 11,
      fontWeight: FontWeight.bold,
    );
    final safaLabel = TextPainter(
      text: TextSpan(text: 'SAFÂ\n(Başlangıç)', style: textStyle),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    safaLabel.paint(canvas, Offset(14, h * 0.42));

    final merveLabel = TextPainter(
      text: TextSpan(text: 'MERVE\n(Bitiş)', style: textStyle),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    merveLabel.paint(canvas, Offset(w - 56, h * 0.42));

    // The Walking Lane
    final laneY = h * 0.55;
    final lanePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(60, laneY), Offset(w - 60, laneY), lanePaint);

    // Green Lights / Hervele Rapid Walking Zone (Center Third)
    final greenZoneStart = w * 0.35;
    final greenZoneEnd = w * 0.65;
    final herveleZone = Rect.fromLTWH(
      greenZoneStart,
      laneY - 26,
      greenZoneEnd - greenZoneStart,
      52,
    );
    final hervelePaint = Paint()
      ..color = const Color(0xFF00FF88).withValues(alpha: 0.16);
    canvas.drawRRect(
      RRect.fromRectAndRadius(herveleZone, const Radius.circular(8)),
      hervelePaint,
    );

    // Fluorescent Green Lamps
    final lampPaint = Paint()
      ..color = const Color(0xFF00FF88)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(greenZoneStart, laneY - 22),
      Offset(greenZoneEnd, laneY - 22),
      lampPaint,
    );

    final herveleText = TextPainter(
      text: const TextSpan(
        text: 'Hervele Bölgesi (Yeşil Işıklar Arasında Hızlı Yürüyüş)',
        style: TextStyle(
          color: Color(0xFF00FF88),
          fontSize: 8,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    herveleText.paint(canvas, Offset(w * 0.32, laneY + 16));

    // Direction and Lap Calculation
    // Odd laps: Safa -> Merve; Even laps: Merve -> Safa
    final isGoingToMerve = (lapIndex % 2) == 0;
    final t = isGoingToMerve ? animValue : (1.0 - animValue);
    final pilgrimX = 65 + (w - 130) * t;

    // Pilgrim Walker
    final pilgrimPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(pilgrimX, laneY - 6), 6, pilgrimPaint);

    // Direction Arrow
    final arrowPaint = Paint()
      ..color = RehberTheme.goldLight
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final arrowDir = isGoingToMerve ? 6 : -6;
    canvas.drawLine(
      Offset(pilgrimX, laneY - 6),
      Offset(pilgrimX + arrowDir, laneY - 6),
      arrowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SayStagePainter oldDelegate) =>
      oldDelegate.animValue != animValue ||
      oldDelegate.lapIndex != lapIndex;
}

// ==========================================
// 4. MÎKĀT VE İHRAM PAINTER'I
// ==========================================
class _IhramStagePainter extends CustomPainter {
  const _IhramStagePainter({
    required this.animValue,
    required this.stepIndex,
  });

  final double animValue;
  final int stepIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bgPaint = Paint()..color = const Color(0xFF0B1F1A);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // Mîkāt Gate Arch (Center-Left)
    final archPaint = Paint()
      ..color = RehberTheme.goldLight
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w * 0.35, h * 0.50), width: 70, height: 95),
      math.pi,
      math.pi,
      false,
      archPaint,
    );

    final gateText = TextPainter(
      text: const TextSpan(
        text: 'MÎKĀT SINIRI',
        style: TextStyle(
          color: RehberTheme.goldLight,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    gateText.paint(canvas, Offset(w * 0.26, h * 0.22));

    // Pilgrim Entering in White Ihram (Center-Right)
    final pilgrimX = w * 0.62 + (math.sin(animValue * math.pi * 2) * 2);
    final pilgrimY = h * 0.52;

    // Head
    canvas.drawCircle(Offset(pilgrimX, pilgrimY - 26), 9, Paint()..color = const Color(0xFFFFD1A9));
    // White Ihram Cloth (Two pieces)
    final ihramPaint = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(pilgrimX, pilgrimY + 4), width: 26, height: 38),
        const Radius.circular(6),
      ),
      ihramPaint,
    );

    // Intention / Talbiyah Speech Bubble
    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.62, h * 0.22), width: 140, height: 28),
      const Radius.circular(8),
    );
    canvas.drawRRect(bubbleRect, Paint()..color = Colors.black87);
    canvas.drawRRect(
      bubbleRect,
      Paint()
        ..color = RehberTheme.emerald
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    final bubbleText = TextPainter(
      text: const TextSpan(
        text: 'Lebbeyk Allahümme Lebbeyk...',
        style: TextStyle(
          color: Color(0xFF00FF88),
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    bubbleText.paint(canvas, Offset(w * 0.44, h * 0.17));
  }

  @override
  bool shouldRepaint(covariant _IhramStagePainter oldDelegate) =>
      oldDelegate.animValue != animValue ||
      oldDelegate.stepIndex != stepIndex;
}

// ==========================================
// 5. CEMARAT (ŞEYTAN TAŞLAMA) PAINTER'I
// ==========================================
class _CemaratStagePainter extends CustomPainter {
  const _CemaratStagePainter({
    required this.animValue,
    required this.targetIndex,
  });

  final double animValue;
  final int targetIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bgPaint = Paint()..color = const Color(0xFF0B1F1A);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // Draw Jamarat Pillar (Center)
    final pillarRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.72, h * 0.50), width: 36, height: 75),
      const Radius.circular(6),
    );
    canvas.drawRRect(pillarRect, Paint()..color = const Color(0xFF7D6B58));
    canvas.drawRRect(
      pillarRect,
      Paint()
        ..color = RehberTheme.goldLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Oval Basin around Pillar
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.72, h * 0.76), width: 85, height: 26),
      Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Flying Pebble (Taş)
    final startPt = Offset(w * 0.25, h * 0.65);
    final targetPt = Offset(w * 0.72, h * 0.45);
    final t = animValue;
    final stoneX = startPt.dx + (targetPt.dx - startPt.dx) * t;
    final stoneY = startPt.dy + (targetPt.dy - startPt.dy) * t - (math.sin(t * math.pi) * 35);

    final stonePaint = Paint()..color = const Color(0xFFE0E0E0);
    canvas.drawCircle(Offset(stoneX, stoneY), 3.5, stonePaint);

    final takbirText = TextPainter(
      text: const TextSpan(
        text: 'Bismillahi Allahu Ekber',
        style: TextStyle(
          color: Color(0xFF00FF88),
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    takbirText.paint(canvas, Offset(w * 0.22, h * 0.42));
  }

  @override
  bool shouldRepaint(covariant _CemaratStagePainter oldDelegate) =>
      oldDelegate.animValue != animValue ||
      oldDelegate.targetIndex != targetIndex;
}
