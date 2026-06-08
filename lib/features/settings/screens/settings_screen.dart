import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/settings_provider.dart';
import '../../../core/config/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isClearingCache = false;

  @override
  void initState() {
    super.initState();
    // Bỏ qua thời gian trễ (delay) khi chạy widget test để tránh treo pumpAndSettle
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<SettingsProvider>().calculateCacheSize();
        }
      });
    } else {
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted) {
          context.read<SettingsProvider>().calculateCacheSize();
        }
      });
    }
  }

  final List<Color> _colorSeeds = const [
    Color(0xFF0FA87E), // Emerald Green (Default)
    Color(0xFF4A90D9), // Sky Blue
    Color(0xFF8B5CF6), // Royal Purple
    Color(0xFFF59E0B), // Amber Orange
    Color(0xFFEF4444), // Crimson Red
  ];

  final Map<String, String> _languages = const {
    'vi': 'Tiếng Việt 🇻🇳',
    'en': 'English 🇬🇧',
    'ja': '日本語 🇯🇵',
    'ko': '한국어 🇰🇷',
    'zh': '中文 🇨🇳',
  };

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text(
          context.tr('settings'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Theme Color Selector Section ───
            _buildSectionHeader(context.tr('theme_color'), Icons.palette_outlined),
            _buildThemeColorSelector(settings),
            const SizedBox(height: 24),

            // ─── Language Selector Section ───
            _buildSectionHeader(context.tr('language'), Icons.language_rounded),
            _buildLanguageSelector(settings),
            const SizedBox(height: 24),

            // ─── Notifications Section ───
            _buildSectionHeader(context.tr('notifications'), Icons.notifications_none_rounded),
            _buildNotificationCard(settings),
            const SizedBox(height: 24),

            // ─── Security Lock Section ───
            _buildSectionHeader(context.tr('security_lock'), Icons.lock_outline_rounded),
            _buildSecurityCard(context, settings),
            const SizedBox(height: 24),

            // ─── Cache Management Section ───
            _buildSectionHeader(context.tr('cache_size'), Icons.cleaning_services_outlined),
            _buildCacheCard(context, settings),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeColorSelector(SettingsProvider settings) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: _colorSeeds.map((color) {
          final isSelected = settings.themeColorHex == color.value;
          return GestureDetector(
            onTap: () => settings.updateThemeColor(color),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(isSelected ? 0.4 : 0.15),
                    blurRadius: isSelected ? 12 : 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLanguageSelector(SettingsProvider settings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.softShadow,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: settings.languageCode,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textHint),
          items: _languages.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Text(
                entry.value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              settings.updateLanguage(val);
            }
          },
        ),
      ),
    );
  }

  Widget _buildNotificationCard(SettingsProvider settings) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.softShadow,
      ),
      child: SwitchListTile(
        activeColor: Colors.white,
        activeTrackColor: Color(AppColors.primaryHex),
        inactiveThumbColor: AppColors.textHint,
        inactiveTrackColor: AppColors.cardBorder,
        title: Text(
          context.tr('notifications'),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          context.tr('notifications_desc'),
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        value: settings.notificationsEnabled,
        onChanged: (val) => settings.toggleNotifications(val),
      ),
    );
  }

  Widget _buildSecurityCard(BuildContext context, SettingsProvider settings) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        children: [
          SwitchListTile(
            activeColor: Colors.white,
            activeTrackColor: Color(AppColors.primaryHex),
            inactiveThumbColor: AppColors.textHint,
            inactiveTrackColor: AppColors.cardBorder,
            title: Text(
              context.tr('security_lock'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            subtitle: Text(
              context.tr('security_lock_desc'),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            value: settings.pinLockEnabled,
            onChanged: (val) {
              if (val) {
                _showPINSetupDialog(context, settings);
              } else {
                settings.togglePinLock(false);
              }
            },
          ),
          if (settings.pinLockEnabled && settings.isBiometricsAvailable) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Divider(height: 1),
            ),
            SwitchListTile(
              activeColor: Colors.white,
              activeTrackColor: Color(AppColors.primaryHex),
              inactiveThumbColor: AppColors.textHint,
              inactiveTrackColor: AppColors.cardBorder,
              title: Text(
                context.tr('use_biometric'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              subtitle: Text(
                context.tr('use_biometric_desc'),
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              value: settings.biometricsEnabled,
              onChanged: (val) => settings.toggleBiometrics(val),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCacheCard(BuildContext context, SettingsProvider settings) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${settings.cacheSizeMB.toStringAsFixed(2)} MB',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('clear_cache'),
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          _isClearingCache
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : IconButton.filledTonal(
                  onPressed: () async {
                    setState(() {
                      _isClearingCache = true;
                    });
                    await settings.clearCache();
                    setState(() {
                      _isClearingCache = false;
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.tr('clear_cache_success')),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primarySurface,
                    foregroundColor: AppColors.primary,
                  ),
                ),
        ],
      ),
    );
  }

  void _showPINSetupDialog(BuildContext context, SettingsProvider settings) {
    final pinController1 = TextEditingController();
    final pinController2 = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: AppColors.cardBg,
          title: Text(
            context.tr('pin_setup'),
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: pinController1,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 4,
                    decoration: InputDecoration(
                      labelText: context.tr('enter_pin'),
                      counterText: '',
                    ),
                    validator: (val) {
                      if (val == null || val.length != 4 || int.tryParse(val) == null) {
                        return 'Vui lòng nhập đúng 4 chữ số';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: pinController2,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 4,
                    decoration: InputDecoration(
                      labelText: context.tr('confirm_pin'),
                      counterText: '',
                    ),
                    validator: (val) {
                      if (val != pinController1.text) {
                        return context.tr('pin_mismatch');
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  settings.togglePinLock(true, pinToSave: pinController1.text);
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.tr('pin_save_success')),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
  }
}
