import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../models/task_suggestion.dart';
import '../../models/nutrition_analysis_result.dart';
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
  /// Trả về [List<TaskSuggestion>] luôn đúng 3 nhiệm vụ.
  /// Nếu API lỗi → fallback về danh sách dự phòng.
  Future<List<TaskSuggestion>> generateHealthTasks({
    required int steps,
    required int stepGoal,
    required int bpm,
    required double waterLiters,
    required double waterGoal,
    required double energyLevel,
    required String screenTimeData,
    double? heightCm,
    double? weightKg,
    int? birthYear,
    String? gender,
    String? activityLevel,
    String? targetBedtime,
    String? targetWakeTime,
  }) async {
    // Nếu chưa có API key, trả fallback ngay
    if (!_isConfigured) {
      debugPrint('⚠️ [GeminiService] Không có API key, sử dụng fallback tasks');
      return _getFallbackTasks();
    }

    final age = birthYear != null ? DateTime.now().year - birthYear : 22;
    final bmiVal = (heightCm != null && heightCm > 0 && weightKg != null)
        ? weightKg / ((heightCm / 100) * (heightCm / 100))
        : 22.0;

    // ─── 1. Prompt Engineering ──────────────────────────────
    final prompt = '''
Bạn là một chuyên gia sức khỏe ảo trong ứng dụng SHCare. Dựa vào các chỉ số sức khỏe real-time và thông tin cá nhân/thói quen sau đây của người dùng, hãy tạo ra ĐÚNG 3 nhiệm vụ nhỏ (micro-tasks) để giúp họ cải thiện tình trạng hiện tại. Mỗi ngày người dùng chỉ được làm tối đa 3 nhiệm vụ này.

[Thông tin cá nhân & Thói quen]
- Chiều cao: ${heightCm?.toStringAsFixed(0) ?? '170'} cm
- Cân nặng: ${weightKg?.toStringAsFixed(1) ?? '70'} kg
- Chỉ số khối cơ thể (BMI): ${bmiVal.toStringAsFixed(1)}
- Giới tính: ${gender ?? 'Khác'}
- Tuổi: $age tuổi
- Tần suất tập thể dục: ${activityLevel ?? 'Vừa phải'}
- Mục tiêu giấc ngủ: đi ngủ lúc ${targetBedtime ?? '23:00'} và dậy lúc ${targetWakeTime ?? '07:00'}

[Chỉ số hiện tại]
- Bước chân: $steps / $stepGoal
- Nhịp tim: $bpm bpm
- Lượng nước đã uống: $waterLiters / $waterGoal lít
- Mức năng lượng: ${(energyLevel * 100).toInt()}%
- 📱 Hoạt động kỹ thuật số (Screen Time): $screenTimeData

[Quy tắc sinh nhiệm vụ]
1. BẮT BUỘC tạo ĐÚNG 3 nhiệm vụ, không hơn không kém.
2. Phân tích: Nếu "Lượng nước" dưới 50% mục tiêu, BẮT BUỘC có nhiệm vụ uống nước (type: "water").
3. Phân tích: Nếu "Nhịp tim" lớn hơn 90bpm, BẮT BUỘC có nhiệm vụ hít thở hoặc nghỉ ngơi (type: "relax").
4. DIGITAL DETOX: Đọc biến "Hoạt động kỹ thuật số (Screen Time)". Nếu người dùng sử dụng Mạng xã hội / Game (TikTok, Facebook, YouTube, Instagram...) VƯỢT QUÁ 5 phút (ngưỡng thử nghiệm theo yêu cầu của người dùng để test tính năng hoạt động), BẮT BUỘC sinh ra 1 nhiệm vụ rời xa màn hình (Ví dụ: "Nhắm mắt thư giãn 5 phút", "Đi dạo ngoài trời 15 phút" với type: "relax" hoặc "exercise").
5. Trọng số EXP: Nhiệm vụ dễ (20 EXP), Vừa (30 EXP), Khó (50 EXP).
6. Không giao nhiệm vụ vận động mạnh nếu Mức năng lượng đang dưới 40%.
7. 3 nhiệm vụ phải đa dạng, không trùng lặp loại (type).
8. CÁ NHÂN HÓA PHÙ HỢP THỂ TRẠNG:
   - Dựa vào Tần suất tập thể dục của người dùng để thiết kế độ khó của bài tập phù hợp:
     + Nếu Tần suất là "Không tập luyện": Giao nhiệm vụ siêu nhẹ nhàng (đi bộ 5-10 phút, đứng dậy giãn cơ 2 phút). KHÔNG giao chạy bộ hay tập nặng.
     + Nếu Tần suất là "Ít (1-2 ngày/tuần)": Giao nhiệm vụ nhẹ đến trung bình (đi bộ 10-15 phút, vươn vai).
     + Nếu Tần suất là "Vừa phải (3-5 ngày/tuần)": Giao các bài tập trung bình (như squat 15-20 cái, đi bộ nhanh 15 phút).
     + Nếu Tần suất là "Nhiều (6-7 ngày/tuần)": Có thể giao nhiệm vụ nâng cao (chạy bộ nhẹ 20 phút, bài tập HIIT ngắn).
   - Dựa vào BMI:
     + Nếu người dùng béo phì hoặc thừa cân (BMI >= 23): Tránh giao bài tập nhảy cao hoặc tác động mạnh đến khớp gối, ưu tiên đi bộ, giãn cơ hoặc tập thân trên.
   - Dựa vào mục tiêu giấc ngủ: Giao nhiệm vụ chuẩn bị ngủ (type: "relax") ví dụ như tắt thiết bị trước giờ đi ngủ mục tiêu 30 phút.

TRẢ VỀ ĐÚNG ĐỊNH DẠNG MẢNG JSON SAU (luôn 3 phần tử):
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

  /// Đánh giá giấc ngủ của người dùng và đưa ra lời khuyên chuẩn y khoa/nhịp sinh học.
  Future<String> getSleepInsight({
    required DateTime start,
    required DateTime wake,
    required double durationHours,
    required String targetBedtime,
    required String targetWakeTime,
  }) async {
    if (!_isConfigured) {
      return 'Bạn đã ngủ ${durationHours.toStringAsFixed(1)} tiếng. Hãy cố gắng duy trì thói quen ngủ điều độ nhé!';
    }

    final prompt = '''
Bạn là một trợ lý ảo/thú cưng đồng hành cùng người dùng trong ứng dụng SHCare. Người dùng vừa ghi nhận giấc ngủ đêm qua:
- Thực tế bắt đầu ngủ: ${start.hour}:${start.minute.toString().padLeft(2, '0')}
- Thực tế thức dậy: ${wake.hour}:${wake.minute.toString().padLeft(2, '0')}
- Tổng thời gian ngủ thực tế: ${durationHours.toStringAsFixed(1)} tiếng
- Giờ ngủ mục tiêu đã cài đặt: $targetBedtime
- Giờ thức dậy mục tiêu đã cài đặt: $targetWakeTime

Hãy đưa ra một đánh giá ngắn gọn (khoảng 2-3 câu, tối đa 60 từ), thân thiện nhưng chuẩn y khoa, đánh giá sự phù hợp của giấc ngủ này với nhịp sinh học (circadian rhythm) và giờ ngủ mục tiêu của họ. Đưa ra lời khuyên hữu ích để họ phục hồi cơ bắp và thần kinh tốt hơn.
Trả về nội dung văn bản trực tiếp không chứa JSON hay ký tự đặc biệt thừa.
''';

    try {
      final modelForText = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: dotenv.env['GEMINI_API_KEY'] ?? '',
        generationConfig: GenerationConfig(
          temperature: 0.7,
        ),
      );
      final response = await modelForText.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? 'Chúc bạn một ngày mới tràn đầy năng lượng!';
    } catch (e) {
      debugPrint('🚨 [GeminiService] Lỗi getSleepInsight: $e');
      return 'Bạn đã ngủ ${durationHours.toStringAsFixed(1)} tiếng. Hãy cố gắng duy trì nhịp ngủ đều đặn để phục hồi cơ thể nhé!';
    }
  }

  /// Đưa ra lời khuyên/insight của Pet AI cho việc cài đặt giờ ngủ ban đầu.
  Future<String> getBedtimeOnboardingInsight({
    required String targetBedtime,
    required String targetWakeTime,
  }) async {
    if (!_isConfigured) {
      return 'Tuyệt vời! Mình sẽ giúp bạn theo dõi giấc ngủ lúc $targetBedtime mỗi ngày nhé!';
    }

    final prompt = '''
Bạn là một thú cưng ảo đồng hành (Pet AI) cực kỳ thân thiện trong ứng dụng sức khỏe SHCare. Người dùng vừa thiết lập giờ ngủ mục tiêu là $targetBedtime và giờ thức dậy là $targetWakeTime.
Hãy đưa ra một phản hồi siêu dễ thương, khích lệ (tối đa 40 từ), nói rằng mục tiêu ngủ này rất tuyệt (ví dụ giúp ngủ đủ 8 tiếng, giữ nhịp sinh học tốt) và hứa sẽ canh chừng giấc ngủ cho họ thật tốt.
Trả về nội dung văn bản trực tiếp không chứa JSON hay ký tự đặc biệt thừa.
''';

    try {
      final modelForText = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: dotenv.env['GEMINI_API_KEY'] ?? '',
        generationConfig: GenerationConfig(
          temperature: 0.7,
        ),
      );
      final response = await modelForText.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? 'Tuyệt vời! Mình sẽ canh giấc ngủ cho cậu thật tốt!';
    } catch (e) {
      debugPrint('🚨 [GeminiService] Lỗi getBedtimeOnboardingInsight: $e');
      return 'Tuyệt vời! Mình sẽ giúp bạn theo dõi giấc ngủ lúc $targetBedtime mỗi ngày nhé!';
    }
  }

  /// Danh sách nhiệm vụ dự phòng khi AI không khả dụng (luôn 3 nhiệm vụ).
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
      TaskSuggestion(
        id: 'fallback_exercise_${DateTime.now().millisecondsSinceEpoch}',
        userId: 'mock_user_001',
        title: 'Đi bộ 500 bước',
        description: 'Đi bộ nhẹ nhàng xung quanh để kích hoạt cơ thể.',
        category: 'Vận động',
        expReward: 30,
        type: 'exercise',
        priority: 2,
        source: 'rule_based',
      ),
    ];
  }
}
