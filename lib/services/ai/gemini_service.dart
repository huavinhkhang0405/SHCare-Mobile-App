import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../models/task_suggestion.dart';
import '../../models/nutrition_analysis_result.dart';

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

  /// Phân tích hình ảnh món ăn hoặc đồ uống sử dụng mô hình đa phương thức (Multimodal).
  Future<NutritionAnalysisResult> analyzeNutritionImage(
    Uint8List imageBytes, {
    String? userDescription,
  }) async {
    if (!_isConfigured) {
      throw Exception('Chưa cấu hình GEMINI_API_KEY. Vui lòng kiểm tra tệp .env.');
    }

    final prompt = '''
Bạn là một chuyên gia dinh dưỡng ảo trong ứng dụng SHCare. Hãy phân tích hình ảnh món ăn hoặc đồ uống được cung cấp (kèm theo mô tả bổ sung của người dùng nếu có dưới đây) để ước tính lượng calo, các chất dinh dưỡng đa lượng (Carbs, Protein, Fat) và lượng nước ước tính chứa trong phần thực phẩm đó.

[Mô tả bổ sung của người dùng (nếu có)]
\${userDescription ?? "Không có mô tả thêm từ người dùng."}

[Quy tắc phân tích]
1. Hãy nhận diện chính xác nhất loại món ăn hoặc đồ uống trong ảnh. BẮT BUỘC ƯU TIÊN TUYỆT ĐỐI thông tin từ "Mô tả bổ sung của người dùng" để xác định thành phần, lượng đường, topping, nguyên liệu hoặc kích cỡ phần ăn, vì đây là thông tin chính xác nhất về thực phẩm họ đang ăn/uống mà mắt thường không nhìn thấy hết qua ảnh.
2. Xác định "type" là "food" (cho món ăn) hoặc "drink" (cho đồ uống).
3. Lượng calo (calories) tính bằng kcal.
4. Carbs, Protein, Fat tính bằng gam (g).
5. Lượng nước (water_liters) ước tính theo lít (ví dụ: ly nước mía khoảng 0.35 L, cốc trà đá 0.3 L, nước suối 0.5 L). Đối với món ăn dạng nước như phở/bún, ước tính lượng nước lèo khoảng 0.25 L. Các món khô trả về 0.0.
6. Cung cấp một đoạn đánh giá ngắn gọn (2-3 câu) về tính lành mạnh hoặc lời khuyên sức khỏe về thực phẩm đó trong trường "assessment".

TRẢ VỀ ĐÚNG ĐỊNH DẠNG JSON SAU (Không thêm bất kỳ văn bản nào ngoài JSON):
{
  "name": "Tên món ăn hoặc đồ uống (tiếng Việt, ví dụ: Phở bò chín)",
  "type": "food",
  "calories": 450,
  "carbs_g": 55.0,
  "protein_g": 22.5,
  "fat_g": 12.0,
  "water_liters": 0.25,
  "confidence_percentage": 85,
  "assessment": "Đánh giá dinh dưỡng của món ăn..."
}
''';

    try {
      final content = [
        Content.multi([
          DataPart('image/jpeg', imageBytes),
          TextPart(prompt),
        ])
      ];

      final response = await _model.generateContent(content);
      final text = response.text;
      if (text == null || text.isEmpty) {
        throw Exception('AI không thể nhận diện được hình ảnh thực phẩm.');
      }

      // Parse JSON kết quả
      final Map<String, dynamic> jsonResult = json.decode(text);
      return NutritionAnalysisResult.fromJson(jsonResult);
    } catch (e) {
      debugPrint('🚨 [GeminiService] Lỗi phân tích ảnh thực phẩm: \$e');
      rethrow;
    }
  }

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
