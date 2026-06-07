import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';

/* =========================================================
   FILE: forgot_password_screen.dart

   Vai trò:
   - Màn hình Quên / Đặt lại mật khẩu
   - 2 trạng thái: Nhập email → Thông báo đã gửi
   - Tích hợp Firebase sendPasswordResetEmail
   - Timer 60s chống spam gửi lại

   ⚠️ Lưu ý:
   - Kiểm tra mounted sau mọi await
   - Disable nút ngay khi bấm (chống spam)
   - Error messages đã được dịch tiếng Việt trong AuthProvider
   ========================================================= */

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  bool _emailSent = false;
  int _resendCountdown = 0;
  Timer? _resendTimer;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _animController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _handleSendResetEmail() async {
    final auth = context.read<AuthProvider>();
    final success = await auth.resetPassword(_emailController.text.trim());

    if (!mounted) return;

    if (success) {
      setState(() => _emailSent = true);
      _startResendTimer();
      // Re-run animation for the success state
      _animController.reset();
      _animController.forward();
    }
  }

  Future<void> _handleResend() async {
    if (_resendCountdown > 0) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.resetPassword(_emailController.text.trim());

    if (!mounted) return;

    if (success) {
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email đã được gửi lại thành công!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.scaffoldBg,
        child: Stack(
          children: [
            // ─── Gradient header ───
            _buildGradientHeader(screenHeight),

            // ─── Content ───
            SafeArea(
              child: SingleChildScrollView(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      children: [
                        // ─── Top bar with back button ───
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              _buildBackButton(),
                              const Spacer(),
                            ],
                          ),
                        ),

                        SizedBox(height: screenHeight * 0.02),

                        // ─── Lock icon ───
                        _buildLockIcon(),

                        const SizedBox(height: 24),

                        // ─── Title & description ───
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: _emailSent
                              ? _buildSentState(auth)
                              : _buildInputState(auth),
                        ),

                        SizedBox(height: screenHeight * 0.05),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  GRADIENT HEADER
  // ═══════════════════════════════════════════════════════════

  Widget _buildGradientHeader(double screenHeight) {
    return Container(
      height: screenHeight * 0.42,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A1628), AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: CustomPaint(
        painter: _HeaderPatternPainter(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  LOCK ICON
  // ═══════════════════════════════════════════════════════════

  Widget _buildLockIcon() {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.primaryGradient,
          ),
          child: Icon(
            _emailSent ? Icons.mark_email_read_rounded : Icons.lock_reset_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  BACK BUTTON
  // ═══════════════════════════════════════════════════════════

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () {
        context.read<AuthProvider>().clearError();
        Navigator.of(context).pop();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: Colors.white,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  STATE 1: INPUT EMAIL
  // ═══════════════════════════════════════════════════════════

  Widget _buildInputState(AuthProvider auth) {
    return Column(
      children: [
        const Text(
          'Quên mật khẩu?',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Nhập email tài khoản của bạn.\nChúng tôi sẽ gửi link đặt lại mật khẩu.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 32),

        // ─── Error banner ───
        if (auth.errorMessage != null) ...[
          _buildErrorBanner(auth.errorMessage!),
          const SizedBox(height: 16),
        ],

        // ─── Email input ───
        _buildEmailInput(),

        const SizedBox(height: 28),

        // ─── Send button ───
        _buildSendButton(auth),

        const SizedBox(height: 24),

        // ─── Back to login link ───
        _buildBackToLoginLink(),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  STATE 2: EMAIL SENT
  // ═══════════════════════════════════════════════════════════

  Widget _buildSentState(AuthProvider auth) {
    return Column(
      children: [
        const SizedBox(height: 8),
        const Text(
          'Email đã được gửi!',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.email_outlined,
                color: AppColors.primary,
                size: 36,
              ),
              const SizedBox(height: 12),
              const Text(
                'Chúng tôi đã gửi link đặt lại mật khẩu đến:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _emailController.text.trim(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Kiểm tra hộp thư (và thư mục Spam) để tìm email từ Firebase.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textHint,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ─── Error banner (for resend errors) ───
        if (auth.errorMessage != null) ...[
          _buildErrorBanner(auth.errorMessage!),
          const SizedBox(height: 16),
        ],

        // ─── Resend button ───
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton(
            onPressed: (_resendCountdown > 0 || auth.isLoading)
                ? null
                : _handleResend,
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: _resendCountdown > 0
                    ? AppColors.cardBorder
                    : AppColors.primary,
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
              ),
            ),
            child: auth.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primary,
                    ),
                  )
                : Text(
                    _resendCountdown > 0
                        ? 'Gửi lại sau ${_resendCountdown}s'
                        : 'Gửi lại email',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _resendCountdown > 0
                          ? AppColors.textHint
                          : AppColors.primary,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 16),

        // ─── Back to login button ───
        SizedBox(
          width: double.infinity,
          height: 54,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FilledButton(
              onPressed: () {
                context.read<AuthProvider>().clearError();
                Navigator.of(context).pop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                ),
              ),
              child: const Text(
                'Quay về Đăng nhập',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ═══════════════════════════════════════════════════════════

  Widget _buildEmailInput() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'Nhập email của bạn',
          hintStyle: const TextStyle(
            color: AppColors.textHint,
            fontSize: 14,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(10),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.email_outlined,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AppColors.cardBorder.withValues(alpha: 0.5),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AppColors.cardBorder.withValues(alpha: 0.5),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: AppColors.primary,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton(AuthProvider auth) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FilledButton(
          onPressed: auth.isLoading ? null : _handleSendResetEmail,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
            ),
          ),
          child: auth.isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : const Text(
                  'Gửi email đặt lại',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildBackToLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.arrow_back_rounded,
          size: 16,
          color: AppColors.primary,
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () {
            context.read<AuthProvider>().clearError();
            Navigator.of(context).pop();
          },
          child: const Text(
            'Quay lại Đăng nhập',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  HEADER PATTERN PAINTER
// ═══════════════════════════════════════════════════════════════

class _HeaderPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    // Floating circles decoration
    const circles = [
      _Circle(0.1, 0.3, 40, 0.06),
      _Circle(0.85, 0.2, 60, 0.04),
      _Circle(0.7, 0.7, 30, 0.08),
      _Circle(0.3, 0.8, 50, 0.05),
      _Circle(0.5, 0.15, 25, 0.07),
    ];

    for (final c in circles) {
      paint.color = Colors.white.withValues(alpha: c.opacity);
      canvas.drawCircle(
        Offset(size.width * c.x, size.height * c.y),
        c.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Circle {
  final double x, y, radius, opacity;
  const _Circle(this.x, this.y, this.radius, this.opacity);
}
