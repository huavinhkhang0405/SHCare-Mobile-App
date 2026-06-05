import 'package:shared_preferences/shared_preferences.dart';

class NutritionAnalysisLimiter {
  static const int maxScansPerDay = 3;

  static String _getTodayKey() {
    final now = DateTime.now();
    return 'nutrition_scan_count_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Lấy số lần đã quét hôm nay
  static Future<int> getTodayScanCount() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getTodayKey();
    return prefs.getInt(key) ?? 0;
  }

  /// Kiểm tra xem còn lượt quét hay không
  static Future<bool> canScanToday() async {
    final count = await getTodayScanCount();
    return count < maxScansPerDay;
  }

  /// Tăng số lần quét hôm nay lên 1
  static Future<void> incrementScanCount() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getTodayKey();
    final currentCount = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, currentCount + 1);
  }
}
