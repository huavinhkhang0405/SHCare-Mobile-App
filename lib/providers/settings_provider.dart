import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../core/theme/app_colors.dart';
import '../services/notification_service.dart';
import '../services/security_service.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _colorKey = 'settings_theme_color';
  static const String _langKey = 'settings_language';
  static const String _notifKey = 'settings_notifications_enabled';
  static const String _lockKey = 'settings_pin_lock_enabled';
  static const String _bioKey = 'settings_biometrics_enabled';

  SharedPreferences? _prefs;

  // Defaults
  int _themeColorHex = 0xFF0FA87E;
  String _languageCode = 'vi';
  bool _notificationsEnabled = true;
  bool _pinLockEnabled = false;
  bool _biometricsEnabled = false;
  double _cacheSizeMB = 0.0;
  bool _isBiometricsAvailable = false;

  // Getters
  int get themeColorHex => _themeColorHex;
  String get languageCode => _languageCode;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get pinLockEnabled => _pinLockEnabled;
  bool get biometricsEnabled => _biometricsEnabled;
  double get cacheSizeMB => _cacheSizeMB;
  bool get isBiometricsAvailable => _isBiometricsAvailable;

  Locale get locale {
    switch (_languageCode) {
      case 'vi':
        return const Locale('vi', 'VN');
      case 'en':
        return const Locale('en', 'US');
      case 'ja':
        return const Locale('ja', 'JP');
      case 'ko':
        return const Locale('ko', 'KR');
      case 'zh':
        return const Locale('zh', 'CN');
      default:
        return const Locale('vi', 'VN');
    }
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    
    _themeColorHex = _prefs?.getInt(_colorKey) ?? 0xFF0FA87E;
    _languageCode = _prefs?.getString(_langKey) ?? 'vi';
    _notificationsEnabled = _prefs?.getBool(_notifKey) ?? true;
    
    // Security lock is active only if PIN is stored
    final hasPin = await SecurityService.hasPIN();
    _pinLockEnabled = (hasPin && (_prefs?.getBool(_lockKey) ?? false));
    _biometricsEnabled = _prefs?.getBool(_bioKey) ?? false;
    
    // Tạm thời vô hiệu hóa sinh trắc học theo yêu cầu người dùng
    _isBiometricsAvailable = false;

    // Apply color setting to global system colors
    AppColors.updatePrimaryColor(Color(_themeColorHex));

    notifyListeners();
  }

  Future<void> updateThemeColor(Color newColor) async {
    _themeColorHex = newColor.value;
    AppColors.updatePrimaryColor(newColor);
    // Allow the local button tap and selection animation to complete smoothly
    await Future.delayed(const Duration(milliseconds: 150));
    notifyListeners();
    await _prefs?.setInt(_colorKey, _themeColorHex);
  }

  Future<void> updateLanguage(String langCode) async {
    _languageCode = langCode;
    // Allow dropdown popup close animation to complete smoothly
    await Future.delayed(const Duration(milliseconds: 300));
    notifyListeners();
    await _prefs?.setString(_langKey, langCode);
  }

  Future<void> toggleNotifications(bool value) async {
    _notificationsEnabled = value;
    // Allow switch animation to transition smoothly
    await Future.delayed(const Duration(milliseconds: 150));
    notifyListeners();
    await _prefs?.setBool(_notifKey, value);
    if (!value) {
      // Cancel all pending/scheduled notifications
      await NotificationService.cancelAllPendingNotifications();
    }
  }

  Future<void> togglePinLock(bool value, {String? pinToSave}) async {
    if (value && pinToSave != null) {
      await SecurityService.savePIN(pinToSave);
      _pinLockEnabled = true;
    } else if (!value) {
      await SecurityService.clearPIN();
      _pinLockEnabled = false;
      _biometricsEnabled = false;
      await _prefs?.setBool(_bioKey, false);
    }
    // Allow switch animation to transition smoothly
    await Future.delayed(const Duration(milliseconds: 150));
    notifyListeners();
    await _prefs?.setBool(_lockKey, _pinLockEnabled);
  }

  Future<void> toggleBiometrics(bool value) async {
    _biometricsEnabled = value;
    // Allow switch animation to transition smoothly
    await Future.delayed(const Duration(milliseconds: 150));
    notifyListeners();
    await _prefs?.setBool(_bioKey, value);
  }

  Future<void> calculateCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      // Offload cache size calculation to a background isolate to keep UI smooth (60/90/120 FPS)
      _cacheSizeMB = await compute(_calculateDirSize, tempDir.path);
    } catch (e) {
      _cacheSizeMB = 0.0;
    }
    notifyListeners();
  }

  Future<void> clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      // Offload clearing task to a background isolate, deleting files synchronously
      await compute(_clearDirContents, tempDir.path);
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
    await calculateCacheSize();
  }
}

/// Helper top-level function to calculate directory size synchronously inside a background isolate.
double _calculateDirSize(String path) {
  try {
    final dir = Directory(path);
    if (!dir.existsSync()) return 0.0;
    int totalSize = 0;
    final List<FileSystemEntity> entities = dir.listSync(recursive: true, followLinks: false);
    for (final entity in entities) {
      if (entity is File) {
        try {
          totalSize += entity.lengthSync();
        } catch (_) {}
      }
    }
    return totalSize / (1024 * 1024);
  } catch (_) {
    return 0.0;
  }
}

/// Helper top-level function to clean a directory synchronously inside a background isolate.
void _clearDirContents(String path) {
  try {
    final dir = Directory(path);
    if (!dir.existsSync()) return;
    final List<FileSystemEntity> entities = dir.listSync(recursive: false, followLinks: false);
    for (final entity in entities) {
      try {
        if (entity is File) {
          entity.deleteSync();
        } else if (entity is Directory) {
          entity.deleteSync(recursive: true);
        }
      } catch (_) {}
    }
  } catch (_) {}
}
