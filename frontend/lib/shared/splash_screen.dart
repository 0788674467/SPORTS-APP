import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ───────────────────────────── controllers ──────────────────────────────
  late final AnimationController _bgCtrl;
  late final AnimationController _ballCtrl;
  late final AnimationController _goalCtrl;
  late final AnimationController _logoCtrl;
  late final AnimationController _particleCtrl;
  late final AnimationController _shimmerCtrl;

  // ───────────────────────── bg / overlay animations ──────────────────────
  late final Animation<double> _overlayOpacity;
  late final Animation<double> _trophyScale;
  late final Animation<double> _trophyOpacity;

  // ─────────────────────────── ball animations ────────────────────────────
  late final Animation<Offset> _ballPosition;
  late final Animation<double> _ballScale;
  late final Animation<double> _ballSpin;
  late final Animation<double> _ballOpacity;

  // ─────────────────────────── goal animations ────────────────────────────
  late final Animation<double> _goalOpacity;
  late final Animation<double> _netWave;

  // ─────────────────────────── logo animations ────────────────────────────
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<Offset> _titleSlide;
  late final Animation<Offset> _subtitleSlide;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();

    // Background fades in quickly
    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _overlayOpacity = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _bgCtrl, curve: Curves.easeIn));
    _trophyScale = Tween(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _bgCtrl, curve: Curves.elasticOut));
    _trophyOpacity = Tween(begin: 0.0, end: 0.22).animate(
        CurvedAnimation(parent: _bgCtrl, curve: Curves.easeIn));

    // Goal fades in after bg
    _goalCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _goalOpacity = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _goalCtrl, curve: Curves.easeOut));
    _netWave = Tween(begin: 0.0, end: 1.0).animate(_goalCtrl);

    // Ball arcs across the screen and goes into the goal
    _ballCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _ballPosition = Tween<Offset>(
      begin: const Offset(-0.5, 0.65),
      end: const Offset(0.5, 0.37),
    ).animate(CurvedAnimation(parent: _ballCtrl, curve: Curves.easeInOut));
    _ballScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 0.55), weight: 60),
    ]).animate(CurvedAnimation(parent: _ballCtrl, curve: Curves.easeInOut));
    _ballSpin = Tween(begin: 0.0, end: 3 * pi).animate(_ballCtrl);
    _ballOpacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 80),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 10),
    ]).animate(_ballCtrl);

    // Logo fades/slides in after ball scores
    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _logoScale = Tween(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoOpacity = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut));
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut));
    _subtitleSlide = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut)));

    // Particle burst after goal
    _particleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));

    // Shimmer on logo text
    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat();
    _shimmer = Tween(begin: -2.0, end: 2.0).animate(
        CurvedAnimation(parent: _shimmerCtrl, curve: Curves.linear));

    _runSequence();
  }

  Future<void> _runSequence() async {
    await _bgCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    _goalCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    await _ballCtrl.forward();
    // ball reached goal – flash & particles
    await _particleCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 2200));
    widget.onComplete();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _ballCtrl.dispose();
    _goalCtrl.dispose();
    _logoCtrl.dispose();
    _particleCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────── build ──────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.navyDark,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: AnimatedBuilder(
          animation: Listenable.merge(
              [_bgCtrl, _ballCtrl, _goalCtrl, _logoCtrl, _particleCtrl, _shimmerCtrl]),
          builder: (ctx, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                // ── 1. Navy gradient background ──────────────────────────
                _buildBackground(size),

                // ── 2. Trophy watermark ──────────────────────────────────
                _buildTrophy(size),

                // ── 3. Pitch lines (subtle) ──────────────────────────────
                _buildPitchLines(size),

                // ── 4. Colour overlay gradient ───────────────────────────
                Opacity(
                  opacity: _overlayOpacity.value,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xCC001A4D), // navyDark
                          Color(0xB3003087), // mmwNavy
                          Color(0xD9001A4D), // navyDark
                        ],
                      ),
                    ),
                  ),
                ),

                // ── 5. Goal post ─────────────────────────────────────────
                _buildGoal(size),

                // ── 6. Particle burst ────────────────────────────────────
                if (_particleCtrl.value > 0)
                  _buildParticles(size),

                // ── 7. Fire Trail (Rocket effect) ──────────────────────
                _buildFireTrail(size),

                // ── 8. Soccer ball (san.jpeg) ───────────────────────────
                _buildBall(size),

                // ── 9. Logo + text ───────────────────────────────────────
                _buildLogo(size),
              ],
            );
          },
        ),
      ),
    );
  }

  // ────────────────────────── sub-builders ────────────────────────────────

  Widget _buildBackground(Size size) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.2),
          radius: 1.4,
          colors: [
            Color(0xFF003087), // mmwNavy centre
            Color(0xFF001A4D), // navyDark edges
          ],
        ),
      ),
    );
  }

  Widget _buildTrophy(Size size) {
    return Center(
      child: Opacity(
        opacity: _trophyOpacity.value,
        child: Transform.scale(
          scale: _trophyScale.value,
          child: Image.asset(
            'assets/trophy.png',
            width: size.width * 0.8,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildPitchLines(Size size) {
    return CustomPaint(
      painter: _PitchLinesPainter(opacity: _overlayOpacity.value * 0.18),
      size: size,
    );
  }

  Widget _buildGoal(Size size) {
    final w = size.width * 0.55;
    final h = size.height * 0.22;
    final top = size.height * 0.22;
    final left = (size.width - w) / 2;

    return Positioned(
      top: top,
      left: left,
      width: w,
      height: h,
      child: Opacity(
        opacity: _goalOpacity.value,
        child: CustomPaint(
          painter: _GoalPainter(
            netWave: _netWave.value,
            flash: _particleCtrl.value,
          ),
        ),
      ),
    );
  }

  Widget _buildFireTrail(Size size) {
    if (_ballCtrl.value <= 0 || _ballCtrl.value >= 1.0) return const SizedBox.shrink();

    final t = _ballCtrl.value;
    final cx = size.width * (_ballPosition.value.dx + 0.5);
    final arcY = -size.height * 0.18 * sin(t * pi);
    final cy = size.height * _ballPosition.value.dy + arcY;

    // Calculate direction for the trail (tangent to arc)
    final dt = 0.01;
    final nextT = (t + dt).clamp(0.0, 1.0);
    
    // Position of ball at next step for direction
    final nextCx = size.width * (_ballPosition.value.dx + 0.05); // Approximate shift
    final nextArcY = -size.height * 0.18 * sin(nextT * pi);
    final nextCy = size.height * _ballPosition.value.dy + nextArcY;

    final angle = atan2(nextCy - cy, nextCx - cx);

    return CustomPaint(
      painter: _FireTrailPainter(
        position: Offset(cx, cy),
        angle: angle,
        progress: t,
      ),
      size: size,
    );
  }

  /// Ball uses san.jpeg clipped to a circle
  Widget _buildBall(Size size) {
    final cx = size.width * (_ballPosition.value.dx + 0.5);
    final t = _ballCtrl.value;
    final arcY = -size.height * 0.18 * sin(t * pi);
    final cy = size.height * _ballPosition.value.dy + arcY;
    final r = 28.0 * _ballScale.value;

    return Positioned(
      left: cx - r,
      top: cy - r,
      child: Opacity(
        opacity: _ballOpacity.value,
        child: Transform.rotate(
          angle: _ballSpin.value,
          child: Container(
            width: r * 2,
            height: r * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.mmwGold.withOpacity(0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.6 * _ballCtrl.value),
                  blurRadius: 20 * _ballCtrl.value,
                  spreadRadius: 5 * _ballCtrl.value,
                ),
                BoxShadow(
                  color: AppColors.mmwNavy.withOpacity(0.4),
                  blurRadius: 12,
                ),
              ],
            ),
            clipBehavior: Clip.hardEdge,
            child: Image.asset(
              'assets/images/san.jpeg',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParticles(Size size) {
    return CustomPaint(
      painter: _ParticlePainter(
        progress: _particleCtrl.value,
        center: Offset(size.width / 2, size.height * 0.33),
      ),
      size: size,
    );
  }

  Widget _buildLogo(Size size) {
    return Positioned(
      bottom: size.height * 0.08,
      left: 0,
      right: 0,
      child: Opacity(
        opacity: _logoOpacity.value,
        child: SlideTransition(
          position: _titleSlide,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Glowing circle emblem with ball.jpeg
              _buildEmblem(),
              const SizedBox(height: 20),
              // UNILEAGUE — gold shimmer
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment(_shimmer.value - 1, 0),
                  end: Alignment(_shimmer.value + 1, 0),
                  colors: const [
                    Color(0xFFC47A00), // goldDark
                    Color(0xFFF5A500), // mmwGold
                    Color(0xFFFFD966), // bright gold
                    Color(0xFFF5A500), // mmwGold
                    Color(0xFFC47A00), // goldDark
                  ],
                  stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                ).createShader(bounds),
                child: Text(
                  'UNILEAGUE',
                  style: GoogleFonts.orbitron(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Subtitle in green accent
              SlideTransition(
                position: _subtitleSlide,
                child: Text(
                  'U  C R E A T E',
                  style: GoogleFonts.rajdhani(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 10,
                    color: AppColors.mmwGreen,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Loading dots — navy to gold pulse
              _buildLoadingDots(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmblem() {
    return Transform.scale(
      scale: _logoScale.value,
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [AppColors.mmwNavy, AppColors.navyDark],
          ),
          border: Border.all(color: AppColors.mmwGold, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.mmwGold.withOpacity(0.4),
              blurRadius: 24,
              spreadRadius: 4,
            ),
            BoxShadow(
              color: AppColors.mmwNavy.withOpacity(0.5),
              blurRadius: 40,
              spreadRadius: 8,
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Image.asset(
          'assets/images/san.jpeg',
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildLoadingDots() {
    final t = _shimmerCtrl.value;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final phase = (t - i * 0.25).clamp(0.0, 1.0);
        final brightness = (sin(phase * 2 * pi) * 0.5 + 0.5).clamp(0.2, 1.0);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.lerp(
              AppColors.mmwNavy,
              AppColors.mmwGold,
              brightness,
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────── Goal Post ──────────────────────────────────────

class _GoalPainter extends CustomPainter {
  final double netWave;
  final double flash;
  _GoalPainter({required this.netWave, required this.flash});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Flash overlay when ball enters — gold flash (on-brand)
    if (flash > 0 && flash < 0.5) {
      final fp = Paint()
        ..color = AppColors.mmwGold.withOpacity(flash * 0.6)
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), fp);
    }

    // Net lines – horizontal
    final netPaint = Paint()
      ..color = Colors.white.withOpacity(0.25 + flash * 0.2)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const rows = 8;
    const cols = 12;
    for (int r = 1; r < rows; r++) {
      final y = h * r / rows;
      final waveOffset = sin(netWave * pi * 2 + r * 0.4) * 3 * netWave;
      final path = Path()..moveTo(0, y + waveOffset);
      for (double x = 0; x <= w; x += 4) {
        path.lineTo(x, y + sin(x * 0.3 + netWave * pi) * 2 * netWave);
      }
      canvas.drawPath(path, netPaint);
    }
    // Vertical
    for (int c = 1; c < cols; c++) {
      final x = w * c / cols;
      canvas.drawLine(Offset(x, 0), Offset(x, h), netPaint);
    }

    // Goal frame
    final framePaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..strokeWidth = 5
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final frame = Path()
      ..moveTo(0, h)
      ..lineTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h);
    canvas.drawPath(frame, framePaint);

    // Crossbar glow — gold on-brand
    final shadowPaint = Paint()
      ..color = AppColors.mmwGold.withOpacity(0.3 + flash * 0.4)
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawLine(Offset(0, 0), Offset(w, 0), shadowPaint);
    canvas.drawLine(Offset(0, 0), Offset(0, h), shadowPaint);
    canvas.drawLine(Offset(w, 0), Offset(w, h), shadowPaint);
  }

  @override
  bool shouldRepaint(covariant _GoalPainter old) =>
      old.netWave != netWave || old.flash != flash;
}

// ─────────────────────────── Particles ──────────────────────────────────────

class _ParticlePainter extends CustomPainter {
  final double progress;
  final Offset center;
  final _rng = Random(42);

  _ParticlePainter({required this.progress, required this.center});

  @override
  void paint(Canvas canvas, Size size) {
    const count = 40;
    // MMU brand palette particle colors
    const colors = [
      AppColors.mmwGold,
      AppColors.mmwNavy,
      AppColors.mmwGreen,
      Colors.white,
      Color(0xFFF5A500), // gold duplicate for frequency
    ];
    for (int i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 80 + _rng.nextDouble() * 180;
      final x = center.dx + cos(angle) * speed * progress;
      final y = center.dy + sin(angle) * speed * progress - 60 * progress * progress;
      final opacity = (1 - progress).clamp(0.0, 1.0);
      final radius = (3 + _rng.nextDouble() * 5) * (1 - progress * 0.5);

      final paint = Paint()
        ..color = colors[i % colors.length].withOpacity(opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) =>
      old.progress != progress;
}

// ──────────────────────────── Pitch Lines ───────────────────────────────────

class _PitchLinesPainter extends CustomPainter {
  final double opacity;
  _PitchLinesPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;

    // Centre circle
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.22, paint);
    // Centre spot
    final spotPaint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w / 2, h / 2), 4, spotPaint);
    // Halfway line
    canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), paint);
    // Outer boundary
    canvas.drawRect(
        Rect.fromLTWH(w * 0.04, h * 0.04, w * 0.92, h * 0.92), paint);
    // Penalty area top
    canvas.drawRect(
        Rect.fromLTWH(w * 0.2, h * 0.04, w * 0.6, h * 0.25), paint);
    // Penalty area bottom
    canvas.drawRect(
        Rect.fromLTWH(w * 0.2, h * 0.71, w * 0.6, h * 0.25), paint);
  }

  @override
  bool shouldRepaint(covariant _PitchLinesPainter old) =>
      old.opacity != opacity;
}

// ─────────────────────────── Fire Trail Painter ────────────────────────────

class _FireTrailPainter extends CustomPainter {
  final Offset position;
  final double angle;
  final double progress;
  final _rng = Random(77);

  _FireTrailPainter({
    required this.position,
    required this.angle,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < 0.1) return;

    final paint = Paint()
      ..style = PaintingStyle.fill;

    // Trail length increases as it moves
    final trailLength = 120.0 * progress;
    final particleCount = (30 * progress).toInt();

    for (int i = 0; i < particleCount; i++) {
      final pT = _rng.nextDouble();
      final distance = pT * trailLength;

      // Particle position along the tail (opposite to move direction)
      final px = position.dx - cos(angle) * distance + (_rng.nextDouble() - 0.5) * 20;
      final py = position.dy - sin(angle) * distance + (_rng.nextDouble() - 0.5) * 20;

      final opacity = (1.0 - pT) * (progress * 1.5).clamp(0.0, 1.0);
      final radius = 12.0 * (1.0 - pT) * _rng.nextDouble();

      // Fire colors: white/yellow core to orange/red edges
      final color = Color.lerp(
        Colors.white,
        i % 2 == 0 ? Colors.orange : Colors.redAccent,
        pT,
      )!;

      paint.color = color.withOpacity(opacity);
      canvas.drawCircle(Offset(px, py), radius, paint);
    }

    // High speed "Rocket" lines
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.4 * progress)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 5; i++) {
      final lineDist = 40.0 + _rng.nextDouble() * 100.0 * progress;
      final startPos = Offset(
        position.dx - cos(angle) * 30,
        position.dy - sin(angle) * 30,
      );
      final endPos = Offset(
        startPos.dx - cos(angle) * lineDist,
        startPos.dy - sin(angle) * lineDist,
      );
      canvas.drawLine(startPos, endPos, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FireTrailPainter old) =>
      old.position != position || old.progress != progress;
}

extension on double {
  double interpolate(double target) {
    return this + (target - this); 
  }
}

extension _OffsetInterpolation on Offset {
  Offset interpolate(Offset target, double t) {
    return Offset.lerp(this, target, t)!;
  }
}
