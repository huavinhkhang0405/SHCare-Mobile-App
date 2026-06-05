import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../models/task_suggestion.dart';

/// Bộ não AI của SHCare — Sử dụng Gemini API để sinh nhiệm vụ sức khỏe.
///
/// Kỹ thuật cốt lõi:
/// - responseMimeType: 'application/json' → ép AI chỉ trả JSON thuần
/// - Prompt Engineering với rule-based constraints
/// - Fallback logic khi mất mạng hoặc API lỗi
class GeminiService {
  late final GenerativeModel _model;
  final bool _isConfigured;

  GeminiService()
      : _isConfigured = (dotenv.env['GEMINI_API_KEY'] ?? '').isNotEmpty {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

    if (apiKey.isEmpty) {
      debugPrint('🚨 [GeminiService] Chưa cấu hình GEMINI_API_KEY trong file .env');
      debugPrint('👉 Thêm dòng GEMINI_API_KEY=your_key_here vào file .env');
    }

    // Khởi tạo mô hình AI
    _model = GenerativeModel(
      model: 'gemini-2.5-flash', // Bản Flash cho tốc độ tính bằng mili-giây
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json', // Ép buộc AI chỉ trả về JSON hợp lệ
        temperature: 0.7, // Độ sáng tạo vừa phải
      ),
    );
  }

  /// Kiểm tra xem service đã được cấu hình API key chưa
  bool get isConfigured => _isConfigured;

  /// Hàm chính để sinh nhiệm vụ sức khỏe dựa trên chỉ số real-time.
  ///
  /// Trả về [List<TaskSuggestion>] từ 1-3 nhiệm vụ.
  /// Nếu API lỗi → fallback về danh sách dự phòng.
  Future<List<TaskSuggestion>> generateHealthTasks({
    required int steps,
    required int stepGoal,
    required int bpm,
    required double waterLiters,
    required double waterGoal,
    required double energyLevel,
  }) async {
    // Nếu chưa có API key, trả fallback ngay
    if (!_isConfigured) {
      debugPrint('⚠️ [GeminiService] Không có API key, sử dụng fallback tasks');
      return _getFallbackTasks();
    }

    // ─── 1. Prompt Engineering ──────────────────────────────
    final prompt = '''
Bạn là một chuyên gia sức khỏe ảo trong ứng dụng SHCare. Dựa vào các chỉ số sức khỏe real-time sau đây của người dùng, hãy tạo ra từ 1 đến 3 nhiệm vụ nhỏ (micro-tasks) để giúp họ cải thiện tình trạng hiện tại.

[Chỉ số hiện tại]
- Bước chân: $steps / $stepGoal
- Nhịp tim: $bpm bpm
- Lượng nước đã uống: $waterLiters / $waterGoal lít
- Mức năng lượng: ${(energyLevel * 100).toInt()}%

[Quy tắc sinh nhiệm vụ]
1. Phân tích: Nếu "Lượng nước" dưới 50% mục tiêu, BẮT BUỘC có nhiệm vụ uống nước.
2. Phân tích: Nếu "Nhịp tim" lớn hơn 90bpm, BẮT BUỘC có nhiệm vụ hít thở hoặc nghỉ ngơi.
3. Trọng số EXP: Nhiệm vụ dễ (20 EXP), Vừa (30 EXP), Khó (50 EXP).
4. Không giao nhiệm vụ vận động mạnh nếu Mức năng lượng đang dưới 40%.

TRẢ VỀ ĐÚNG ĐỊNH DẠNG MẢNG JSON SAU:
[
  {
    "task_name": "Tên nhiệm vụ (tối đa 5 từ)",
    "description": "Cách thực hiện chi tiết (1 câu ngắn)",
    "exp_reward": 30,
    "type": "water"
  }
]
''';

    try {
      // ─── 2. Gửi request lên AI ────────────────────────────
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      final text = response.text;
      if (text == null || text.isEmpty) {
        throw Exception('AI trả về dữ liệu rỗng');
      }

      debugPrint('✅ [GeminiService] Nhận response: ${text.substring(0, text.length.clamp(0, 200))}');

      // ─── 3. Parse JSON thành Object Dart ──────────────────
      final List<dynamic> jsonList = json.decode(text);
      return jsonList
          .map((item) => TaskSuggestion.fromAiJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('🚨 [GeminiService] Lỗi khi gọi Gemini: $e');
      // ─── 4. Fallback Logic ────────────────────────────────
      return _getFallbackTasks();
    }
  }

  /// Danh sách nhiệm vụ dự phòng khi AI không khả dụng.
  List<TaskSuggestion> _getFallbackTasks() {
    return [
      TaskSuggestion(
        id: 'fallback_water_${DateTime.now().millisecondsSinceEpoch}',
        userId: 'mock_user_001',
        title: 'Uống 1 ly nước',
        description: 'Bổ sung 250ml nước lọc ngay bây giờ.',
        category: 'Dinh dưỡng',
        expReward: 20,
        type: 'water',
        priority: 1,
        source: 'rule_based',
      ),
      TaskSuggestion(
        id: 'fallback_rest_${DateTime.now().millisecondsSinceEpoch}',
        userId: 'mock_user_001',
        title: 'Đứng dậy vươn vai',
        description: 'Tạm rời mắt khỏi màn hình và giãn cơ trong 2 phút.',
        category: 'Tinh thần',
        expReward: 30,
        type: 'rest',
        priority: 2,
        source: 'rule_based',
      ),
    ];
  }
}
