import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/sharebite_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final AnimationController _particleCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _scaleAnim = Tween<double>(begin: 0.96, end: 1.05).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _fadeAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );

    _initApp();
  }

  Future<void> _initApp() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    await auth.initialize();
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      auth.isAuthenticated ? '/main' : '/login',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Floating particles
            AnimatedBuilder(
              animation: _particleCtrl,
              builder: (_, __) => CustomPaint(
                painter: _ParticlePainter(_particleCtrl.value),
                child: const SizedBox.expand(),
              ),
            ),
            // Logo
            Center(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(38),
                      border: Border.all(color: Colors.white.withOpacity(0.28)),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryDark.withOpacity(0.24),
                          blurRadius: 34,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: const ShareBiteLogo(size: 126, radius: 32),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double progress;
  _ParticlePainter(this.progress);

  static final _rng = math.Random(42);
  static final _particles = List.generate(18, (i) => _Particle(
    x: _rng.nextDouble(),
    y: _rng.nextDouble(),
    radius: 3 + _rng.nextDouble() * 6,
    speed: 0.15 + _rng.nextDouble() * 0.25,
    phase: _rng.nextDouble(),
    opacity: 0.06 + _rng.nextDouble() * 0.12,
  ));

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final t = (progress * p.speed + p.phase) % 1.0;
      final y = size.height * (1.0 - t);
      final x = size.width * p.x + math.sin(t * math.pi * 2 + p.phase * 6) * 20;
      final paint = Paint()
        ..color = Colors.white.withOpacity(p.opacity * (1 - (t - 0.5).abs() * 2).clamp(0, 1))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}

class _Particle {
  final double x, y, radius, speed, phase, opacity;
  const _Particle({required this.x, required this.y, required this.radius, required this.speed, required this.phase, required this.opacity});
}
