import 'package:app_usage/app_usage.dart';
import 'package:flutter/material.dart';

class ScreenTimeService {
  // Danh sách các package name của các app dễ gây nghiện (Tối ưu: Chỉ quét tụi này)
  final Map<String, String> _targetApps = {
    'com.facebook.katana': 'Facebook',
    'com.zhiliaoapp.musically': 'TikTok',
    'com.ss.android.ugc.trill': 'TikTok', // TikTok bản quốc tế
    'com.google.android.youtube': 'YouTube',
    'com.instagram.android': 'Instagram',
    'com.tencent.ig': 'PUBG Mobile',
    'com.garena.game.kgvn': 'Liên Quân Mobile',
  };

  Future<String> getSocialMediaUsageToday() async {
    try {
      DateTime endDate = DateTime.now();
      // Lấy từ 00:00 sáng hôm nay đến hiện tại
      DateTime startDate = DateTime(endDate.year, endDate.month, endDate.day); 

      // Gọi API Android (Package này sẽ tự động mở màn hình Cài đặt xin quyền nếu chưa có)
      List<AppUsageInfo> infoList = await AppUsage().getAppUsage(startDate, endDate);

      Map<String, int> socialUsageMinutes = {};
      int totalSocialMinutes = 0;

      for (var info in infoList) {
        // Chỉ bóc tách những app có trong danh sách theo dõi
        if (_targetApps.containsKey(info.packageName)) {
          int minutes = info.usage.inMinutes;
          if (minutes > 0) { // Lọc bỏ app mở chưa tới 1 phút
            String appName = _targetApps[info.packageName]!;
            socialUsageMinutes[appName] = (socialUsageMinutes[appName] ?? 0) + minutes;
            totalSocialMinutes += minutes;
          }
        }
      }

      if (totalSocialMinutes == 0) return "Sử dụng màn hình hợp lý, không lạm dụng MXH.";

      // Định dạng lại thành String ngắn gọn gửi cho AI (Tối ưu độ dài)
      // Ví dụ: "Tổng MXH: 150 phút (TikTok: 120p, Facebook: 30p)"
      String details = socialUsageMinutes.entries
          .map((e) => '${e.key}: ${e.value}p')
          .join(', ');

      return "Thời gian dùng MXH/Game hôm nay: $totalSocialMinutes phút ($details)";

    } catch (exception) {
      debugPrint("🚨 Lỗi Screen Time: $exception");
      if (exception.toString().contains("permission") || exception.toString().contains("PERMISSION")) {
        return "Chưa cấp quyền đo thời gian màn hình.";
      }
      return "Không thể đo thời gian màn hình.";
    }
  }

  Future<int> getTotalSocialMediaUsageMinutes() async {
    try {
      DateTime endDate = DateTime.now();
      DateTime startDate = DateTime(endDate.year, endDate.month, endDate.day); 

      List<AppUsageInfo> infoList = await AppUsage().getAppUsage(startDate, endDate);

      int totalSocialMinutes = 0;
      for (var info in infoList) {
        if (_targetApps.containsKey(info.packageName)) {
          int minutes = info.usage.inMinutes;
          if (minutes > 0) {
            totalSocialMinutes += minutes;
          }
        }
      }
      return totalSocialMinutes;
    } catch (exception) {
      debugPrint("🚨 Lỗi Screen Time: $exception");
      return 0;
    }
  }
}
