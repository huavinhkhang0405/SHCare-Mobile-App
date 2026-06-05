import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../models/task_suggestion.dart';
import '../../models/nutrition_result.dart';

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
    required String screenTimeData,
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
- 📱 Hoạt động kỹ thuật số (Screen Time): $screenTimeData

[Quy tắc sinh nhiệm vụ]
1. Phân tích: Nếu "Lượng nước" dưới 50% mục tiêu, BẮT BUỘC có nhiệm vụ uống nước (type: "water").
2. Phân tích: Nếu "Nhịp tim" lớn hơn 90bpm, BẮT BUỘC có nhiệm vụ hít thở hoặc nghỉ ngơi (type: "relax").
3. DIGITAL DETOX: Đọc biến "Hoạt động kỹ thuật số (Screen Time)". Nếu người dùng sử dụng Mạng xã hội / Game (TikTok, Facebook, YouTube, Instagram...) VƯỢT QUÁ 5 phút (ngưỡng thử nghiệm theo yêu cầu của người dùng để test tính năng hoạt động), BẮT BUỘC sinh ra 1 nhiệm vụ rời xa màn hình (Ví dụ: "Nhắm mắt thư giãn 5 phút", "Đi dạo ngoài trời 15 phút" với type: "relax" hoặc "exercise").
4. Trọng số EXP: Nhiệm vụ dễ (20 EXP), Vừa (30 EXP), Khó (50 EXP).
5. Không giao nhiệm vụ vận động mạnh nếu Mức năng lượng đang dưới 40%.

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

  /// Phân tích khẩu phần ăn qua AI để ước lượng Calories, Protein, Carbs, Fat.
  Future<NutritionResult?> analyzeNutrition(String mealDescription) async {
    final prompt = '''
    Bạn là một chuyên gia dinh dưỡng. Người dùng vừa nhập bữa ăn của họ: "$mealDescription".
    Nhiệm vụ của bạn là ước tính tổng lượng dinh dưỡng (Calories, Protein, Carbs, Fat).
    
    [Quy tắc nghiêm ngặt]
    1. Nếu nội dung KHÔNG PHẢI là đồ ăn/thức uống (ví dụ: "tôi đi bộ", "xin chào", câu chửi thề), hãy đặt "is_valid_food" = false và cho các chỉ số bằng 0.
    2. Nếu là đồ ăn, ước lượng số liệu ở mức trung bình của Việt Nam (ví dụ: 1 tô phở bò ~ 450-500 kcal).
    3. Chỉ trả về JSON thuần túy, KHÔNG giải thích thêm.

    [Định dạng JSON yêu cầu]
    {
      "food_items": ["tên món 1", "tên món 2"],
      "total_calories": 500,
      "total_protein": 30,
      "total_carbs": 55,
      "total_fat": 15,
      "is_valid_food": true
    }
    ''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text;
      if (text == null || text.isEmpty) return null;

      // Parse JSON thành Map
      final Map<String, dynamic> jsonMap = json.decode(text);
      return NutritionResult.fromJson(jsonMap);
    } catch (e) {
      debugPrint('🚨 Lỗi AI phân tích thức ăn: $e');
      return null;
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
