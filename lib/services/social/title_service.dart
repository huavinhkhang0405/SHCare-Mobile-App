import '../../../models/diary_entry.dart';

class TitleService {
  TitleService._();

  /// Tính toán danh hiệu Gen Z từ nhật ký sức khỏe hàng ngày
  static String calculateTitle(DiaryEntry entry) {
    // 1. Kiểm tra các thói quen xấu/bottleneck nghiêm trọng trước để cảnh báo dí dỏm
    
    // Chúa tể ôm giường: Đi bộ quá ít
    if (entry.stepCount > 0 && entry.stepCount < 2000) {
      return 'Cột sống bất ổn';
    }

    // Sa mạc lời: Uống quá ít nước
    if (entry.waterIntakeLiters > 0 && entry.waterIntakeLiters < 1.0) {
      return 'Sa mạc lời';
    }

    // Cú đêm deadline: Ngủ quá ít (< 6 tiếng)
    if (entry.sleepMinutes > 0 && entry.sleepMinutes < 360) {
      return 'Cú đêm deadline';
    }

    // 2. Khen ngợi nếu đạt chỉ số tốt
    
    // Kẻ hủy diệt nước lọc: Uống nhiều nước
    if (entry.waterIntakeLiters >= 2.0) {
      return 'Kẻ hủy diệt nước lọc';
    }

    // Bậc thầy xê dịch: Đi bộ nhiều
    if (entry.stepCount >= 10000) {
      return 'Bậc thầy xê dịch';
    }

    // Sleeping Beauty: Ngủ ngon đủ giấc
    if (entry.sleepMinutes >= 480) {
      return 'Sleeping Beauty';
    }

    // 3. Fallback mặc định
    return 'Chiến thần KPI';
  }
}
