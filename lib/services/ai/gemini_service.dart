import 'dart:convert';
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
/// - Cơ chế xoay tua API keys (GEMINI_API_KEYS) và tự động thử lại khi lỗi
/// - Fallback logic khi mất mạng hoặc tất cả API keys đều lỗi
class GeminiService {
  List<String> _apiKeys = [];
  int _currentKeyIndex = 0;
  bool _isConfigured = false;

  GeminiService() {
    _initializeKeys();
  }

  void _initializeKeys() {
    final rawKeys = dotenv.env['GEMINI_API_KEYS'] ?? dotenv.env['GEMINI_API_KEY'] ?? '';
    if (rawKeys.isNotEmpty) {
      _apiKeys = rawKeys.split(',').map((k) => k.trim()).where((k) => k.isNotEmpty).toList();
    }
    _isConfigured = _apiKeys.isNotEmpty;
    if (!_isConfigured) {
      debugPrint('🚨 [GeminiService] Chưa cấu hình API key trong file .env');
    } else {
      debugPrint('✅ [GeminiService] Đã nạp ${_apiKeys.length} API key để xoay tua.');
    }
  }

  /// Kiểm tra xem service đã được cấu hình API key chưa
  bool get isConfigured => _isConfigured;

  String get _currentKey => _apiKeys.isEmpty ? '' : _apiKeys[_currentKeyIndex];

  void _rotateKey() {
    if (_apiKeys.length > 1) {
      _currentKeyIndex = (_currentKeyIndex + 1) % _apiKeys.length;
      debugPrint('🔄 [GeminiService] Xoay tua sang API key index: $_currentKeyIndex');
    }
  }

  GenerativeModel _getModel({GenerationConfig? config}) {
    return GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _currentKey,
      generationConfig: config,
    );
  }

  Future<T> _executeWithRotation<T>(
    Future<T> Function(GenerativeModel model) requestBuilder, {
    GenerationConfig? config,
  }) async {
    if (!_isConfigured) {
      throw Exception('Chưa cấu hình API key trong file .env.');
    }

    int attempts = 0;
    final maxAttempts = _apiKeys.length;

    while (attempts < maxAttempts) {
      try {
        final model = _getModel(config: config);
        return await requestBuilder(model);
      } catch (e) {
        attempts++;
        final errStr = e.toString();
        final isQuotaOrUnavailable = errStr.contains('429') || 
                                     errStr.contains('503') || 
                                     errStr.contains('Quota exceeded') || 
                                     errStr.contains('ResourceExhausted') || 
                                     errStr.contains('Service Unavailable');
        
        if (isQuotaOrUnavailable) {
          debugPrint('⚠️ [GeminiService] Phát hiện lỗi giới hạn tần suất/dịch vụ (429/503) với key $_currentKeyIndex. Tự động xoay sang key tiếp theo.');
        } else {
          debugPrint('🚨 [GeminiService] Lỗi khi gọi API với key index $_currentKeyIndex (Lần thử $attempts/$maxAttempts): $e');
        }
        
        if (attempts < maxAttempts) {
          _rotateKey();
          if (isQuotaOrUnavailable) {
            await Future.delayed(const Duration(milliseconds: 200));
          }
        } else {
          rethrow;
        }
      }
    }
    throw Exception('Đã thử tất cả các API key nhưng đều thất bại.');
  }

  /// Làm sạch chuỗi JSON từ Gemini (bỏ markdown code blocks và trích xuất đúng mảng/đối tượng JSON)
  String _sanitizeJson(String rawText) {
    var clean = rawText.replaceAll(RegExp(r'```json|```JSON|```'), '').trim();
    final jsonStart = clean.indexOf(RegExp(r'[\[\{]'));
    final jsonEnd = clean.lastIndexOf(RegExp(r'[\]\}]'));
    if (jsonStart != -1 && jsonEnd != -1 && jsonEnd > jsonStart) {
      clean = clean.substring(jsonStart, jsonEnd + 1);
    }
    return clean;
  }

  /// Xác thực hình ảnh hoàn thành nhiệm vụ qua Gemini AI (Multimodal)
  Future<bool> verifyTaskWithImage({
    required Uint8List imageBytes,
    required String taskTitle,
    required String taskDescription,
  }) async {
    if (!_isConfigured) {
      // Nếu không có API Key, tự động trả về true để test offline không bị nghẽn
      return true;
    }

    final prompt = '''
Bạn là trợ lý ảo kiểm định nhiệm vụ trong ứng dụng sức khỏe SHCare. 
Hãy phân tích hình ảnh được cung cấp xem có khớp với bằng chứng hoàn thành nhiệm vụ này hay không:
- Tên nhiệm vụ: "$taskTitle"
- Mô tả nhiệm vụ: "$taskDescription"

[Quy tắc xác thực]
1. Kiểm tra xem hình ảnh có chứa bằng chứng thực hiện nhiệm vụ hay không (Ví dụ: Nhiệm vụ là "Ăn 1 loại trái cây" thì ảnh phải chứa trái cây, quả táo, quả chuối, quả cam... Nhiệm vụ là "Uống nước" thì ảnh phải chứa ly nước, bình nước, chai nước... Nhiệm vụ là "Đi bộ" hay "Vận động" thì có thể chứa giày thể thao, phòng gym, công viên, đường chạy...).
2. Nếu hình ảnh đúng là bằng chứng thực hiện nhiệm vụ, trả về true.
3. Nếu hình ảnh hoàn toàn không liên quan, hoặc là ảnh chụp màn hình trống, hoặc không chứa bất kỳ bằng chứng nào liên quan, trả về false.

TRẢ VỀ ĐÚNG ĐỊNH DẠNG JSON SAU (Không thêm bất kỳ văn bản nào ngoài JSON):
{
  "is_valid": true,
  "reason": "Giải thích ngắn gọn tại sao hợp lệ hoặc không hợp lệ"
}
''';

    try {
      final content = [
        Content.multi([
          DataPart('image/jpeg', imageBytes),
          TextPart(prompt),
        ])
      ];

      final text = await _executeWithRotation(
        (model) async {
          final response = await model.generateContent(content);
          return response.text;
        },
        config: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.2, // Giảm temperature để kết quả xác thực ổn định và chính xác
        ),
      );

      if (text == null || text.isEmpty) {
        return false;
      }

      final Map<String, dynamic> jsonResult = json.decode(_sanitizeJson(text));
      return jsonResult['is_valid'] as bool? ?? false;
    } catch (e) {
      debugPrint('🚨 [GeminiService] Lỗi xác thực ảnh nhiệm vụ: $e');
      return false;
    }
  }

  /// Phân tích hình ảnh món ăn hoặc đồ uống sử dụng mô hình đa phương thức (Multimodal).
  Future<NutritionAnalysisResult> analyzeNutritionImage(
    Uint8List imageBytes, {
    String? userDescription,
  }) async {
    if (!_isConfigured) {
      throw Exception('Chưa cấu hình API key. Vui lòng kiểm tra tệp .env.');
    }

    final prompt = '''
Bạn là một chuyên gia dinh dưỡng ảo trong ứng dụng SHCare. Hãy phân tích hình ảnh món ăn hoặc đồ uống được cung cấp (kèm theo mô tả bổ sung của người dùng nếu có dưới đây) để ước tính lượng calo, các chất dinh dưỡng đa lượng (Carbs, Protein, Fat) và lượng nước ước tính chứa trong phần thực phẩm đó.

[Mô tả bổ sung của người dùng (nếu có)]
${userDescription ?? "Không có mô tả thêm từ người dùng."}

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

      final text = await _executeWithRotation(
        (model) async {
          final response = await model.generateContent(content);
          return response.text;
        },
        config: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.7,
        ),
      );

      if (text == null || text.isEmpty) {
        throw Exception('AI không thể nhận diện được hình ảnh thực phẩm.');
      }

      // Parse JSON kết quả
      final Map<String, dynamic> jsonResult = json.decode(_sanitizeJson(text));
      return NutritionAnalysisResult.fromJson(jsonResult);
    } catch (e) {
      debugPrint('🚨 [GeminiService] Lỗi phân tích ảnh thực phẩm: $e');
      rethrow;
    }
  }

  String buildPersonalizedContext({
    required double bmi,
    required String primaryHealthGoal,
    required int yesterdaySteps,
    required double yesterdaySleepMinutes,
    required int streakCount,
  }) {
    final sleepHours = yesterdaySleepMinutes / 60.0;
    return '''
[Bối cảnh cá nhân hóa chuyên sâu từ Huấn luyện viên AI]
- Thể trạng BMI của người dùng: ${bmi.toStringAsFixed(1)} (phân loại y sinh: ${_getBmiCategory(bmi)}).
- Mục tiêu sức khỏe cốt lõi dài hạn: $primaryHealthGoal.
- Nhật ký hoạt động hôm qua: Người dùng đã đi bộ $yesterdaySteps bước chân, giấc ngủ đạt được ${sleepHours.toStringAsFixed(1)} giờ.
- Chuỗi ngày liên tục rèn luyện kỷ luật (Streak): $streakCount ngày.
''';
  }

  String _getBmiCategory(double bmi) {
    if (bmi < 18.5) return 'Thiếu cân';
    if (bmi < 23.0) return 'Bình thường';
    if (bmi < 25.0) return 'Tiền béo phì';
    if (bmi < 30.0) return 'Béo phì độ I';
    return 'Béo phì độ II';
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
    List<Map<String, dynamic>> taskHistory = const [],
    required String primaryHealthGoal,
    required int yesterdaySteps,
    required double yesterdaySleepMinutes,
    required int streakCount,
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

    final historyString = taskHistory.isEmpty 
        ? "Chưa có dữ liệu lịch sử." 
        : taskHistory.map((h) => "- ${h['task_name'] ?? h['title'] ?? ''}: ${h['is_completed'] == true ? 'Hoàn thành' : 'Bỏ qua'}").join('\n');

    final contextString = buildPersonalizedContext(
      bmi: bmiVal,
      primaryHealthGoal: primaryHealthGoal,
      yesterdaySteps: yesterdaySteps,
      yesterdaySleepMinutes: yesterdaySleepMinutes,
      streakCount: streakCount,
    );

    // ─── 1. Prompt Engineering ──────────────────────────────
    final prompt = '''
Bạn là lõi AI thông minh tối cao của ứng dụng SHCare, đóng vai trò là một Huấn luyện viên sức khỏe cá nhân (Context-Aware AI Coach) nhằm cá nhân hóa chính xác 3 nhiệm vụ sức khỏe hàng ngày cho người dùng dựa trên thể trạng và thói quen của họ.

$contextString

[Thông tin cơ bản người dùng]
- Chiều cao: ${heightCm?.toStringAsFixed(0) ?? '170'} cm
- Cân nặng: ${weightKg?.toStringAsFixed(1) ?? '70'} kg
- Giới tính: ${gender ?? 'Khác'}
- Tuổi: $age tuổi
- Tần suất tập thể dục: ${activityLevel ?? 'Vừa phải'}
- Mục tiêu giấc ngủ: đi ngủ lúc ${targetBedtime ?? '23:00'} và dậy lúc ${targetWakeTime ?? '07:00'}

[Chỉ số hôm nay]
- Bước chân hôm nay: $steps / $stepGoal
- Nhịp tim hiện tại: $bpm bpm
- Lượng nước uống hôm nay: $waterLiters / $waterGoal lít
- Mức năng lượng: ${(energyLevel * 100).toInt()}%
- 📱 Hoạt động kỹ thuật số (Screen Time): $screenTimeData

[LỊCH SỬ HOÀN THÀNH 3 NGÀY QUA CỦA NGƯỜI DÙNG]
$historyString

[QUY TẮC AN TOÀN Y SINH HỌC & RÀNG BUỘC (Safety Guardrails) - BẮT BUỘC TUÂN THỦ]
1. Theo sát mục tiêu cốt lõi: 
   - Nếu mục tiêu là "Giảm cân" (Weight Loss) hoặc "Duy trì sức khỏe", ưu tiên các nhiệm vụ vận động (exercise) và dinh dưỡng lành mạnh (nutrition).
   - Nếu mục tiêu là "Cải thiện giấc ngủ" (Sleep Improvement) hoặc "Duy trì năng lượng", ưu tiên các nhiệm vụ ngủ (sleep), nghỉ ngơi (rest), và giải tỏa căng thẳng.
2. Bù đắp giấc ngủ: Nếu giấc ngủ đêm qua của người dùng ít hơn 6 tiếng (yesterdaySleepMinutes < 360), bắt buộc phải sinh ra ít nhất 1 nhiệm vụ thuộc nhóm ngủ (sleep) hoặc nghỉ ngơi thư giãn (rest) giúp phục hồi năng lượng và ngủ sớm hơn tối nay.
3. An toàn thể trạng (BMI & Năng lượng):
   - Nếu BMI >= 23.0 (thừa cân/béo phì) hoặc mức năng lượng hiện tại dưới 40%, tuyệt đối CẤM đề xuất các bài tập vận động nặng (ví dụ: HIIT, chạy nhanh cường độ cao, cử tạ nặng). Thay vào đó, hãy đề xuất đi bộ nhẹ nhàng, tập thở sâu, thiền ngắn hoặc giãn cơ.
4. Chống ép chín ép non (Vận động tiệm tiến): Giới hạn cường độ bước chân trong các nhiệm vụ vận động. Mục tiêu bước đi mới không được tăng đột ngột quá 20% so với số bước thực tế họ đã đi được ngày hôm qua (yesterdaySteps). (Ví dụ: Nếu hôm qua họ chỉ đi 1000 bước, nhiệm vụ hôm nay không được vượt quá 1200 bước).

[QUY TẮC CÁ NHÂN HÓA ĐỘ KHÓ (DDA)]
- Phân tích lịch sử hoàn thành nhiệm vụ: Nếu người dùng liên tục bỏ qua nhiệm vụ khó, hãy hạ độ khó xuống. Nếu họ hoàn thành xuất sắc, hãy tăng tính thử thách dần.
- Luôn sinh chính xác 3 nhiệm vụ với phân cấp phần thưởng EXP nghiêm ngặt:
  + 1 Nhiệm vụ Dễ: Phần thưởng ĐÚNG 20 EXP.
  + 1 Nhiệm vụ Vừa: Phần thưởng ĐÚNG 30 EXP.
  + 1 Nhiệm vụ Khó: Phần thưởng ĐÚNG 50 EXP.
- 3 nhiệm vụ phải đa dạng, không trùng lặp loại (type): 'water', 'exercise', 'rest', 'sleep'.

[QUY TẮC PHÂN BỔ PHƯƠNG THỨC XÁC THỰC HÌNH ẢNH (requires_image)]
- Chỉ gán `requires_image` là true cho các hoạt động vật lý có thể chụp ảnh kiểm chứng trực quan rõ ràng tại thực địa: uống nước (chụp ly nước, chai nước), ăn đĩa hoa quả/rau xanh/trái cây, giãn cơ trên thảm tập yoga, thảm tập tại phòng gym, dụng cụ tạ, giày thể thao ngoài trời khi chạy bộ/đi bộ.
- BẮT BUỘC gán `requires_image` là false cho các hoạt động tinh thần, giấc ngủ, giãn cơ tại chỗ trong văn phòng hoặc hành động diễn ra trong không gian riêng tư nhạy cảm: nhắm mắt thư giãn, bài tập thở thở 4-7-8, đi ngủ đúng giờ, dọn dường ngủ, tắm rửa vệ sinh cá nhân, rời xa điện thoại (digital detox), xoay cổ tại chỗ.
- Luật Tie-breaker: Nếu một nhiệm vụ đan xen cả hành động vật lý lẫn tinh thần/thời gian (Ví dụ: "Uống 1 ly nước ấm và nhắm mắt thư giãn 5 phút"), bắt buộc gán `"requires_image": false` để giảm thiểu rào cản thao tác cho người dùng.

[QUY TẮC ĐẶT GIỜ VÀNG (Flash Quests)]
- Chọn duy nhất 1 trong 3 nhiệm vụ phù hợp để biến thành Nhiệm vụ giờ vàng. Gán cờ `"is_flash_quest": true`.
- Nhiệm vụ được chọn phải mang tính chất có thể thực hiện nhanh ngay lập tức (Ví dụ: uống ngay 1 ly nước, đứng dậy vươn vai 2 phút tại chỗ).
- Gán trường `"expires_in_minutes"` từ 30 đến 60 phút. Các nhiệm vụ còn lại đặt `"is_flash_quest": false` và `"expires_in_minutes": null`.

[ĐỊNH DẠNG ĐẦU RA BẮT BUỘC]
Trả về một mảng JSON thuần túy (luôn gồm đúng 3 phần tử), TUYỆT ĐỐI không bao bọc trong mã khối markdown (vd: không chứa thẻ ```json hay ```), không chứa khoảng trắng thừa hay ký tự lạ. Các trường boolean phải ở dạng kiểu dữ liệu nguyên bản, không bọc trong dấu ngoặc kép. Hãy luôn trả về các trường `target_steps` và `required_duration_minutes` dưới dạng số nguyên (integer) trong JSON phản hồi.

Mẫu cấu trúc JSON chính xác:
[
  {
    "task_name": "Ăn 1 quả táo xanh",
    "description": "Bổ sung vitamin và chất xơ cho hệ tiêu hóa vào buổi sáng.",
    "exp_reward": 20,
    "type": "nutrition",
    "requires_image": true,
    "is_flash_quest": false,
    "expires_in_minutes": null,
    "target_steps": 0,
    "required_duration_minutes": 0
  }
]
''';

    try {
      final text = await _executeWithRotation(
        (model) async {
          final response = await model.generateContent([Content.text(prompt)]);
          return response.text;
        },
        config: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.7,
        ),
      );

      if (text == null || text.isEmpty) {
        throw Exception('AI trả về dữ liệu rỗng');
      }

      debugPrint('✅ [GeminiService] Nhận response: ${text.substring(0, text.length.clamp(0, 200))}');

      // ─── 3. Parse JSON thành Object Dart ──────────────────
      final List<dynamic> jsonList = json.decode(_sanitizeJson(text));
      return jsonList.map((item) {
        final Map<String, dynamic> map = item as Map<String, dynamic>;
        final String generatedId = 'ai_${DateTime.now().millisecondsSinceEpoch}_${map.hashCode}';
        return TaskSuggestion.fromAiJson(map, generatedId);
      }).toList();
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
      final text = await _executeWithRotation(
        (model) async {
          final response = await model.generateContent([Content.text(prompt)]);
          return response.text;
        },
        config: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.7,
        ),
      );

      if (text == null || text.isEmpty) return null;

      // Parse JSON thành Map
      final Map<String, dynamic> jsonMap = json.decode(_sanitizeJson(text));
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
      final text = await _executeWithRotation(
        (model) async {
          final response = await model.generateContent([Content.text(prompt)]);
          return response.text;
        },
        config: GenerationConfig(
          temperature: 0.7,
        ),
      );
      return text?.trim() ?? 'Chúc bạn một ngày mới tràn đầy năng lượng!';
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
      final text = await _executeWithRotation(
        (model) async {
          final response = await model.generateContent([Content.text(prompt)]);
          return response.text;
        },
        config: GenerationConfig(
          temperature: 0.7,
        ),
      );
      return text?.trim() ?? 'Tuyệt vời! Mình sẽ canh giấc ngủ cho cậu thật tốt!';
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
        priority: 3,
        source: 'rule_based',
        targetSteps: 0,
        requiredDuration: Duration.zero,
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
        targetSteps: 0,
        requiredDuration: const Duration(minutes: 2),
      ),
      TaskSuggestion(
        id: 'fallback_fruit_${DateTime.now().millisecondsSinceEpoch}',
        userId: 'mock_user_001',
        title: 'Ăn 1 loại trái cây',
        description: 'Chụp ảnh 1 quả chuối, táo hoặc cam bạn ăn hôm nay.',
        category: 'Dinh dưỡng',
        expReward: 50,
        type: 'water',
        priority: 1,
        source: 'rule_based',
        targetSteps: 0,
        requiredDuration: Duration.zero,
      ),
    ];
  }
}
