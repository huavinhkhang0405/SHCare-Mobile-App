import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';

/* =========================================================
   FILE: animated_splash_screen.dart

   Vai trò:
   - Màn hình Intro animated premium thay thế RootScreen tĩnh
   - Chạy hiệu ứng thị giác (logo, glow, shimmer) song song
     với việc load data bất đồng bộ (auth, Firestore)
   - Khi cả animation lẫn data đều hoàn tất → navigate
     sang đúng màn hình đích, KHÔNG có độ trễ

   Kỹ thuật:
   - 4 AnimationController phân lớp (staggered)
   - Logic "Khóa Kép" (Dual-Wait): Future.wait() đồng bộ
     animation tối thiểu 1.5s + data loading
   - ShaderMask + LinearGradient cho text shimmer
   - Kiểm tra mounted trước mọi lệnh chuyển trang

   ⚠️ Lưu ý:
   - Dispose tất cả 4 controller trong dispose()
   - Không thêm logic UI phức tạp khác vào file này
   ========================================================= */

class AnimatedSplashScreen extends StatefulWidget {
  const AnimatedSplashScreen({super.key});

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with TickerProviderStateMixin {
  // ─── Animation Controllers ────────────────────────────────
  late final AnimationController _logoController;
  late final AnimationController _glowController;
  late final AnimationController _textController;
  late final AnimationController _shimmerController;

  // ─── Animations ───────────────────────────────────────────
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _glowPulse;
  late final Animation<double> _textFade;
  late final Animation<double> _textSlide;
  late final Animation<double> _shimmerSlide;

  // ─── State ────────────────────────────────────────────────
  /// Route đích sau khi load data xong
  String _destinationRoute = '/login';

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startSequence();
  }

  // ═══════════════════════════════════════════════════════════
  //  KHỞI TẠO ANIMATION
  // ═══════════════════════════════════════════════════════════

  void _initAnimations() {
    // 1) Logo: fade-in + scale (1200ms)
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _logoFade = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOut,
    );
    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );

    // 2) Glow ring: pulse vô hạn (1500ms mỗi vòng)
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _glowPulse = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // 3) Text: fade-in + slide lên (800ms)
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _textFade = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    );
    _textSlide = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    // 4) Shimmer: chạy vô hạn (1500ms mỗi vòng)
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _shimmerSlide = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  SEQUENCE CHÍNH: Chạy song song animation + load data
  // ═══════════════════════════════════════════════════════════

  Future<void> _startSequence() async {
    // Chạy đồng thời: animation timeline + data loading
    await Future.wait([
      _runAnimationTimeline(),
      _loadDataInBackground(),
    ]);

    // Cả 2 luồng đều xong → chuyển trang
    _navigateToDestination();
  }

  /// Chuỗi animation phân lớp (staggered) — tối thiểu 2 giây
  Future<void> _runAnimationTimeline() async {
    // 0ms: Logo fade-in + scale
    _logoController.forward();

    // 400ms: Glow ring bắt đầu pulse
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _glowController.repeat(reverse: true);

    // 800ms: Text fade-in + slide
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _textController.forward();

    // 1000ms: Shimmer bắt đầu chạy
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _shimmerController.repeat();

    // Đợi thêm để tổng thời gian tối thiểu ~2s
    // (400 + 400 + 200 + 1000 = 2000ms)
    await Future.delayed(const Duration(milliseconds: 1000));
  }

  /// Load data bất đồng bộ ngầm (auth check, Firestore)
  Future<void> _loadDataInBackground() async {
    try {
      final auth = context.read<AuthProvider>();
      final firebaseUser = FirebaseAuth.instance.currentUser;

      if (firebaseUser != null) {
        // Đã đăng nhập → load UserModel từ Firestore
        await auth.loadCurrentUserModel();

        // Xác định đích đến
        if (auth.currentUser?.isOnboarded == true) {
          _destinationRoute = '/main';
        } else {
          _destinationRoute = '/onboarding';
        }
      } else {
        // Chưa đăng nhập
        _destinationRoute = '/login';
      }
    } catch (e) {
      debugPrint('🚨 [Splash] Lỗi load data: $e');
      _destinationRoute = '/login';
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  CHUYỂN TRANG (với kiểm tra mounted)
  // ═══════════════════════════════════════════════════════════

  void _navigateToDestination() {
    if (!mounted) return;

    Navigator.of(context).pushReplacementNamed(
      _destinationRoute,
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  DISPOSE — Giải phóng tất cả controller
  // ═══════════════════════════════════════════════════════════

  @override
  void dispose() {
    _logoController.dispose();
    _glowController.dispose();
    _textController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  //  BUILD UI
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A1628), Color(0xFF162033), Color(0xFF0D1A2A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // ─── Background particles decorative ──────────
            _buildBackgroundParticles(),

            // ─── Main content ─────────────────────────────
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),

                  // ─── Logo + Glow Ring ─────────────────
                  _buildLogoWithGlow(),

                  const SizedBox(height: 32),

                  // ─── App Name Text ────────────────────
                  _buildAppNameText(),

                  const SizedBox(height: 12),

                  // ─── Tagline ──────────────────────────
                  _buildTagline(),

                  const Spacer(flex: 3),

                  // ─── Bottom loading indicator ─────────
                  _buildLoadingIndicator(),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  WIDGET BUILDERS
  // ═══════════════════════════════════════════════════════════

  /// Logo ở giữa + vòng sáng pulse glow
  Widget _buildLogoWithGlow() {
    return AnimatedBuilder(
      animation: Listenable.merge([_logoController, _glowController]),
      builder: (context, child) {
        return FadeTransition(
          opacity: _logoFade,
          child: ScaleTransition(
            scale: _logoScale,
            child: SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Lớp Glow bên ngoài — viền xanh lá + vàng đồng
                  _buildGlowRing(),

                  // Logo chính
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Image.asset(
                          'assets/images/logo.jpg',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Vòng sáng pulse với gradient xanh lá → vàng đồng
  Widget _buildGlowRing() {
    return AnimatedBuilder(
      animation: _glowPulse,
      builder: (context, child) {
        final pulseValue = _glowPulse.value;
        return Container(
          width: 170,
          height: 170,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.transparent,
              width: 0,
            ),
            gradient: SweepGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.8 * pulseValue),
                const Color(0xFFD4A853).withValues(alpha: 0.6 * pulseValue), // Vàng đồng
                AppColors.primaryLight.withValues(alpha: 0.7 * pulseValue),
                const Color(0xFFD4A853).withValues(alpha: 0.5 * pulseValue),
                AppColors.primary.withValues(alpha: 0.8 * pulseValue),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25 * pulseValue),
                blurRadius: 30 * pulseValue,
                spreadRadius: 5 * pulseValue,
              ),
              BoxShadow(
                color: const Color(0xFFD4A853).withValues(alpha: 0.15 * pulseValue),
                blurRadius: 20 * pulseValue,
                spreadRadius: 3 * pulseValue,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Text "Smart Health Care" với hiệu ứng shimmer
  Widget _buildAppNameText() {
    return AnimatedBuilder(
      animation: Listenable.merge([_textController, _shimmerController]),
      builder: (context, child) {
        return FadeTransition(
          opacity: _textFade,
          child: Transform.translate(
            offset: Offset(0, _textSlide.value),
            child: ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  colors: const [
                    Color(0xFFE8FAF3), // Sáng nhạt
                    Color(0xFFFFFFFF), // Trắng tinh (điểm sáng shimmer)
                    Color(0xFF6FDCBA), // Xanh lá nhạt
                    Color(0xFFFFFFFF), // Trắng tinh
                    Color(0xFFE8FAF3), // Sáng nhạt
                  ],
                  stops: _calculateShimmerStops(_shimmerSlide.value),
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ).createShader(bounds);
              },
              blendMode: BlendMode.srcIn,
              child: const Text(
                'Smart Health Care',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'PlusJakartaSans',
                  letterSpacing: 1.2,
                  color: Colors.white, // Sẽ bị override bởi ShaderMask
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Tính toán stops cho shimmer gradient dựa trên animation value
  List<double> _calculateShimmerStops(double animValue) {
    // animValue chạy từ -1.0 → 2.0
    // Tạo ra 5 stops di chuyển từ trái sang phải
    final center = animValue.clamp(0.0, 1.0);
    return [
      (center - 0.3).clamp(0.0, 1.0),
      (center - 0.1).clamp(0.0, 1.0),
      center.clamp(0.0, 1.0),
      (center + 0.1).clamp(0.0, 1.0),
      (center + 0.3).clamp(0.0, 1.0),
    ];
  }

  /// Tagline nhỏ bên dưới tên app
  Widget _buildTagline() {
    return AnimatedBuilder(
      animation: _textController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _textFade,
          child: Transform.translate(
            offset: Offset(0, _textSlide.value * 0.5),
            child: Text(
              'Sức khỏe thông minh  •  Cuộc sống chất lượng',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontFamily: 'PlusJakartaSans',
                color: Colors.white.withValues(alpha: 0.5),
                letterSpacing: 0.5,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Linear progress indicator mỏng ở bottom
  Widget _buildLoadingIndicator() {
    return AnimatedBuilder(
      animation: _logoController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _logoFade,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 80),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                minHeight: 2.5,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Chấm sáng trang trí nền (tạo chiều sâu)
  Widget _buildBackgroundParticles() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _ParticlePainter(
            animationValue: _glowPulse.value,
            primaryColor: AppColors.primary,
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  CUSTOM PAINTER: Chấm sáng trang trí nền
// ═══════════════════════════════════════════════════════════════

class _ParticlePainter extends CustomPainter {
  final double animationValue;
  final Color primaryColor;

  _ParticlePainter({
    required this.animationValue,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Các "ngôi sao" / chấm sáng cố định vị trí, thay đổi opacity
    const particles = [
      _Particle(0.15, 0.2, 2.5, 0.3, 0.6),
      _Particle(0.82, 0.15, 1.8, 0.5, 0.6),
      _Particle(0.35, 0.75, 3.0, 0.2, 0.6),
      _Particle(0.7, 0.6, 2.0, 0.4, 0.6),
      _Particle(0.9, 0.8, 1.5, 0.35, 0.6),
      _Particle(0.1, 0.55, 2.2, 0.25, 0.6),
      _Particle(0.55, 0.12, 1.6, 0.45, 0.6),
      _Particle(0.25, 0.9, 2.8, 0.15, 0.6),
      _Particle(0.65, 0.35, 1.3, 0.55, 0.6),
      _Particle(0.45, 0.5, 2.0, 0.3, 0.6),
    ];

    for (final p in particles) {
      // Mỗi chấm pulse với phase khác nhau
      final phase = (animationValue + p.phase) % 1.0;
      final opacity = p.baseOpacity * (0.3 + 0.7 * math.sin(phase * math.pi));

      paint.color = primaryColor.withValues(alpha: opacity);
      canvas.drawCircle(
        Offset(size.width * p.x, size.height * p.y),
        p.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

/// Dữ liệu cho mỗi chấm sáng trang trí
class _Particle {
  final double x;
  final double y;
  final double radius;
  final double phase;
  final double baseOpacity;

  const _Particle(this.x, this.y, this.radius, this.phase, this.baseOpacity);
}
