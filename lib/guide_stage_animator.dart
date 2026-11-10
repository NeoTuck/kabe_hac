import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'narration_service.dart';

enum GuideStageType { luggage, tawaf, say, ihram, cemarat, arafat }

/// An interactive, visually rich animated stage shown above guide sections.
/// Allows pilgrims to watch real-time simulations (luggage packing, Kaaba tawaf,
/// Safa-Marwa sa'y, Mikat ihram, Jamarat stone throw) synchronized with narration
/// and persistent steps below.
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
    final isMyAudioPlaying =
        state.asset == widget.audioAsset &&
        state.status == NarrationStatus.playing;
    if (isMyAudioPlaying && !_isAutoPlaying) {
      setState(() => _isAutoPlaying = true);
      if (!_animController.isAnimating) {
        _animController.forward(from: 0.0);
      }
    } else if (!isMyAudioPlaying &&
        _isAutoPlaying &&
        state.status != NarrationStatus.paused) {
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
              height: 215,
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
                    top: 10,
                    left: 12,
                    right: 12,
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
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: RehberTheme.goldLight.withValues(
                                  alpha: 0.45,
                                ),
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
                            color: RehberTheme.emerald.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: RehberTheme.emerald.withValues(
                                  alpha: 0.4,
                                ),
                                blurRadius: 6,
                              ),
                            ],
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
                    bottom: 10,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: RehberTheme.emerald.withValues(alpha: 0.55),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: RehberTheme.emerald.withValues(
                                alpha: 0.35,
                              ),
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
                                fontSize: 11.5,
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
                color: dark ? const Color(0xFF091210) : const Color(0xFF0B1F1A),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
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
                              margin: const EdgeInsets.symmetric(
                                horizontal: 2.5,
                              ),
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
        return _TawafStagePainter(animValue: animValue, shawtIndex: itemIndex);
      case GuideStageType.say:
        return _SayStagePainter(animValue: animValue, lapIndex: itemIndex);
      case GuideStageType.ihram:
        return _IhramStagePainter(animValue: animValue, stepIndex: itemIndex);
      case GuideStageType.cemarat:
        return _CemaratStagePainter(
          animValue: animValue,
          targetIndex: itemIndex,
        );
      case GuideStageType.arafat:
        return _ArafatStagePainter(animValue: animValue, vakfeIndex: itemIndex);
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
      case GuideStageType.arafat:
        return Icons.wb_sunny_rounded;
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
      case GuideStageType.arafat:
        return 'Arafat Vakfesi & Cebelü’r-Rahme';
    }
  }
}

// ==========================================
// 1. VALİZ VE HAZIRLIK RESMİ PAINTER'I (PRO)
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

    // Ambient Room Background with warm spiritual vignette
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.1, -0.1),
        radius: 0.95,
        colors: [
          const Color(0xFF1E4535).withValues(alpha: 0.85),
          const Color(0xFF071B14),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // Modern Perspective Floor Planks
    final floorY = h * 0.68;
    final floorPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF0F261E), const Color(0xFF06120D)],
      ).createShader(Rect.fromLTWH(0, floorY, w, h - floorY));
    canvas.drawRect(Rect.fromLTWH(0, floorY, w, h - floorY), floorPaint);

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, floorY), Offset(w, floorY), linePaint);
    for (double x = -w * 0.2; x <= w * 1.2; x += 40) {
      canvas.drawLine(
        Offset(x, floorY),
        Offset(x + (x - w * 0.5) * 0.45, h),
        linePaint,
      );
    }

    // Traveler on Left
    final travelerPos = Offset(w * 0.19, floorY - 14);
    _drawTraveler(canvas, travelerPos, animValue);

    // Suitcase on Right
    final suitcaseCenter = Offset(w * 0.70, floorY - 12);
    _drawSuitcase(canvas, suitcaseCenter, progress);

    // Parabolic Item Animation
    final startPt = Offset(travelerPos.dx + 22, travelerPos.dy - 32);
    final endPt = Offset(suitcaseCenter.dx, suitcaseCenter.dy - 6);

    final t = (animValue * 1.35).clamp(0.0, 1.0);
    final curveT = Curves.easeOutCubic.transform(t);
    final currentX = startPt.dx + (endPt.dx - startPt.dx) * curveT;
    final arcHeight = -42 * math.sin(curveT * math.pi);
    final currentY = startPt.dy + (endPt.dy - startPt.dy) * curveT + arcHeight;

    // Glowing particle trail
    if (t > 0.08 && t < 0.95) {
      final trailPaint = Paint()
        ..color = RehberTheme.goldLight.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      for (int i = 1; i <= 4; i++) {
        final backT = (t - (i * 0.04)).clamp(0.0, 1.0);
        final backCurveT = Curves.easeOutCubic.transform(backT);
        final bx = startPt.dx + (endPt.dx - startPt.dx) * backCurveT;
        final by =
            startPt.dy +
            (endPt.dy - startPt.dy) * backCurveT +
            (-42 * math.sin(backCurveT * math.pi));
        canvas.drawCircle(Offset(bx, by), 4.0 - (i * 0.7), trailPaint);
      }
    }

    if (t < 0.94) {
      _drawFlyingItem(canvas, Offset(currentX, currentY), itemIndex, animValue);
    } else {
      // Landing bounce and golden burst
      final bounce = math.sin((animValue - 0.7) * math.pi * 6) * 2.5;
      _drawPackSuccessGlow(canvas, endPt + Offset(0, bounce));
    }
  }

  void _drawTraveler(Canvas canvas, Offset groundPos, double anim) {
    final breathing = math.sin(anim * math.pi * 2) * 1.5;
    final headCenter = Offset(groundPos.dx, groundPos.dy - 56 + breathing);

    // Drop shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(groundPos.dx, groundPos.dy + 4),
        width: 36,
        height: 10,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );

    // Legs / Pants
    final legPaint = Paint()
      ..color = const Color(0xFF264E3E)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(groundPos.dx - 4, groundPos.dy - 20),
      Offset(groundPos.dx - 4, groundPos.dy),
      legPaint,
    );
    canvas.drawLine(
      Offset(groundPos.dx + 4, groundPos.dy - 20),
      Offset(groundPos.dx + 4, groundPos.dy),
      legPaint,
    );

    // Shoes
    final shoePaint = Paint()..color = const Color(0xFF162D24);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(groundPos.dx - 9, groundPos.dy - 2, 8, 5),
        const Radius.circular(2),
      ),
      shoePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(groundPos.dx + 1, groundPos.dy - 2, 8, 5),
        const Radius.circular(2),
      ),
      shoePaint,
    );

    // Tunic / White Robe (Thobe)
    final robePaint = Paint()..color = const Color(0xFFE8F1EC);
    final robeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(groundPos.dx, groundPos.dy - 35 + breathing),
        width: 24,
        height: 32,
      ),
      const Radius.circular(7),
    );
    canvas.drawRRect(robeRect, robePaint);

    // Subtle robe folds
    final foldPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(groundPos.dx, groundPos.dy - 46 + breathing),
      Offset(groundPos.dx, groundPos.dy - 22 + breathing),
      foldPaint,
    );

    // Head (Skin & Hair / Kufi)
    final skinPaint = Paint()..color = const Color(0xFFFFD5B3);
    canvas.drawCircle(headCenter, 10.5, skinPaint);

    // Kufi / Islamic Prayer Cap (White/Gold trim)
    final kufiPaint = Paint()..color = Colors.white;
    canvas.drawArc(
      Rect.fromCenter(
        center: headCenter + const Offset(0, -2),
        width: 21,
        height: 18,
      ),
      math.pi,
      math.pi,
      true,
      kufiPaint,
    );

    // Friendly face profile
    final eyePaint = Paint()..color = const Color(0xFF332211);
    canvas.drawCircle(headCenter + const Offset(3.5, 0), 1.2, eyePaint);

    // Reaching Arm toward suitcase
    final armPaint = Paint()
      ..color = const Color(0xFFE8F1EC)
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    final handPaint = Paint()..color = const Color(0xFFFFD5B3);

    final handY =
        groundPos.dy - 36 + breathing - (math.sin(anim * math.pi) * 6);
    canvas.drawLine(
      Offset(groundPos.dx + 8, groundPos.dy - 44 + breathing),
      Offset(groundPos.dx + 22, handY),
      armPaint,
    );
    canvas.drawCircle(Offset(groundPos.dx + 23, handY), 3.0, handPaint);
  }

  void _drawSuitcase(Canvas canvas, Offset center, double fillFraction) {
    const caseWidth = 136.0;
    const caseHeight = 90.0;
    final rect = Rect.fromCenter(
      center: center,
      width: caseWidth,
      height: caseHeight,
    );

    // Drop Shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, rect.bottom + 6),
        width: caseWidth * 0.95,
        height: 14,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Telescoping Trolley Handle
    final handlePaint = Paint()
      ..color = const Color(0xFFD4AF37)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(rect.center.dx - 18, rect.top),
      Offset(rect.center.dx - 18, rect.top - 20),
      handlePaint,
    );
    canvas.drawLine(
      Offset(rect.center.dx + 18, rect.top),
      Offset(rect.center.dx + 18, rect.top - 20),
      handlePaint,
    );
    canvas.drawLine(
      Offset(rect.center.dx - 22, rect.top - 20),
      Offset(rect.center.dx + 22, rect.top - 20),
      Paint()
        ..color = Colors.black87
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round,
    );

    // Outer Polycarbonate Case Body (Emerald & Gold)
    final shellPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [const Color(0xFF23533E), const Color(0xFF133527)],
      ).createShader(rect);

    final shellRRect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    canvas.drawRRect(shellRRect, shellPaint);

    final goldBezel = Paint()
      ..color = RehberTheme.goldLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawRRect(shellRRect, goldBezel);

    // Inner Open Cavity
    final innerRect = rect.deflate(7);
    final innerRRect = RRect.fromRectAndRadius(
      innerRect,
      const Radius.circular(8),
    );
    final innerPaint = Paint()..color = const Color(0xFF0C1F17);
    canvas.drawRRect(innerRRect, innerPaint);

    // Stacked Packed Items inside (Levels build up as progress increases)
    if (fillFraction > 0.05) {
      final fillH = (innerRect.height - 4) * fillFraction.clamp(0.0, 1.0);
      final fillRect = Rect.fromLTWH(
        innerRect.left + 3,
        innerRect.bottom - fillH - 2,
        innerRect.width - 6,
        fillH,
      );

      final packPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [RehberTheme.emerald, const Color(0xFF1E523C)],
        ).createShader(fillRect);

      canvas.drawRRect(
        RRect.fromRectAndRadius(fillRect, const Radius.circular(5)),
        packPaint,
      );

      // Folded garment texture lines inside luggage
      final foldLine = Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..strokeWidth = 1.2;
      for (double y = fillRect.bottom - 10; y > fillRect.top; y -= 11) {
        canvas.drawLine(
          Offset(fillRect.left + 6, y),
          Offset(fillRect.right - 6, y),
          foldLine,
        );
      }

      // Elastic Gold X-Straps
      final strapPaint = Paint()
        ..color = RehberTheme.goldLight.withValues(alpha: 0.6)
        ..strokeWidth = 1.5;
      canvas.drawLine(fillRect.topLeft, fillRect.bottomRight, strapPaint);
      canvas.drawLine(fillRect.topRight, fillRect.bottomLeft, strapPaint);
    }

    // Spinner Wheels at bottom
    final wheelPaint = Paint()..color = Colors.black87;
    final goldHub = Paint()..color = RehberTheme.goldLight;
    for (final wx in [
      rect.left + 16,
      rect.left + 34,
      rect.right - 34,
      rect.right - 16,
    ]) {
      canvas.drawCircle(Offset(wx, rect.bottom + 4), 4.5, wheelPaint);
      canvas.drawCircle(Offset(wx, rect.bottom + 4), 1.8, goldHub);
    }

    // Corner Protectors
    for (final corner in [
      rect.topLeft + const Offset(6, 6),
      rect.topRight + const Offset(-6, 6),
      rect.bottomLeft + const Offset(6, -6),
      rect.bottomRight + const Offset(-6, -6),
    ]) {
      canvas.drawCircle(corner, 3.5, goldHub);
    }

    // Percentage Badge Pill
    final pctText = '%${(fillFraction * 100).round()} Dolu';
    final pctPainter = TextPainter(
      text: TextSpan(
        text: pctText,
        style: const TextStyle(
          color: RehberTheme.goldLight,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(rect.center.dx, rect.top - 2),
        width: pctPainter.width + 14,
        height: 16,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(badgeRect, Paint()..color = Colors.black87);
    canvas.drawRRect(badgeRect, goldBezel);
    pctPainter.paint(
      canvas,
      Offset(rect.center.dx - pctPainter.width / 2, rect.top - 9.5),
    );
  }

  void _drawFlyingItem(Canvas canvas, Offset pos, int index, double anim) {
    // Drop shadow
    canvas.drawCircle(
      pos + const Offset(0, 10),
      14,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Base Circular Badge
    final discRRect = Rect.fromCircle(center: pos, radius: 15.5);
    final discPaint = Paint()
      ..shader = RadialGradient(colors: [Colors.white, const Color(0xFFF0F5F2)])
          .createShader(discRRect);
    canvas.drawCircle(pos, 15.5, discPaint);

    final goldRing = Paint()
      ..color = RehberTheme.goldLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(pos, 15.5, goldRing);

    final glyph = Paint()
      ..color = const Color(0xFF1B4332)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    switch (index % 8) {
      case 0: // 2 Parça İhram Kumaşı & Altın Kemer
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: pos + const Offset(0, -3),
              width: 14,
              height: 6,
            ),
            const Radius.circular(2),
          ),
          glyph,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: pos + const Offset(0, 4),
              width: 14,
              height: 6,
            ),
            const Radius.circular(2),
          ),
          glyph,
        );
        break;
      case 1: // Kokusuz Bakım / Sabun & Şampuan
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: pos + const Offset(0, 2),
              width: 10,
              height: 13,
            ),
            const Radius.circular(3),
          ),
          glyph,
        );
        canvas.drawLine(
          pos + const Offset(0, -5),
          pos + const Offset(0, -8),
          glyph,
        );
        canvas.drawLine(
          pos + const Offset(-3, -8),
          pos + const Offset(3, -8),
          glyph,
        );
        // Bubble
        canvas.drawCircle(pos + const Offset(5, -6), 2, glyph);
        break;
      case 2: // Ortopedik Sandalet & Tavaf Patiği
        canvas.drawOval(
          Rect.fromCenter(
            center: pos + const Offset(0, 4),
            width: 16,
            height: 5,
          ),
          glyph,
        );
        canvas.drawArc(
          Rect.fromCenter(
            center: pos + const Offset(-2, 1),
            width: 9,
            height: 8,
          ),
          math.pi,
          math.pi,
          false,
          glyph,
        );
        break;
      case 3: // Ayakkabı Bez Torbası
        final bagPath = Path()
          ..moveTo(pos.dx - 6, pos.dy - 6)
          ..lineTo(pos.dx + 6, pos.dy - 6)
          ..lineTo(pos.dx + 8, pos.dy + 7)
          ..quadraticBezierTo(pos.dx, pos.dy + 9, pos.dx - 8, pos.dy + 7)
          ..close();
        canvas.drawPath(bagPath, glyph);
        canvas.drawLine(
          pos + const Offset(-4, -6),
          pos + const Offset(0, -9),
          glyph,
        );
        break;
      case 4: // İlaç & İlk Yardım Kiti
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: pos, width: 14, height: 14),
            const Radius.circular(3),
          ),
          glyph,
        );
        canvas.drawLine(
          pos + const Offset(0, -4),
          pos + const Offset(0, 4),
          glyph,
        );
        canvas.drawLine(
          pos + const Offset(-4, 0),
          pos + const Offset(4, 0),
          glyph,
        );
        break;
      case 5: // Pasaport & Boyun Cüzdanı
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: pos, width: 12, height: 16),
            const Radius.circular(2),
          ),
          glyph,
        );
        canvas.drawCircle(pos, 2.5, glyph);
        break;
      case 6: // Dua Risalesi & Dijital Zikirmatik
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: pos + const Offset(-2, 0),
              width: 10,
              height: 14,
            ),
            const Radius.circular(2),
          ),
          glyph,
        );
        canvas.drawCircle(pos + const Offset(5, 2), 3.5, glyph);
        break;
      default: // Saç Makası / Tırnak Makası
        canvas.drawLine(
          pos + const Offset(-5, -5),
          pos + const Offset(5, 5),
          glyph,
        );
        canvas.drawLine(
          pos + const Offset(5, -5),
          pos + const Offset(-5, 5),
          glyph,
        );
        canvas.drawCircle(pos + const Offset(-5, -5), 2.5, glyph);
        canvas.drawCircle(pos + const Offset(5, -5), 2.5, glyph);
        break;
    }
  }

  void _drawPackSuccessGlow(Canvas canvas, Offset pos) {
    final glow = Paint()
      ..color = RehberTheme.goldLight.withValues(alpha: 0.65)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(pos, 20, glow);

    final starPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0;
    canvas.drawLine(
      pos + const Offset(0, -9),
      pos + const Offset(0, 9),
      starPaint,
    );
    canvas.drawLine(
      pos + const Offset(-9, 0),
      pos + const Offset(9, 0),
      starPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LuggageStagePainter oldDelegate) =>
      oldDelegate.animValue != animValue ||
      oldDelegate.itemIndex != itemIndex ||
      oldDelegate.progress != progress;
}

// ==========================================
// 2. CANLI KÂBE TAVAF SİMÜLASYONU (ULTRA PRO)
// ==========================================
class _TawafStagePainter extends CustomPainter {
  const _TawafStagePainter({required this.animValue, required this.shawtIndex});

  final double animValue;
  final int shawtIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.50, size.height * 0.48);
    final radiusX = size.width * 0.34;
    final radiusY = size.height * 0.35;

    // Deep Spiritual Midnight Mataf Marble Floor
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.95,
        colors: [const Color(0xFF132B23), const Color(0xFF040C09)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Mataf Concentric Thassos Marble Rings
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (double r = 42; r <= radiusX + 35; r += 22) {
      canvas.drawOval(
        Rect.fromCenter(center: center, width: r * 2, height: r * 1.55),
        ringPaint,
      );
    }

    // Radial Joint Lines
    final radialPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 0.8;
    for (int i = 0; i < 12; i++) {
      final ang = i * (math.pi / 6);
      canvas.drawLine(
        Offset(center.dx + 45 * math.cos(ang), center.dy + 35 * math.sin(ang)),
        Offset(
          center.dx + (radiusX + 40) * math.cos(ang),
          center.dy + (radiusY + 40) * math.sin(ang),
        ),
        radialPaint,
      );
    }

    // Dynamic Ambient Flowing Tawaf Crowd Particles (18 pilgrims circling)
    final crowdPaint = Paint()..color = Colors.white.withValues(alpha: 0.45);
    for (int i = 0; i < 18; i++) {
      final crowdSpeed = 1.0 + (i % 3) * 0.15;
      final crowdAngle =
          -(animValue * 2 * math.pi * crowdSpeed) + (i * (math.pi * 2 / 18));
      final ringFactor = 0.65 + ((i * 7) % 10) * 0.07;
      final px = center.dx + (radiusX * ringFactor) * math.cos(crowdAngle);
      final py = center.dy + (radiusY * ringFactor) * math.sin(crowdAngle);
      canvas.drawCircle(Offset(px, py), 2.2, crowdPaint);
    }

    // Hacerü'l-Esved Virtual Laser Line (Glowing Neon Green)
    final esvedCorner = center + const Offset(20, 20);
    final laserEnd = center + const Offset(125, 90);

    final laserGlow = Paint()
      ..color = const Color(0xFF00FF88).withValues(alpha: 0.35)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawLine(esvedCorner, laserEnd, laserGlow);

    final greenLaser = Paint()
      ..color = const Color(0xFF00FF88)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(esvedCorner, laserEnd, greenLaser);

    // Animated light beam particle along laser line
    final laserT = (animValue * 2.5) % 1.0;
    final beamPos = Offset(
      esvedCorner.dx + (laserEnd.dx - esvedCorner.dx) * laserT,
      esvedCorner.dy + (laserEnd.dy - esvedCorner.dy) * laserT,
    );
    canvas.drawCircle(beamPos, 3.5, Paint()..color = Colors.white);

    // Green Laser Line Label
    final laserText = TextPainter(
      text: const TextSpan(
        text: 'Hacerü’l-Esved Hizası (Başlangıç/Bitiş)',
        style: TextStyle(
          color: Color(0xFF00FF88),
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    laserText.paint(canvas, laserEnd + const Offset(-65, 3));

    // Hatîm / Hicr-i İsmâîl (North-West Semicircular Marble Wall)
    final hatimCenter = center + const Offset(-30, -8);
    final hatimRect = Rect.fromCenter(
      center: hatimCenter,
      width: 38,
      height: 42,
    );

    // Green Carpet inside Hatim
    final hatimFill = Paint()
      ..color = const Color(0xFF144D34).withValues(alpha: 0.6);
    canvas.drawArc(hatimRect, math.pi * 0.62, math.pi * 0.76, true, hatimFill);

    // Thick White Marble Wall
    final hatimWall = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawArc(hatimRect, math.pi * 0.62, math.pi * 0.76, false, hatimWall);

    // Outer guide dotted arc for Hatim bypass
    final hatimDotted = Paint()
      ..color = RehberTheme.goldLight.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawArc(
      Rect.fromCenter(
        center: hatimCenter - const Offset(6, 0),
        width: 50,
        height: 54,
      ),
      math.pi * 0.58,
      math.pi * 0.84,
      false,
      hatimDotted,
    );

    // Makam-ı İbrâhîm (Golden Pavilion with Crystal Dome on East)
    final makamPos = center + const Offset(42, -12);
    canvas.drawCircle(
      makamPos,
      8.0,
      Paint()
        ..color = RehberTheme.goldLight.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(makamPos, 5.0, Paint()..color = RehberTheme.goldLight);
    canvas.drawCircle(makamPos, 2.5, Paint()..color = const Color(0xFFFFF6D6));

    // THE HOLY KAABA (Detailed Architectural Center Cube)
    final kaabaRect = Rect.fromCenter(center: center, width: 48, height: 48);

    // Soft Kaaba Shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        kaabaRect.shift(const Offset(3, 4)),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    // Şâzervân (White marble skirting border at base)
    final shazarvan = kaabaRect.inflate(2.5);
    canvas.drawRect(shazarvan, Paint()..color = const Color(0xFFDCD8CF));

    // Siyah Kiswah Body (Obsidian Black with subtle vertical fabric pleat lines)
    final kaabaPaint = Paint()..color = const Color(0xFF141518);
    canvas.drawRect(kaabaRect, kaabaPaint);

    final pleatPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;
    for (double kx = kaabaRect.left + 5; kx < kaabaRect.right; kx += 7) {
      canvas.drawLine(
        Offset(kx, kaabaRect.top),
        Offset(kx, kaabaRect.bottom),
        pleatPaint,
      );
    }

    // Golden Kiswah Band (Hizâm - Altın Sırma Kemer)
    final hizamY = kaabaRect.top + 10;
    final goldBand = Paint()
      ..color = RehberTheme.goldLight
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke;
    canvas.drawRect(
      Rect.fromLTRB(
        kaabaRect.left + 2,
        hizamY,
        kaabaRect.right - 2,
        hizamY + 4,
      ),
      goldBand,
    );

    // Bâbü'l-Kâbe (Golden Door on Eastern Wall)
    final doorRect = Rect.fromLTWH(
      kaabaRect.right - 10,
      kaabaRect.top + 14,
      8,
      18,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(doorRect, const Radius.circular(2)),
      Paint()..color = RehberTheme.goldLight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(doorRect, const Radius.circular(2)),
      Paint()
        ..color = const Color(0xFF8A6D1C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Mîzâbü'r-Rahme (Golden Water Spout on NW Wall facing Hatim)
    final spoutPaint = Paint()
      ..color = RehberTheme.goldLight
      ..strokeWidth = 2.0;
    canvas.drawLine(
      kaabaRect.topLeft + const Offset(8, 0),
      kaabaRect.topLeft + const Offset(4, -4),
      spoutPaint,
    );

    // Hacerü'l-Esved Silver Teardrop Casing at SE Corner
    final esvedCasing = Paint()..color = const Color(0xFFE8E8E8);
    final esvedStone = Paint()..color = const Color(0xFF0A0A0A);
    final esvedPt = kaabaRect.bottomRight + const Offset(-2, -2);
    canvas.drawCircle(esvedPt, 4.5, esvedCasing);
    canvas.drawCircle(esvedPt, 2.2, esvedStone);

    // Rükn-i Yemânî at SW Corner (Traditional Stone Accent)
    final yemaniPt = kaabaRect.bottomLeft + const Offset(2, -2);
    canvas.drawCircle(yemaniPt, 2.5, Paint()..color = const Color(0xFFB89772));

    // COUNTER-CLOCKWISE PILGRIM ORBIT
    // Tawaf strictly proceeds counter-clockwise with Kaaba on the left shoulder.
    final angle = -(animValue * 2 * math.pi) + (math.pi * 0.35);
    final pilgrimPos = Offset(
      center.dx + (radiusX * math.cos(angle)),
      center.dy + (radiusY * math.sin(angle)),
    );

    // Golden User Pilgrim Orbit Ring Track
    final orbitTrack = Paint()
      ..color = RehberTheme.goldLight.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radiusX * 2, height: radiusY * 2),
      orbitTrack,
    );

    // Pilgrim Light Aura Trail
    final auraPaint = Paint()
      ..color = RehberTheme.emerald.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(pilgrimPos, 16, auraPaint);

    final goldAura = Paint()
      ..color = RehberTheme.goldLight.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(pilgrimPos, 10, goldAura);

    // White Robed Pilgrim Figure
    canvas.drawCircle(pilgrimPos, 5.5, Paint()..color = Colors.white);
    canvas.drawCircle(
      pilgrimPos,
      5.5,
      Paint()
        ..color = RehberTheme.emerald
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Directional Forward Chevron / Arrow (Pointing CCW)
    final arrowAng = angle - (math.pi / 2);
    final arrowTip =
        pilgrimPos + Offset(math.cos(arrowAng) * 9, math.sin(arrowAng) * 9);
    final arrowPaint = Paint()
      ..color = RehberTheme.goldLight
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(pilgrimPos, arrowTip, arrowPaint);

    // Shawt Badge
    final shawtNo = (shawtIndex + 1).clamp(1, 7);
    final badgeBox = RRect.fromRectAndRadius(
      Rect.fromLTWH(pilgrimPos.dx + 9, pilgrimPos.dy - 16, 46, 17),
      const Radius.circular(6),
    );
    canvas.drawRRect(badgeBox, Paint()..color = Colors.black87);
    canvas.drawRRect(
      badgeBox,
      Paint()
        ..color = RehberTheme.goldLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    final badgeText = TextPainter(
      text: TextSpan(
        text: '$shawtNo. Şavt',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    badgeText.paint(canvas, Offset(pilgrimPos.dx + 13, pilgrimPos.dy - 14.5));

    // İstimlâm Event Flash when passing Hacerü'l-Esved line
    final isNearStartLine = (angle % (2 * math.pi)).abs() < 0.28;
    if (isNearStartLine) {
      final flashWave = Paint()
        ..color = const Color(0xFF00FF88).withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(esvedPt, 22, flashWave);

      final flashBanner = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center + const Offset(0, 78),
          width: 210,
          height: 22,
        ),
        const Radius.circular(8),
      );
      canvas.drawRRect(
        flashBanner,
        Paint()..color = Colors.black.withValues(alpha: 0.88),
      );
      canvas.drawRRect(
        flashBanner,
        Paint()
          ..color = const Color(0xFF00FF88)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      final flashText = TextPainter(
        text: const TextSpan(
          text: 'İstimlâm: Bismillâhi Allâhu Ekber ✋',
          style: TextStyle(
            color: Color(0xFF00FF88),
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      flashText.paint(canvas, center + const Offset(-95, 71.5));
    }
  }

  @override
  bool shouldRepaint(covariant _TawafStagePainter oldDelegate) =>
      oldDelegate.animValue != animValue ||
      oldDelegate.shawtIndex != shawtIndex;
}

// ==========================================
// 3. SAFÂ - MERVE SA'Y YOLU PAINTER'I (PRO)
// ==========================================
class _SayStagePainter extends CustomPainter {
  const _SayStagePainter({required this.animValue, required this.lapIndex});

  final double animValue;
  final int lapIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Ambient Corridor Canvas
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF091F18), const Color(0xFF05110E)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // Architectural Arched Islamic Ceiling Beams
    final archPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (double ax = 55; ax <= w - 55; ax += 38) {
      canvas.drawLine(Offset(ax, 0), Offset(ax, h * 0.35), archPaint);
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(ax + 19, h * 0.35),
          width: 38,
          height: 26,
        ),
        math.pi,
        math.pi,
        false,
        archPaint,
      );
    }

    final laneY = h * 0.58;

    // Polished Marble Dual Walking Lanes
    final floorPaint = Paint()..color = const Color(0xFF0E2B21);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(45, laneY - 26, w - 90, 52),
        const Radius.circular(8),
      ),
      floorPaint,
    );

    // Lane Divider Center Island (Wheelchair / Stroller path)
    final dividerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(50, laneY), Offset(w - 50, laneY), dividerPaint);

    // HERVELE ZONE: Real green fluorescent lights between the green pillars (~55m)
    final greenZoneStart = w * 0.33;
    final greenZoneEnd = w * 0.67;
    final greenZoneRect = Rect.fromLTWH(
      greenZoneStart,
      laneY - 26,
      greenZoneEnd - greenZoneStart,
      52,
    );

    // Volumetric Emerald Glow Cone from ceiling down to floor
    final conePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF00FF88).withValues(alpha: 0.28),
          const Color(0xFF00FF88).withValues(alpha: 0.08),
        ],
      ).createShader(greenZoneRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(greenZoneRect, const Radius.circular(8)),
      conePaint,
    );

    // Overhead Fluorescent Green Light Tubes
    final tubePaint = Paint()
      ..color = const Color(0xFF00FF88)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2);
    canvas.drawLine(
      Offset(greenZoneStart, laneY - 24),
      Offset(greenZoneEnd, laneY - 24),
      tubePaint,
    );

    // Green Pillars (Milên Ahdaren)
    final pillarPaint = Paint()
      ..color = const Color(0xFF00FF88)
      ..strokeWidth = 2.5;
    canvas.drawLine(
      Offset(greenZoneStart, laneY - 26),
      Offset(greenZoneStart, laneY + 26),
      pillarPaint,
    );
    canvas.drawLine(
      Offset(greenZoneEnd, laneY - 26),
      Offset(greenZoneEnd, laneY + 26),
      pillarPaint,
    );

    // Hervele Info Label
    final herveleText = TextPainter(
      text: const TextSpan(
        text: '⚡ Hervele Alanı (Yeşil Işıklar: Hızlı ve Canlı Yürüyüş)',
        style: TextStyle(
          color: Color(0xFF00FF88),
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    herveleText.paint(canvas, Offset(w * 0.31, laneY + 28));

    // SAFÂ TEPESİ (Left Rocky Elevation)
    final hillPaint = Paint()..color = const Color(0xFF42372A);
    final safaPath = Path()
      ..moveTo(8, laneY + 26)
      ..lineTo(8, laneY - 14)
      ..quadraticBezierTo(28, laneY - 24, 48, laneY - 12)
      ..lineTo(48, laneY + 26)
      ..close();
    canvas.drawPath(safaPath, hillPaint);
    canvas.drawPath(
      safaPath,
      Paint()
        ..color = RehberTheme.goldLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // MERVE TEPESİ (Right Rocky Elevation)
    final mervePath = Path()
      ..moveTo(w - 48, laneY + 26)
      ..lineTo(w - 48, laneY - 12)
      ..quadraticBezierTo(w - 28, laneY - 24, w - 8, laneY - 14)
      ..lineTo(w - 8, laneY + 26)
      ..close();
    canvas.drawPath(mervePath, hillPaint);
    canvas.drawPath(
      mervePath,
      Paint()
        ..color = RehberTheme.goldLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Hill Labels
    final hillStyle = const TextStyle(
      color: Colors.white,
      fontSize: 9.5,
      fontWeight: FontWeight.bold,
    );
    final safaLabel = TextPainter(
      text: TextSpan(text: 'SAFÂ\n(Başlangıç)', style: hillStyle),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    safaLabel.paint(canvas, Offset(11, laneY - 10));

    final merveLabel = TextPainter(
      text: TextSpan(text: 'MERVE\n(Bitiş)', style: hillStyle),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    merveLabel.paint(canvas, Offset(w - 46, laneY - 10));

    // Direction and Dynamic Pilgrim Movement
    // Laps 0, 2, 4, 6: Safa -> Merve; Laps 1, 3, 5: Merve -> Safa
    final isGoingToMerve = (lapIndex % 2) == 0;
    final t = isGoingToMerve ? animValue : (1.0 - animValue);
    final pilgrimX = 55 + (w - 110) * t;

    // Hervele check (is pilgrim inside green zone?)
    final isInsideHervele =
        pilgrimX >= greenZoneStart && pilgrimX <= greenZoneEnd;

    // In Hervele zone: Stride speed doubles with energetic vertical trot bob
    final trotBob = isInsideHervele
        ? (math.sin(animValue * math.pi * 12) * 2.8).abs()
        : (math.sin(animValue * math.pi * 6) * 1.5).abs();

    final pilgrimY = (isGoingToMerve ? laneY - 12 : laneY + 12) - trotBob;

    // Speed trails if inside Hervele
    if (isInsideHervele) {
      final trailPaint = Paint()
        ..color = const Color(0xFF00FF88).withValues(alpha: 0.35)
        ..strokeWidth = 2.0;
      final trailDir = isGoingToMerve ? -14 : 14;
      canvas.drawLine(
        Offset(pilgrimX + trailDir, pilgrimY),
        Offset(pilgrimX, pilgrimY),
        trailPaint,
      );
    }

    // Pilgrim Avatar
    canvas.drawCircle(
      Offset(pilgrimX, pilgrimY),
      8.0,
      Paint()
        ..color = isInsideHervele
            ? const Color(0xFF00FF88).withValues(alpha: 0.4)
            : RehberTheme.goldLight.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(
      Offset(pilgrimX, pilgrimY),
      5.5,
      Paint()..color = Colors.white,
    );

    // Direction Arrow next to pilgrim
    final arrowPaint = Paint()
      ..color = RehberTheme.goldLight
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final dirSign = isGoingToMerve ? 7.0 : -7.0;
    canvas.drawLine(
      Offset(pilgrimX, pilgrimY),
      Offset(pilgrimX + dirSign, pilgrimY),
      arrowPaint,
    );

    // Lap HUD Pill at top center
    final lapText =
        '${(lapIndex + 1).clamp(1, 7)}. Tur: ${isGoingToMerve ? "Safâ ➔ Merve" : "Merve ➔ Safâ"} (~395m)';
    final hudPainter = TextPainter(
      text: TextSpan(
        text: lapText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final hudRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.22),
        width: hudPainter.width + 18,
        height: 20,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(hudRect, Paint()..color = Colors.black87);
    canvas.drawRRect(
      hudRect,
      Paint()
        ..color = RehberTheme.emerald
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    hudPainter.paint(
      canvas,
      Offset(w * 0.50 - hudPainter.width / 2, h * 0.22 - 6),
    );
  }

  @override
  bool shouldRepaint(covariant _SayStagePainter oldDelegate) =>
      oldDelegate.animValue != animValue || oldDelegate.lapIndex != lapIndex;
}

// ==========================================
// 4. MÎKĀT VE İHRAM HAZIRLIĞI PAINTER'I (PRO)
// ==========================================
class _IhramStagePainter extends CustomPainter {
  const _IhramStagePainter({required this.animValue, required this.stepIndex});

  final double animValue;
  final int stepIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Atmospheric Twilight Desert Sky
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF091C15),
          const Color(0xFF0B241C),
          const Color(0xFF16382C),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // Twinkling Desert Stars & Silver Crescent Moon
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.65);
    for (final star in [
      Offset(w * 0.12, h * 0.14),
      Offset(w * 0.25, h * 0.08),
      Offset(w * 0.48, h * 0.12),
      Offset(w * 0.78, h * 0.09),
      Offset(w * 0.88, h * 0.16),
    ]) {
      canvas.drawCircle(star, 1.2, starPaint);
    }

    // Crescent Moon
    final moonCenter = Offset(w * 0.84, h * 0.15);
    canvas.drawCircle(
      moonCenter,
      7.0,
      Paint()..color = const Color(0xFFFFF7D6),
    );
    canvas.drawCircle(
      moonCenter + const Offset(2.5, -1),
      6.0,
      Paint()..color = const Color(0xFF091C15),
    );

    // Monumental Mîkāt Mosque Archway (Center-Left)
    final archCenter = Offset(w * 0.32, h * 0.58);
    final archPaint = Paint()
      ..color = RehberTheme.goldLight
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    // Horseshoe Islamic Arch Profile
    final archPath = Path()
      ..moveTo(archCenter.dx - 36, archCenter.dy + 35)
      ..lineTo(archCenter.dx - 36, archCenter.dy - 10)
      ..quadraticBezierTo(
        archCenter.dx - 36,
        archCenter.dy - 35,
        archCenter.dx,
        archCenter.dy - 44,
      )
      ..quadraticBezierTo(
        archCenter.dx + 36,
        archCenter.dy - 35,
        archCenter.dx + 36,
        archCenter.dy - 10,
      )
      ..lineTo(archCenter.dx + 36, archCenter.dy + 35);
    canvas.drawPath(archPath, archPaint);

    // Arch Gate Plaque
    final plaque = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(archCenter.dx, archCenter.dy - 48),
        width: 90,
        height: 16,
      ),
      const Radius.circular(5),
    );
    canvas.drawRRect(plaque, Paint()..color = Colors.black87);
    canvas.drawRRect(
      plaque,
      Paint()
        ..color = RehberTheme.goldLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    final gateText = TextPainter(
      text: const TextSpan(
        text: 'MÎKĀT SINIRI',
        style: TextStyle(
          color: RehberTheme.goldLight,
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    gateText.paint(
      canvas,
      Offset(archCenter.dx - gateText.width / 2, archCenter.dy - 54),
    );

    // Pilgrim in White Ihram on Right (Center-Right)
    final pilgrimCenter = Offset(w * 0.68, h * 0.60);
    final breathing = math.sin(animValue * math.pi * 2) * 1.5;

    // Spiritual Aura Glow around Pilgrim
    canvas.drawCircle(
      pilgrimCenter + const Offset(0, -10),
      28,
      Paint()
        ..color = RehberTheme.goldLight.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Prayer Rug (Seccade) under Pilgrim
    final rugRect = Rect.fromCenter(
      center: Offset(pilgrimCenter.dx, pilgrimCenter.dy + 26),
      width: 44,
      height: 12,
    );
    canvas.drawOval(rugRect, Paint()..color = const Color(0xFF1B4332));
    canvas.drawOval(
      rugRect,
      Paint()
        ..color = RehberTheme.goldLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Head
    final headPt = Offset(pilgrimCenter.dx, pilgrimCenter.dy - 36 + breathing);
    canvas.drawCircle(headPt, 9.5, Paint()..color = const Color(0xFFFFD5B3));

    // Two-Piece White Ihram (İzâr lower wrap + Ridâ upper wrap)
    final ihramPaint = Paint()..color = Colors.white;
    // Lower wrap (İzâr)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(pilgrimCenter.dx, pilgrimCenter.dy + 8 + breathing),
          width: 24,
          height: 26,
        ),
        const Radius.circular(5),
      ),
      ihramPaint,
    );
    // Upper wrap (Ridâ - draped over shoulder)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(pilgrimCenter.dx, pilgrimCenter.dy - 12 + breathing),
          width: 28,
          height: 24,
        ),
        const Radius.circular(6),
      ),
      ihramPaint,
    );

    // Folds & Golden Ihram Belt
    final beltPaint = Paint()
      ..color = RehberTheme.goldLight
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(pilgrimCenter.dx - 12, pilgrimCenter.dy - 1 + breathing),
      Offset(pilgrimCenter.dx + 12, pilgrimCenter.dy - 1 + breathing),
      beltPaint,
    );

    // Raised Dua Hands
    final handPaint = Paint()
      ..color = const Color(0xFFFFD5B3)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(pilgrimCenter.dx - 8, pilgrimCenter.dy - 14 + breathing),
      Offset(pilgrimCenter.dx - 3, pilgrimCenter.dy - 22 + breathing),
      handPaint,
    );
    canvas.drawLine(
      Offset(pilgrimCenter.dx + 8, pilgrimCenter.dy - 14 + breathing),
      Offset(pilgrimCenter.dx + 3, pilgrimCenter.dy - 22 + breathing),
      handPaint,
    );

    // Intention & Talbiyah Illuminated Speech Bubble
    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.58, h * 0.22),
        width: 175,
        height: 32,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      bubbleRect,
      Paint()..color = Colors.black.withValues(alpha: 0.85),
    );
    canvas.drawRRect(
      bubbleRect,
      Paint()
        ..color = RehberTheme.emerald
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final bubbleText = TextPainter(
      text: const TextSpan(
        text: 'لَبَّيْكَ اللَّهُمَّ لَبَّيْكَ...\n"Lebbeyk Allâhümme Lebbeyk"',
        style: TextStyle(
          color: Color(0xFF00FF88),
          fontSize: 9.0,
          fontWeight: FontWeight.bold,
          height: 1.25,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    bubbleText.paint(
      canvas,
      Offset(w * 0.58 - bubbleText.width / 2, h * 0.22 - 11),
    );
  }

  @override
  bool shouldRepaint(covariant _IhramStagePainter oldDelegate) =>
      oldDelegate.animValue != animValue || oldDelegate.stepIndex != stepIndex;
}

// ==========================================
// 5. CEMARAT (ŞEYTAN TAŞLAMA) PAINTER'I (PRO)
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

    // Jamarat Bridge Platform Canvas
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF132620), const Color(0xFF081410)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // Platform Safety Barrier Line
    final floorY = h * 0.74;
    canvas.drawLine(
      Offset(0, floorY),
      Offset(w, floorY),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..strokeWidth = 1.5,
    );

    // Massive Elliptical Stone Jamarat Pillar (Cemre Duvarı on Right)
    final pillarCenter = Offset(w * 0.74, h * 0.48);
    const pillarWidth = 42.0;
    const pillarHeight = 84.0;
    final pillarRect = Rect.fromCenter(
      center: pillarCenter,
      width: pillarWidth,
      height: pillarHeight,
    );

    // Pillar Shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(pillarCenter.dx, pillarRect.bottom + 6),
        width: 60,
        height: 14,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );

    // Chiseled Sandstone Masonry
    final pillarPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [const Color(0xFF96826D), const Color(0xFF6B5A49)],
      ).createShader(pillarRect);

    final pillarRRect = RRect.fromRectAndRadius(
      pillarRect,
      const Radius.circular(8),
    );
    canvas.drawRRect(pillarRRect, pillarPaint);
    canvas.drawRRect(
      pillarRRect,
      Paint()
        ..color = RehberTheme.goldLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Masonry Course Lines on Pillar
    final stoneLine = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..strokeWidth = 1.0;
    for (double sy = pillarRect.top + 14; sy < pillarRect.bottom; sy += 15) {
      canvas.drawLine(
        Offset(pillarRect.left + 4, sy),
        Offset(pillarRect.right - 4, sy),
        stoneLine,
      );
    }

    // Oval Collection Basin (Havuz) around Pillar
    final basinRect = Rect.fromCenter(
      center: Offset(pillarCenter.dx, pillarRect.bottom + 4),
      width: 95,
      height: 28,
    );
    canvas.drawOval(basinRect, Paint()..color = const Color(0xFF1E382D));
    canvas.drawOval(
      basinRect,
      Paint()
        ..color = RehberTheme.goldLight.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    // Pilgrim Thrower on Left
    final throwerPos = Offset(w * 0.20, floorY);
    _drawThrower(canvas, throwerPos, animValue);

    // Ballistic Trajectory of the Flying Pebble (Taş)
    final startPt = Offset(throwerPos.dx + 16, throwerPos.dy - 44);
    final targetPt = Offset(
      pillarCenter.dx - (pillarWidth * 0.4),
      pillarCenter.dy - 8,
    );

    final t = animValue;
    final stoneX = startPt.dx + (targetPt.dx - startPt.dx) * t;
    final arcY = -48 * math.sin(t * math.pi);
    final stoneY = startPt.dy + (targetPt.dy - startPt.dy) * t + arcY;

    // Glowing motion trail
    if (t > 0.08 && t < 0.95) {
      canvas.drawCircle(
        Offset(stoneX, stoneY),
        4.0,
        Paint()
          ..color = RehberTheme.goldLight.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    if (t < 0.92) {
      // Pebble in Flight
      final pebblePaint = Paint()..color = const Color(0xFFF2EFE9);
      canvas.drawCircle(Offset(stoneX, stoneY), 3.8, pebblePaint);
      canvas.drawCircle(
        Offset(stoneX, stoneY),
        3.8,
        Paint()
          ..color = const Color(0xFF887766)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    } else {
      // Strike impact on Pillar wall
      final impactWave = Paint()
        ..color = const Color(0xFF00FF88).withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(targetPt, 14, impactWave);

      // Pebble falling into basin
      final fallY =
          targetPt.dy + (pillarRect.bottom - targetPt.dy) * ((t - 0.92) / 0.08);
      canvas.drawCircle(
        Offset(targetPt.dx, fallY),
        3.2,
        Paint()..color = Colors.white70,
      );
    }

    // Takbir Badge Callout
    final takbirText = TextPainter(
      text: const TextSpan(
        text: 'Bismillâhi Allâhu Ekber 💥',
        style: TextStyle(
          color: Color(0xFF00FF88),
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final takbirPill = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.44, h * 0.22),
        width: takbirText.width + 16,
        height: 20,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(takbirPill, Paint()..color = Colors.black87);
    canvas.drawRRect(
      takbirPill,
      Paint()
        ..color = const Color(0xFF00FF88)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    takbirText.paint(
      canvas,
      Offset(w * 0.44 - takbirText.width / 2, h * 0.22 - 6),
    );

    // Stone Counter Pill (e.g. 1/7 Taş Atıldı)
    final stoneNo = ((targetIndex) % 7) + 1;
    final counterText = '$stoneNo / 7 Taş Atıldı';
    final counterPainter = TextPainter(
      text: TextSpan(
        text: counterText,
        style: const TextStyle(
          color: RehberTheme.goldLight,
          fontSize: 9.0,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    counterPainter.paint(
      canvas,
      Offset(w * 0.74 - counterPainter.width / 2, h * 0.88),
    );
  }

  void _drawThrower(Canvas canvas, Offset pos, double anim) {
    // Drop shadow
    canvas.drawOval(
      Rect.fromCenter(center: pos + const Offset(0, 3), width: 30, height: 8),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );

    // Head
    canvas.drawCircle(
      pos + const Offset(0, -50),
      9.0,
      Paint()..color = const Color(0xFFFFD5B3),
    );

    // White Ihram Robe
    final robeRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: pos + const Offset(0, -25),
        width: 22,
        height: 34,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(robeRRect, Paint()..color = Colors.white);

    // Throwing Arm Animation (Cocks back then throws forward)
    final armAngle = anim < 0.4 ? -(anim * 2) : (anim - 0.4) * 2.5;
    final handX = pos.dx + 8 + (math.cos(armAngle) * 12);
    final handY = pos.dy - 38 - (math.sin(armAngle) * 8);

    final armPaint = Paint()
      ..color = const Color(0xFFFFD5B3)
      ..strokeWidth = 3.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(pos + const Offset(6, -38), Offset(handX, handY), armPaint);
  }

  @override
  bool shouldRepaint(covariant _CemaratStagePainter oldDelegate) =>
      oldDelegate.animValue != animValue ||
      oldDelegate.targetIndex != targetIndex;
}

// ==========================================
// 6. ARAFAT & CEBELÜ’R-RAHME VAKFESİ (60 FPS)
// ==========================================
class _ArafatStagePainter extends CustomPainter {
  const _ArafatStagePainter({
    required this.animValue,
    required this.vakfeIndex,
  });

  final double animValue;
  final int vakfeIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final isNightMuzdelife = vakfeIndex >= 3;

    // 1. Atmosferik Gökyüzü (Sunset / Müzdelife Alacakaranlığı)
    final bgPaint = Paint();
    if (!isNightMuzdelife) {
      // Gün batımı amber & çöl alacakaranlık gradyanı
      bgPaint.shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF091C14), // Üst zümrüt alacakaranlık
          Color(0xFF2C160B), // Sıcak çöl göğü
          Color(0xFF6B2B0F), // Akşam kızıllığı
          Color(0xFFD6771F), // Ufuk altın ışığı
        ],
        stops: [0.0, 0.40, 0.70, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    } else {
      // Müzdelife berrak çöl gecesi gradyanı
      bgPaint.shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF05111A), // Gece laciverti
          Color(0xFF091E24), // Mavi-yeşil çöl gecesi
          Color(0xFF0E2E23), // Ufuk zümrüt parıltısı
        ],
        stops: [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    }
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    if (isNightMuzdelife) {
      _drawNightSky(canvas, w, h);
    } else {
      _drawSettingSun(canvas, w, h);
    }

    // 2. Cebelü'r-Rahme (Rahmet Dağı) Silüeti & Kayalık Granit Tepesi
    _drawMountRahmah(canvas, w, h, isNightMuzdelife);

    // 3. İkonik Beyaz Rahmet Sütunu (El-Alem / Obelisk)
    _drawRahmahObelisk(canvas, w, h);

    // 4. Çöl Zemin Tepeleri & Kumul Katmanları
    _drawDesertDunes(canvas, w, h, isNightMuzdelife);

    // 5. Dua Eden Hacı (Vakfede Semaya Açılan Eller)
    _drawSupplicatingPilgrim(canvas, w, h);

    // 6. Yükselen Nur & Dua Partikülleri
    _drawAscendingPrayers(canvas, w, h);

    // 7. Aşama Rozeti & İhlâs / Telbiye Şeridi
    _drawStageBadge(canvas, w, h, isNightMuzdelife);
  }

  void _drawSettingSun(Canvas canvas, double w, double h) {
    final sunCenter = Offset(w * 0.36, h * 0.46);
    // Güneş Halesi
    canvas.drawCircle(
      sunCenter,
      44,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFE082).withValues(alpha: 0.55),
            const Color(0xFFFF9800).withValues(alpha: 0.20),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: sunCenter, radius: 44)),
    );
    // Güneş Çekirdeği
    canvas.drawCircle(sunCenter, 17, Paint()..color = const Color(0xFFFFF3E0));
  }

  void _drawNightSky(Canvas canvas, double w, double h) {
    // 1. Hilal (Crescent Moon)
    final moonCenter = Offset(w * 0.22, h * 0.24);
    final moonPaint = Paint()..color = const Color(0xFFFFEAA7);
    final moonMask = Paint()..color = const Color(0xFF07151E);

    canvas.drawCircle(moonCenter, 14, moonPaint);
    canvas.drawCircle(moonCenter + const Offset(5, -4), 13, moonMask);

    // Hilal halesi
    canvas.drawCircle(
      moonCenter,
      26,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFEAA7).withValues(alpha: 0.25),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: moonCenter, radius: 26)),
    );

    // 2. Parıldayan Çöl Yıldızları
    final starOffsets = [
      Offset(w * 0.08, h * 0.15),
      Offset(w * 0.16, h * 0.35),
      Offset(w * 0.32, h * 0.12),
      Offset(w * 0.42, h * 0.26),
      Offset(w * 0.52, h * 0.16),
      Offset(w * 0.88, h * 0.14),
      Offset(w * 0.94, h * 0.28),
      Offset(w * 0.82, h * 0.22),
    ];

    for (int i = 0; i < starOffsets.length; i++) {
      final twinkle = (math.sin(animValue * math.pi * 2 + i * 1.2) + 1.0) / 2.0;
      final starPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.35 + (twinkle * 0.55));
      canvas.drawCircle(starOffsets[i], 1.2 + (twinkle * 0.8), starPaint);
    }
  }

  void _drawMountRahmah(Canvas canvas, double w, double h, bool isNight) {
    final mountainBaseY = h * 0.74;
    final peakX = w * 0.72;
    final peakY = h * 0.35;

    // Dağ Gövde Yolu
    final mountainPath = Path()
      ..moveTo(w * 0.38, mountainBaseY)
      ..cubicTo(
        w * 0.48,
        mountainBaseY - 10,
        w * 0.56,
        peakY + 45,
        w * 0.65,
        peakY + 16,
      )
      ..lineTo(peakX - 8, peakY + 2)
      ..lineTo(peakX, peakY)
      ..lineTo(peakX + 8, peakY + 2)
      ..cubicTo(
        w * 0.78,
        peakY + 18,
        w * 0.86,
        peakY + 52,
        w * 0.96,
        mountainBaseY - 8,
      )
      ..lineTo(w * 1.05, mountainBaseY)
      ..lineTo(w * 0.38, mountainBaseY)
      ..close();

    final mountainPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isNight
                ? [const Color(0xFF142B28), const Color(0xFF0B1917)]
                : [const Color(0xFF4A2A1A), const Color(0xFF1F120B)],
          ).createShader(
            Rect.fromLTWH(w * 0.38, peakY, w * 0.67, mountainBaseY - peakY),
          );

    canvas.drawPath(mountainPath, mountainPaint);

    // Granit Kaya Sırtı ve Gölgeler
    final ridgePath = Path()
      ..moveTo(peakX, peakY)
      ..lineTo(w * 0.70, peakY + 30)
      ..lineTo(w * 0.64, peakY + 55)
      ..lineTo(w * 0.58, mountainBaseY)
      ..lineTo(w * 1.05, mountainBaseY)
      ..cubicTo(
        w * 0.86,
        peakY + 52,
        w * 0.78,
        peakY + 18,
        peakX + 8,
        peakY + 2,
      )
      ..close();

    final ridgePaint = Paint()
      ..color = (isNight ? Colors.black : const Color(0xFF150A05)).withValues(
        alpha: 0.35,
      );
    canvas.drawPath(ridgePath, ridgePaint);

    // Kayalık Basamak ve Detaylar
    final boulderPaint = Paint()
      ..color = (isNight ? const Color(0xFF1B3D37) : const Color(0xFF784528))
          .withValues(alpha: 0.30);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.62, peakY + 48),
        width: 28,
        height: 12,
      ),
      boulderPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.78, peakY + 42),
        width: 34,
        height: 14,
      ),
      boulderPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.84, mountainBaseY - 14),
        width: 44,
        height: 16,
      ),
      boulderPaint,
    );
  }

  void _drawRahmahObelisk(Canvas canvas, double w, double h) {
    final peakX = w * 0.72;
    final peakY = h * 0.35;
    const obeliskWidth = 8.0;
    const obeliskHeight = 26.0;

    // Nur / Aydınlık Halesi (Pulsing Noor)
    final pulse = (math.sin(animValue * math.pi * 2) + 1.0) / 2.0;
    final haloRadius = 24.0 + (pulse * 8.0);
    canvas.drawCircle(
      Offset(peakX, peakY - obeliskHeight / 2),
      haloRadius,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                RehberTheme.goldLight.withValues(alpha: 0.38 + (pulse * 0.22)),
                const Color(0xFF2D6A4F).withValues(alpha: 0.15),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(
                center: Offset(peakX, peakY - obeliskHeight / 2),
                radius: haloRadius,
              ),
            ),
    );

    // Kaide (Base Platform)
    final baseRect = Rect.fromCenter(
      center: Offset(peakX, peakY - 1.5),
      width: 16.0,
      height: 4.0,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(baseRect, const Radius.circular(1.5)),
      Paint()..color = const Color(0xFFE0E0E0),
    );

    // Beyaz Sütun Gövdesi
    final obeliskRect = Rect.fromCenter(
      center: Offset(peakX, peakY - (obeliskHeight / 2)),
      width: obeliskWidth,
      height: obeliskHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(obeliskRect, const Radius.circular(2)),
      Paint()..color = Colors.white,
    );

    // Sağ Taraf Gölgeleme (3D Taş Efekti)
    final shadowRect = Rect.fromLTWH(
      peakX,
      peakY - obeliskHeight,
      obeliskWidth / 2,
      obeliskHeight,
    );
    canvas.drawRect(
      shadowRect,
      Paint()..color = Colors.black.withValues(alpha: 0.15),
    );

    // Tepe Zirve Işığı (Altın Nokta)
    canvas.drawCircle(
      Offset(peakX, peakY - obeliskHeight - 1),
      2.2,
      Paint()..color = RehberTheme.goldLight,
    );
  }

  void _drawDesertDunes(Canvas canvas, double w, double h, bool isNight) {
    // 1. Arka Kumul (Midground Dune)
    final midDunePath = Path()
      ..moveTo(0, h * 0.72)
      ..quadraticBezierTo(w * 0.35, h * 0.68, w * 0.65, h * 0.75)
      ..lineTo(w, h * 0.73)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    final midDunePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isNight
            ? [const Color(0xFF0F2620), const Color(0xFF081713)]
            : [const Color(0xFF3B1E12), const Color(0xFF1E0E07)],
      ).createShader(Rect.fromLTWH(0, h * 0.68, w, h * 0.32));
    canvas.drawPath(midDunePath, midDunePaint);

    // 2. Ön Zemin Kumulu (Foreground Plateau)
    final foreDunePath = Path()
      ..moveTo(0, h * 0.78)
      ..cubicTo(w * 0.28, h * 0.74, w * 0.60, h * 0.82, w, h * 0.76)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    final foreDunePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isNight
            ? [const Color(0xFF13352B), const Color(0xFF06140F)]
            : [const Color(0xFF5A2E19), const Color(0xFF180C06)],
      ).createShader(Rect.fromLTWH(0, h * 0.74, w, h * 0.26));
    canvas.drawPath(foreDunePath, foreDunePaint);

    // Altın Kumul Sırt Çizgisi (Golden Ridge Rim)
    final ridgePaint = Paint()
      ..color = (isNight ? RehberTheme.emerald : RehberTheme.goldLight)
          .withValues(alpha: 0.40)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final rimPath = Path()
      ..moveTo(0, h * 0.78)
      ..cubicTo(w * 0.28, h * 0.74, w * 0.60, h * 0.82, w, h * 0.76);
    canvas.drawPath(rimPath, ridgePaint);
  }

  void _drawSupplicatingPilgrim(Canvas canvas, double w, double h) {
    final pos = Offset(w * 0.24, h * 0.76);

    // Yerdeki Gölge
    canvas.drawOval(
      Rect.fromCenter(center: pos + const Offset(0, 3), width: 34, height: 9),
      Paint()..color = Colors.black.withValues(alpha: 0.40),
    );

    // Nefes Alma / Dua Salınım Hareketi
    final breathSway = math.sin(animValue * math.pi * 2) * 1.5;
    final bodyCenter = pos + Offset(0, -32 + breathSway);

    // Baş (Huşû ile kıbleye ve semaya hafif yönelmiş)
    final headCenter = bodyCenter + const Offset(0, -22);
    canvas.drawCircle(
      headCenter,
      7.5,
      Paint()..color = const Color(0xFFFFD5B3),
    );

    // İhram Alt Parçası (İzar - Belden Aşağısı)
    final izarPath = Path()
      ..moveTo(bodyCenter.dx - 9, bodyCenter.dy + 6)
      ..lineTo(bodyCenter.dx + 9, bodyCenter.dy + 6)
      ..lineTo(bodyCenter.dx + 12, bodyCenter.dy + 30)
      ..lineTo(bodyCenter.dx - 12, bodyCenter.dy + 30)
      ..close();
    canvas.drawPath(izarPath, Paint()..color = const Color(0xFFEDEDED));

    // İhram Üst Parçası (Rida - Omuz ve Gövde Örtüsü)
    final ridaRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: bodyCenter + const Offset(0, -6),
        width: 22,
        height: 26,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(ridaRRect, Paint()..color = Colors.white);

    // İhram Kıvrım Çizgisi (Rida drapesi)
    final drapePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      bodyCenter + const Offset(-7, -14),
      bodyCenter + const Offset(5, 4),
      drapePaint,
    );

    // Dua Eden Kollar (Semaya Açılmış İki Kol & Avuçlar)
    final armPaint = Paint()
      ..color = const Color(0xFFFFD5B3)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    // Sol Kol (Yalvarış açısında yukarı)
    final leftHand = Offset(
      bodyCenter.dx - 11,
      bodyCenter.dy - 18 - (breathSway * 0.8),
    );
    canvas.drawLine(bodyCenter + const Offset(-6, -11), leftHand, armPaint);
    canvas.drawCircle(leftHand, 2.2, armPaint);

    // Sağ Kol (Yalvarış açısında yukarı)
    final rightHand = Offset(
      bodyCenter.dx + 11,
      bodyCenter.dy - 18 - (breathSway * 0.8),
    );
    canvas.drawLine(bodyCenter + const Offset(6, -11), rightHand, armPaint);
    canvas.drawCircle(rightHand, 2.2, armPaint);
  }

  void _drawAscendingPrayers(Canvas canvas, double w, double h) {
    // Hacının ellerinden göğe yükselen altın dua ve nur tanecikleri
    const particleCount = 10;
    final sourceX = w * 0.24;
    final sourceY = h * 0.64;

    for (int i = 0; i < particleCount; i++) {
      final pProgress = (animValue + (i / particleCount)) % 1.0;
      final py = sourceY - (pProgress * (h * 0.52));
      final px = sourceX + (math.sin(pProgress * math.pi * 4 + i) * 16.0);
      final alpha = (math.sin(pProgress * math.pi) * 0.75).clamp(0.0, 1.0);

      final pPaint = Paint()
        ..color = RehberTheme.goldLight.withValues(alpha: alpha);
      canvas.drawCircle(Offset(px, py), 1.8 + (1.0 - pProgress), pPaint);
    }
  }

  void _drawStageBadge(Canvas canvas, double w, double h, bool isNight) {
    // Alt Bilgi Rozeti
    final String label;
    switch (vakfeIndex) {
      case 0:
        label = 'Arafat Sınırları & Cebelü’r-Rahme';
        break;
      case 1:
        label = 'Nemire Mescidi · Cem-i Takdim';
        break;
      case 2:
        label = 'Arafat Vakfesi · Duaların Kabul Vakti';
        break;
      case 3:
        label = 'Müzdelife’ye İntikal (Gurub Vakti)';
        break;
      case 4:
        label = 'Müzdelife · Akşam ve Yatsı Cem-i Tehir';
        break;
      default:
        label = 'Meş’ar-i Haram · 70 Taş Toplama';
        break;
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.8,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeWidth = textPainter.width + 20;
    const badgeHeight = 22.0;
    final badgeRect = Rect.fromCenter(
      center: Offset(w * 0.50, h * 0.90),
      width: badgeWidth,
      height: badgeHeight,
    );

    // Rozet Arka Planı
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(11)),
      Paint()..color = Colors.black.withValues(alpha: 0.65),
    );

    // Rozet Altın Çerçevesi
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(11)),
      Paint()
        ..color = RehberTheme.goldLight.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    textPainter.paint(
      canvas,
      Offset(
        badgeRect.left + 10,
        badgeRect.top + (badgeHeight - textPainter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _ArafatStagePainter oldDelegate) =>
      oldDelegate.animValue != animValue ||
      oldDelegate.vakfeIndex != vakfeIndex;
}
