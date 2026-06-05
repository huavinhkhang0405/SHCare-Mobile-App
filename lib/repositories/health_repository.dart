import '../models/diary_entry.dart';
import '../models/pet_model.dart';
import '../models/task_suggestion.dart';
import '../models/user_model.dart';

/// Interface trung tâm cho mọi thao tác dữ liệu sức khỏe.
///
/// ĐÂY LÀ "HỢP ĐỒNG" giữa các thành viên:
/// - UI chỉ gọi hàm từ interface này, KHÔNG gọi trực tiếp Firebase/API.
/// - Khi chạy mock: dùng [MockHealthRepository].
/// - Khi chạy thật: dùng [FirebaseHealthRepository].
///
/// Cách chuyển đổi chỉ cần 1 dòng code trong main.dart hoặc Provider.
abstract class HealthRepository {
  // ─── USER ─────────────────────────────────────────────────
  /// Lấy thông tin user hiện tại
  Future<UserModel?> getCurrentUser();

  /// Cập nhật thông tin hồ sơ cá nhân
  Future<void> updateUserProfile(UserModel user);

  // ─── DIARY ────────────────────────────────────────────────
  /// Lấy nhật ký của 1 ngày cụ thể
  Future<DiaryEntry?> getDiaryEntry(String userId, DateTime date);

  /// Lấy lịch sử nhật ký nhiều ngày (sắp xếp theo ngày giảm dần)
  Future<List<DiaryEntry>> getDiaryHistory(String userId, {int days = 30});

  /// Lưu hoặc cập nhật nhật ký ngày hôm nay
  Future<void> saveDiaryEntry(DiaryEntry entry);

  // ─── PET ──────────────────────────────────────────────────
  /// Lấy trạng thái Pet hiện tại
  Future<PetModel?> getPet(String userId);

  /// Cập nhật trạng thái Pet (EXP, level, message, ...)
  Future<void> updatePet(PetModel pet);

  // ─── AI SUGGESTIONS ───────────────────────────────────────
  /// Lấy danh sách gợi ý hôm nay
  Future<List<TaskSuggestion>> getTodaySuggestions(String userId);

  /// Lưu danh sách gợi ý mới (do AI tạo)
  Future<void> saveSuggestions(List<TaskSuggestion> suggestions);

  /// Đánh dấu 1 gợi ý là đã hoàn thành
  Future<void> completeSuggestion(String suggestionId);
}
