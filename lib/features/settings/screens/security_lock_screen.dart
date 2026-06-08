import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/settings_provider.dart';
import '../../../core/config/app_localizations.dart';
import '../../../services/security_service.dart';

class SecurityLockScreen extends StatefulWidget {
  final VoidCallback onUnlockSuccess;
  
  const SecurityLockScreen({
    super.key,
    required this.onUnlockSuccess,
  });

  @override
  State<SecurityLockScreen> createState() => _SecurityLockScreenState();
}

class _SecurityLockScreenState extends State<SecurityLockScreen> {
  String _pin = '';
  int _remainingAttempts = 5;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerBiometricsIfEnabled();
    });
  }

  Future<void> _triggerBiometricsIfEnabled() async {
    final settings = context.read<SettingsProvider>();
    if (settings.biometricsEnabled && settings.isBiometricsAvailable) {
      final success = await SecurityService.authenticateBiometrics(
        context.tr('biometric_reason'),
      );
      if (success) {
        HapticFeedback.lightImpact();
        widget.onUnlockSuccess();
      }
    }
  }

  void _onKeyPress(String value) {
    if (_pin.length >= 4) return;

    HapticFeedback.lightImpact();
    setState(() {
      _errorMessage = null;
      _pin += value;
    });

    if (_pin.length == 4) {
      _verifyPIN();
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _errorMessage = null;
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  Future<void> _verifyPIN() async {
    // Cho phép UI render chấm thứ 4 hoàn chỉnh trước khi xử lý xác thực/chuyển màn hình
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    
    final correct = await SecurityService.verifyPIN(_pin);
    if (correct) {
      HapticFeedback.mediumImpact();
      widget.onUnlockSuccess();
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _remainingAttempts--;
        _pin = '';
        if (_remainingAttempts <= 0) {
          _errorMessage = 'Đã hết số lần thử! Vui lòng thử lại sau.';
        } else {
          _errorMessage = context.tr('invalid_pin', arguments: {
            'attempts': _remainingAttempts.toString(),
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            
            // App Logo or Lock Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: AppColors.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            
            Text(
              context.tr('unlock_app'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('enter_pin'),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),

            // PIN Dots Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isFilled = index < _pin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isFilled ? AppColors.primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isFilled ? AppColors.primary : AppColors.textHint,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],

            const Spacer(flex: 3),

            // Keypad
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['1', '2', '3'].map((val) => _buildKeypadButton(val)).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['4', '5', '6'].map((val) => _buildKeypadButton(val)).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['7', '8', '9'].map((val) => _buildKeypadButton(val)).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Biometric trigger button
                      settings.biometricsEnabled && settings.isBiometricsAvailable
                          ? _buildKeypadIconButton(
                              Icons.fingerprint_rounded,
                              _triggerBiometricsIfEnabled,
                            )
                          : const SizedBox(width: 72, height: 72),
                      _buildKeypadButton('0'),
                      _buildKeypadIconButton(
                        Icons.backspace_outlined,
                        _onBackspace,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadButton(String value) {
    return SizedBox(
      width: 72,
      height: 72,
      child: OutlinedButton(
        onPressed: _remainingAttempts <= 0 ? null : () => _onKeyPress(value),
        style: OutlinedButton.styleFrom(
          shape: const CircleBorder(),
          side: const BorderSide(color: AppColors.cardBorder, width: 1.5),
          padding: EdgeInsets.zero,
          foregroundColor: AppColors.textPrimary,
        ),
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadIconButton(IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: 72,
      height: 72,
      child: IconButton(
        onPressed: _remainingAttempts <= 0 ? null : onPressed,
        icon: Icon(icon, size: 26, color: AppColors.textPrimary),
        style: IconButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
