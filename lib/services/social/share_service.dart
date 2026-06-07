import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';

import '../../models/pet_model.dart';
/// Service chuyên trách chia sẻ thành tích sức khỏe lên mạng xã hội.
///
/// Tách biệt logic share khỏi Provider và UI theo nguyên tắc Single Responsibility.
class ShareService {
  /// Mapping classType → tên hiển thị tiếng Việt.
  static const Map<int, String> _classNames = {
    1: 'Chiến Binh',
    2: 'Cung Thủ',
    3: 'Sát Thủ',
    4: 'Pháp Sư',
    5: 'Hiệp Sĩ',
    6: 'Thầy Tu',
    7: 'Thợ Săn',
    8: 'Long Kỵ Sĩ',
  };

  /// Tạo chuỗi thông điệp chia sẻ thành tích.
  static String buildShareText({
    required PetModel pet,
    required int steps,
    required int completedTasks,
  }) {
    final className = _classNames[pet.classType] ?? 'Chiến Binh';
    final streakText = pet.streakCount > 0
        ? ' với chuỗi ${pet.streakCount} ngày rèn luyện liên tục'
        : '';

    return '🏆 Tôi đang nuôi dưỡng $className đạt Cấp ${pet.level}'
        '$streakText trên SHCare!\n'
        '🚶 Hôm nay: $steps bước chân · $completedTasks/3 nhiệm vụ hoàn thành\n'
        '🪙 Tổng vàng: ${pet.goldCoins}\n\n'
        'Bạn có muốn thử sức? Tải SHCare ngay! 💪';
  }

  /// Chụp widget (qua RepaintBoundary) thành ảnh PNG.
  ///
  /// [repaintKey] phải được gắn vào một [RepaintBoundary] widget bọc quanh
  /// phần giao diện Pet cần chụp.
  /// Trả về [Uint8List] chứa dữ liệu PNG, hoặc `null` nếu thất bại.
  static Future<Uint8List?> captureWidgetAsImage(GlobalKey repaintKey) async {
    try {
      final boundary = repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('🚨 [ShareService] Không tìm thấy RenderRepaintBoundary.');
        return null;
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('🚨 [ShareService] Lỗi khi chụp widget: $e');
      return null;
    }
  }

  /// Orchestrator chính: chụp ảnh Pet → lưu tạm → gọi native share dialog.
  ///
  /// Trả về `true` nếu hộp thoại share được mở thành công (không đảm bảo người dùng đã share thật).
  static Future<bool> shareAchievement({
    required PetModel pet,
    required int steps,
    required int completedTasks,
    GlobalKey? repaintKey,
    Uint8List? preCapturedImageBytes,
  }) async {
    final text = buildShareText(
      pet: pet,
      steps: steps,
      completedTasks: completedTasks,
    );

    try {
      // Sử dụng ảnh có sẵn hoặc chụp widget thành ảnh
      final imageBytes = preCapturedImageBytes ?? 
          (repaintKey != null ? await captureWidgetAsImage(repaintKey) : null);

      if (imageBytes != null) {
        // Lưu vào thư mục tạm
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/shcare_achievement.png');
        await file.writeAsBytes(imageBytes);

        // Gọi native share với ảnh + text
        await Share.shareXFiles(
          [XFile(file.path)],
          text: text,
          subject: 'Thành tích SHCare',
        );
      } else {
        // Fallback: chia sẻ chỉ text nếu chụp ảnh thất bại
        await Share.share(
          text,
          subject: 'Thành tích SHCare',
        );
      }

      return true;
    } catch (e) {
      debugPrint('🚨 [ShareService] Lỗi khi chia sẻ thành tích: $e');
      return false;
    }
  }
}
