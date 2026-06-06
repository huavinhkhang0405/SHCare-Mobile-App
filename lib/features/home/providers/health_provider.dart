import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:screen_state/screen_state.dart';
import 'package:app_usage/app_usage.dart';

import '../../../models/task_suggestion.dart';
import '../../../services/ai/gemini_service.dart';
import '../../../services/pet/pet_service.dart';
import '../../../models/nutrition_analysis_result.dart';
import '../../../services/sensor/health_sensor_service.dart';
import '../../../services/screen_time_service.dart';
import '../../../models/user_model.dart';
import '../../../models/home_plan_item.dart';
import '../../../models/recent_activity.dart';
import '../../../utils/date_formatter.dart';
import '../../../models/diary_entry.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/social/title_service.dart';
import '../../../services/social/social_service.dart';

class HealthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  String _currentUserId = '';
  int _lastDeviceSteps = -1;
  bool _isScreenTimeExceeded = false;

  // Dữ liệu Lịch trình chăm sóc và Hoạt động gần đây
  List<HomePlanItem> _planItems = [];
  List<RecentActivity> _recentActivities = [];

  List<HomePlanItem> get planItems => List.unmodifiable(_planItems);
  List<RecentActivity> get recentActivities => List.unmodifiable(_recentActivities);

  static final List<HomePlanItem> _defaultPlanItems = [
    HomePlanItem(
      id: 'plan_water_morning',
      time: '08:00',
      title: 'Uống nước đầu ngày',
      subtitle: 'Nhắc nhở',
      gifAssetPath: 'assets/icons/gif/check.gif',
      iconName: 'check_circle_rounded',
      iconColorHex: 'FF2ECC71',
      isCompleted: false,
    ),
    HomePlanItem(
      id: 'plan_walk_afternoon',
      time: '12:30',
      title: 'Đi bộ 15 phút',
      subtitle: 'Sắp đến giờ',
      gifAssetPath: 'assets/icons/gif/walk.gif',
      iconName: 'directions_walk_rounded',
      iconColorHex: 'FFE67E22',
      isCompleted: false,
    ),
    HomePlanItem(
      id: 'plan_breath_evening',
      time: '22:00',
      title: 'Tập thở sâu 5 phút',
      subtitle: 'Nhắc nhở',
      gifAssetPath: 'assets/icons/gif/meditate.gif',
      iconName: 'self_improvement_rounded',
      iconColorHex: 'FF9B59B6',
      isCompleted: false,
    ),
  ];

  Future<void> _savePlanItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = json.encode(_planItems.map((p) => p.toJson()).toList());
      await prefs.setString(_getKey('plan_items_json'), encoded);
    } catch (e) {
      debugPrint('🚨 [HealthProvider] Lỗi khi lưu plan items: $e');
    }
  }

  Future<void> _saveRecentActivities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = json.encode(_recentActivities.map((a) => a.toJson()).toList());
      await prefs.setString(_getKey('recent_activities_json'), encoded);
    } catch (e) {
      debugPrint('🚨 [HealthProvider] Lỗi khi lưu recent activities: $e');
    }
  }

  void addRecentActivity({
    required String title,
    required String subtitle,
    required String trailing,
    required String gifAssetPath,
    required String iconName,
  }) {
    final activity = RecentActivity(
      id: 'activity_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(1000)}',
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      gifAssetPath: gifAssetPath,
      iconName: iconName,
      timestamp: DateTime.now(),
    );
    _recentActivities.insert(0, activity);
    if (_recentActivities.length > 10) {
      _recentActivities = _recentActivities.sublist(0, 10);
    }
    _saveRecentActivities();
    notifyListeners();
  }

  void togglePlanItem(String planId) {
    final index = _planItems.indexWhere((p) => p.id == planId);
    if (index == -1) return;

    final item = _planItems[index];
    final newCompletedState = !item.isCompleted;
    final newSubtitle = newCompletedState ? 'Hoàn thành' : 'Nhắc nhở';

    _planItems[index] = item.copyWith(
      isCompleted: newCompletedState,
      subtitle: newSubtitle,
    );

    _savePlanItems();

    if (newCompletedState) {
      _currentExp += 10;
      var didLevelUp = false;
      if (_currentExp >= _expToNextLevel) {
        _level++;
        _currentExp -= _expToNextLevel;
        didLevelUp = true;
      }
      _petTask = 'Hoàn thành "${item.title}"! +10 EXP';
      _triggerPetEnvironmentEffect(didLevelUp: didLevelUp);
      _petService.gainExperience(_currentUserId, 10);

      addRecentActivity(
        title: 'Hoàn thành lịch trình',
        subtitle: 'Đã thực hiện: ${item.title}',
        trailing: item.time,
        gifAssetPath: item.gifAssetPath,
        iconName: item.iconName,
      );
    } else {
      addRecentActivity(
        title: 'Hủy hoàn thành',
        subtitle: 'Đã hủy: ${item.title}',
        trailing: item.time,
        gifAssetPath: item.gifAssetPath,
        iconName: item.iconName,
      );
    }
    notifyListeners();
  }

  bool get isScreenTimeExceeded => _isScreenTimeExceeded;

  // --- THÊM CÁC BIẾN CHO GIẤC NGỦ CHỐNG GIAN LẬN ---
  int _sleepMinutes = 465; // Mặc định 7h 45m
  StreamSubscription<ScreenStateEvent>? _screenSubscription;
  bool _shouldShowSleepConfirmation = false;
  DateTime? _sleepStartToConfirm;
  DateTime? _sleepWakeToConfirm;

  // Onboarding Giấc ngủ Tiệm tiến (Progressive Bedtime Onboarding)
  bool _hasOnboardedBedtime = false;
  String? _onboardingBedtimeInsight;

  bool get hasOnboardedBedtime => _hasOnboardedBedtime;
  String? get onboardingBedtimeInsight => _onboardingBedtimeInsight;

  Future<void> setHasOnboardedBedtime(bool value) async {
    _hasOnboardedBedtime = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_getKey('has_onboarded_bedtime'), value);
    } catch (e) {
      debugPrint('🚨 [HealthProvider] Lỗi khi lưu has_onboarded_bedtime: $e');
    }
    notifyListeners();
  }

  Future<void> fetchBedtimeOnboardingInsight(String bedtime, String wakeTime) async {
    try {
      final insight = await _geminiService.getBedtimeOnboardingInsight(
        targetBedtime: bedtime,
        targetWakeTime: wakeTime,
      );
      _onboardingBedtimeInsight = insight;
      _refreshPetInsights();
      notifyListeners();
    } catch (e) {
      debugPrint('🚨 [HealthProvider] Lỗi fetchBedtimeOnboardingInsight: $e');
    }
  }

  void completeDailyTaskOnboardingBedtime() {
    _currentExp += 50;
    var didLevelUp = false;
    if (_currentExp >= _expToNextLevel) {
      _level++;
      _currentExp -= _expToNextLevel;
      didLevelUp = true;
    }
    _petTask = 'Đã hoàn thành thiết lập mục tiêu giấc ngủ! +50 EXP';
    _triggerPetEnvironmentEffect(didLevelUp: didLevelUp);
    _petService.gainExperience(_currentUserId, 50);
    _refreshPetInsights();
    notifyListeners();
  }

  int get sleepMinutes => _sleepMinutes;
  bool get shouldShowSleepConfirmation => _shouldShowSleepConfirmation;
  DateTime? get sleepStartToConfirm => _sleepStartToConfirm;
  DateTime? get sleepWakeToConfirm => _sleepWakeToConfirm;

  String get sleepDurationLabel => '${_sleepMinutes ~/ 60}h ${_sleepMinutes % 60}m';

  String get sleepQuality {
    if (_sleepMinutes >= 480) return 'Rất tốt';
    if (_sleepMinutes >= 420) return 'Tốt';
    if (_sleepMinutes >= 360) return 'Tạm ổn';
    return 'Kém';
  }

  // Cấu hình môi trường và ngưỡng cảnh báo
  static const bool isDebugMode = true;
  static const int debugScreenTimeLimit = 5;
  static const int prodScreenTimeLimit = 120;

  bool _hasShownScreenTimeAlert = false;
  String _screenTimeDetails = '';

  bool get hasShownScreenTimeAlert => _hasShownScreenTimeAlert;
  String get screenTimeDetails => _screenTimeDetails;

  String _getKey(String key) {
    return '${_currentUserId}_$key';
  }

  void updateUser(UserModel? user) async {
    final cleanId = user?.id ?? '';
    _currentUser = user;

    // Tự sinh Friend Code nếu trống hoặc không hợp lệ (self-healing cho cả tài khoản cũ/mới)
    if (user != null && (user.friendCode.isEmpty || !RegExp(r'^[A-Z0-9]+$').hasMatch(user.friendCode))) {
      try {
        final code = await SocialService().generateUniqueFriendCode(user.name);
        await FirebaseFirestore.instance.collection('users').doc(user.id).update({
          'friend_code': code,
        });
        _currentUser = user.copyWith(friendCode: code);
        debugPrint('🔮 [HealthProvider] Đã tự sinh Friend Code cho ${user.name}: $code');
        notifyListeners();
      } catch (e) {
        debugPrint('🚨 [HealthProvider] Lỗi sinh Friend Code: $e');
      }
    }

    if (_currentUserId != cleanId) {
      _currentUserId = cleanId;
      _lastDeviceSteps = -1; // Reset device steps baseline for the new profile
      _isScreenTimeExceeded = false;
      _hasShownScreenTimeAlert = false;
      _screenTimeDetails = '';
      
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_user_email', cleanId);
      } catch (e) {
        debugPrint('🚨 [HealthProvider] Lỗi khi lưu current_user_email: $e');
      }

      // Thiết lập lắng nghe Poke chọc ghẹo realtime cho user mới
      _pokeSubscription?.cancel();
      if (_currentUserId.isNotEmpty) {
        _pokeSubscription = SocialService().streamPokes(_currentUserId).listen((snapshot) async {
          if (snapshot.docs.isNotEmpty) {
            final newestDoc = snapshot.docs.first;
            final data = newestDoc.data() as Map<String, dynamic>?;
            if (data != null) {
              final senderName = data['sender_name'] as String? ?? 'Bạn bè';
              final pokeType = data['poke_type'] as String? ?? 'lazy';
              final docId = newestDoc.id;

              String message = '';
              if (pokeType == 'lazy') {
                message = 'Chiến thần đi bộ $senderName chọc quê bạn vì làm [Cột sống bất ổn]!';
              } else if (pokeType == 'water') {
                message = 'Đại sứ đại dương $senderName nhắc nhở cây héo như bạn uống nước [Sa mạc lời]!';
              } else if (pokeType == 'sleep') {
                message = 'Chiến thần ngủ ngon $senderName giục cú đêm như bạn [Cú đêm deadline] đi ngủ!';
              } else {
                message = '$senderName vừa chọc bạn một cái!';
              }

              _latestPokeMessage = message;
              notifyListeners();

              // Garbage Collection: Xóa tài liệu ngay sau khi nhận để tránh phình to DB
              await SocialService().deletePoke(_currentUserId, docId);
            }
          }
        });
      }

      _loadStateFromPrefs();
      checkScreenTimeLimit();
    } else {
      // Cập nhật lại các chỉ số nếu người dùng thay đổi chiều cao/cân nặng
      _updateHealthScore();
      _refreshPetInsights();
      notifyListeners();
    }
  }

  // Getters cho các công thức y khoa cá nhân hóa
  double get bmi {
    final w = _currentUser?.weightKg ?? 70.0;
    final h = _currentUser?.heightCm ?? 170.0;
    if (h <= 0) return 0.0;
    return w / ((h / 100.0) * (h / 100.0));
  }

  String get bmiCategory {
    final val = bmi;
    if (val <= 0) return 'Chưa rõ';
    if (val < 18.5) return 'Thiếu cân (Underweight)';
    if (val < 23.0) return 'Bình thường (Normal)';
    if (val < 25.0) return 'Tiền béo phì (Overweight)';
    if (val < 30.0) return 'Béo phì độ I (Obese I)';
    return 'Béo phì độ II (Obese II)';
  }

  Color get bmiColor {
    final val = bmi;
    if (val <= 0) return Colors.grey;
    if (val < 18.5) return const Color(0xFFF1C40F); // Vàng
    if (val < 23.0) return const Color(0xFF2ECC71); // Xanh
    if (val < 25.0) return const Color(0xFFE67E22); // Cam
    if (val < 30.0) return const Color(0xFFE74C3C); // Đỏ
    return const Color(0xFF9B59B6); // Tím
  }

  double get bmr {
    final w = _currentUser?.weightKg ?? 70.0;
    final h = _currentUser?.heightCm ?? 170.0;
    final birthYear = _currentUser?.birthYear ?? (DateTime.now().year - 22);
    final age = DateTime.now().year - birthYear;
    final isFemale = _currentUser?.gender == 'Nữ' || _currentUser?.gender == 'Female';

    if (isFemale) {
      return 10.0 * w + 6.25 * h - 5.0 * age - 161.0;
    } else {
      return 10.0 * w + 6.25 * h - 5.0 * age + 5.0;
    }
  }

  double get tdee {
    double multiplier = 1.2;
    final level = _currentUser?.activityLevel ?? 'Vừa phải';
    if (level.contains('Không')) {
      multiplier = 1.2;
    } else if (level.contains('Ít')) {
      multiplier = 1.375;
    } else if (level.contains('Vừa') || level == 'Vừa phải') {
      multiplier = 1.55;
    } else if (level.contains('Nhiều')) {
      multiplier = 1.725;
    } else {
      multiplier = 1.55; // fallback
    }
    return bmr * multiplier;
  }

  int get targetCalories {
    final valBmr = bmr;
    final valTdee = tdee;
    final valBmi = bmi;

    if (valBmi <= 0) return 2000;

    if (valBmi < 18.5) {
      return (valTdee + 300).round(); // Tăng cân: Tăng 300 calo
    } else if (valBmi >= 23.0) {
      return (valTdee - 500).clamp(valBmr, valTdee).round(); // Giảm cân: Giảm 500 calo (nhưng không dưới BMR)
    } else {
      return valTdee.round(); // Bình thường: Giữ cân
    }
  }

  // Dữ liệu cốt lõi cho Home
  int _steps = 0;
  final int _goal = 10000;
  int _bpm = 72;
  double _waterLiters = 0.0;
  int _waterPercentage = 0;
  final double _waterGoal = 2.0;

  // Dữ liệu mở rộng cho Stats/Tips/Journal
  int _hrv = 52;
  int _restingBpm = 58;
  int _caloriesBurned = 486;
  int _deepSleepMinutes = 198;
  int _healthScore = 88;

  int get caloriesConsumed => _consumedCalories;

  int _hrvDelta = 8;
  int _calorieDelta = 11;
  int _deepSleepDeltaMinutes = 24;

  double _energyLevel = 0.68;
  int _moodIndex = 1;

  // --- THÊM CÁC BIẾN QUẢN LÝ DINH DƯỠNG ---
  int _consumedCalories = 0;
  int _consumedProtein = 0;
  int _consumedCarbs = 0;
  int _consumedFat = 0;
  List<String> _todayFoods = [];
  String _todayNote = '';

  int get consumedCalories => _consumedCalories;
  int get consumedProtein => _consumedProtein;
  int get consumedCarbs => _consumedCarbs;
  int get consumedFat => _consumedFat;
  List<String> get todayFoods => _todayFoods;
  String get todayNote => _todayNote;

  StreamSubscription<QuerySnapshot>? _pokeSubscription;
  String? _latestPokeMessage;
  String? get latestPokeMessage => _latestPokeMessage;

  void clearLatestPokeMessage() {
    _latestPokeMessage = null;
    notifyListeners();
  }

  void setTodayNote(String value) {
    _todayNote = value;
    _saveTodayNote();
    notifyListeners();
  }

  Future<void> _saveTodayNote() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_getKey('today_note'), _todayNote);
    } catch (e) {
      debugPrint('🚨 [HealthProvider] Lỗi khi lưu today_note: $e');
    }
  }

  // Dữ liệu hiển thị Pet AI trên Home
  String _petState = 'Năng động';
  String _petMessage =
      'Bạn đang duy trì nhịp sinh hoạt rất tốt. Mình luôn đồng hành cùng bạn.';
  String _petTask = 'Đi bộ thêm 500 bước trong 30 phút tới.';
  bool _isLoadingAI = false;

  // ─── AI Tasks (Gemini) ─────────────────────────────────────
  final GeminiService _geminiService = GeminiService();
  final PetService _petService = PetService();
  final HealthSensorService _sensorService = HealthSensorService();
  List<TaskSuggestion> _aiTasks = [];
  bool _isLoadingAiTasks = false;
  String? _aiTasksError;
  DateTime? _lastAiFetchTime;

  final Set<String> _selectedSymptoms = {'Mỏi cổ vai', 'Mất tập trung'};
  final List<double> _weeklyActivity = <double>[
    0.48,
    0.62,
    0.55,
    0.81,
    0.74,
    0.92,
    0.67,
  ];

  // Level & EXP
  int _level = 1;
  int _currentExp = 0;
  final int _expToNextLevel = 100; // Cứ 100 điểm thì lên 1 cấp
  bool _showLevelUpEffect = false;
  bool _showTaskCompletedEffect = false;
  bool _isDailyTaskCompleted = false;
  Timer? _effectResetTimer;

  int get level => _level;
  int get currentExp => _currentExp;
  double get expProgress => _currentExp / _expToNextLevel;
  bool get showLevelUpEffect => _showLevelUpEffect;
  bool get showTaskCompletedEffect => _showTaskCompletedEffect;

  // Getters cho AI Tasks
  List<TaskSuggestion> get aiTasks => List.unmodifiable(_aiTasks);
  bool get isLoadingAiTasks => _isLoadingAiTasks;
  String? get aiTasksError => _aiTasksError;
  bool get hasAiTasks => _aiTasks.isNotEmpty;
  bool get isGeminiConfigured => _geminiService.isConfigured;

  final Random _random = Random();
  Timer? _timer;
  int _ticks = 0;

  HealthProvider() {
    _refreshPetInsights();
    _startSimulation();
    // GỌI HÀM CẢM BIẾN THẬT
    _initRealSensors();
    _initSleepTracking();
    // Tải trạng thái đã lưu từ SharedPreferences
    _loadStateFromPrefs();
    checkScreenTimeLimit();
  }

  // Getters cơ bản
  int get steps => _steps;
  int get goal => _goal;
  int get bpm => _bpm;
  double get waterLiters => _waterLiters;
  int get waterPercentage => _waterPercentage;
  double get waterGoal => _waterGoal;

  // Getters cho Pet AI
  String get petState => _petState;
  String get petMessage => _petMessage;
  
  /// Kiểm tra xem tất cả nhiệm vụ AI trong ngày đã hoàn thành chưa
  bool get allTasksCompleted {
    if (_aiTasks.isEmpty) return false;
    // Tất cả 3 nhiệm vụ đều phải isCompleted
    return _aiTasks.every((t) => t.isCompleted);
  }

  /// Số nhiệm vụ đã hoàn thành trong ngày
  int get completedTaskCount => _aiTasks.where((t) => t.isCompleted).length;

  /// Số nhiệm vụ còn lại chưa hoàn thành
  int get remainingTaskCount => _aiTasks.where((t) => !t.isCompleted).length;

  String get petTask {
    if (allTasksCompleted) {
      return 'Đã hoàn thành tất cả nhiệm vụ hôm nay! 🎉';
    }
    final activeTasks = _aiTasks.where((t) => !t.isCompleted).toList();
    if (activeTasks.isNotEmpty) {
      return activeTasks.first.title;
    }
    return _petTask;
  }
  bool get isLoadingAI => _isLoadingAI;

  // Getters cho Stats
  int get hrv => _hrv;
  int get restingBpm => _restingBpm;
  int get caloriesBurned => _caloriesBurned;
  int get deepSleepMinutes => _deepSleepMinutes;
  int get healthScore => _healthScore;
  int get hrvDelta => _hrvDelta;
  int get calorieDelta => _calorieDelta;
  int get deepSleepDeltaMinutes => _deepSleepDeltaMinutes;
  String get restingTrendLabel => _restingBpm <= 60 ? 'Ổn định' : 'Cần nghỉ';
  String get deepSleepLabel =>
      '${_deepSleepMinutes ~/ 60}h ${_deepSleepMinutes % 60}m';
  String get healthScoreMessage {
    if (_healthScore >= 90) {
      return 'Thể trạng hôm nay rất ấn tượng. Hãy giữ nhịp này!';
    }
    if (_healthScore >= 80) {
      return 'Sự hồi phục của bạn hôm nay đang đi đúng hướng.';
    }
    if (_healthScore >= 70) {
      return 'Cơ thể đang cần thêm nghỉ ngơi và bù nước.';
    }
    return 'Bạn nên giảm cường độ và ưu tiên phục hồi.';
  }

  List<double> get weeklyActivity => List<double>.unmodifiable(_weeklyActivity);

  double get weeklyAverageActivity {
    final total = _weeklyActivity.fold<double>(0, (totalSum, item) => totalSum + item);
    return total / _weeklyActivity.length;
  }

  // Getters cho Tips/Journal
  double get energyLevel => _energyLevel;
  int get moodIndex => _moodIndex;
  Set<String> get selectedSymptoms =>
      Set<String>.unmodifiable(_selectedSymptoms);
  int get waterGlasses => (_waterLiters / 0.25).round();
  int get remainingWaterGlasses =>
      max(0, ((_waterGoal - _waterLiters) / 0.25).ceil());

  void _startSimulation() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _ticks += 1;

      _simulateHeartRate();
      // final stepDelta = _simulateSteps(); // Tắt simulation bước chân
      const stepDelta = 0;
      _simulateWater();
      _simulateRecoveryMetrics(stepDelta);
      _simulateEnergyAndMood();
      _simulateWeeklyActivity();
      _updateHealthScore();
      _refreshPetInsights();

      // Kiểm tra reset ngày mới
      _checkDayChange();

      // Kiểm tra screen time định kỳ mỗi 30 giây (10 ticks)
      if (_ticks % 10 == 0) {
        checkScreenTimeLimit();
      }

      notifyListeners();
    });
  }

  void markScreenTimeAlertAsShown() {
    _hasShownScreenTimeAlert = true;
    _saveDailyAlertStatus(true);
    notifyListeners();
  }

  void dismissScreenTimeAlert() {
    _hasShownScreenTimeAlert = true;
    _saveDailyAlertStatus(true);
    notifyListeners();
  }

  Future<void> _saveDailyAlertStatus(bool completed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_getKey('has_shown_screentime_alert'), completed);
    } catch (e) {
      debugPrint('🚨 [HealthProvider] Lỗi khi lưu trạng thái cảnh báo screen time: $e');
    }
  }

  Future<void> checkScreenTimeLimit() async {
    try {
      final service = ScreenTimeService();
      final minutes = await service.getTotalSocialMediaUsageMinutes();
      final limit = isDebugMode ? debugScreenTimeLimit : prodScreenTimeLimit;
      final isExceeded = minutes >= limit;

      final usageDetails = await service.getSocialMediaUsageToday();
      _screenTimeDetails = usageDetails;

      // Đồng bộ cờ _hasShownScreenTimeAlert từ background task (WorkManager)
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final isShownBg = prefs.getBool(_getKey('has_shown_screentime_alert')) ?? false;
      if (isShownBg != _hasShownScreenTimeAlert) {
        _hasShownScreenTimeAlert = isShownBg;
      }

      if (_isScreenTimeExceeded != isExceeded) {
        _isScreenTimeExceeded = isExceeded;
        _refreshPetInsights();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('🚨 [HealthProvider] Lỗi check screen time limit: $e');
    }
  }

  void _refreshPetInsights() {
    _isLoadingAI = false;

    if (_onboardingBedtimeInsight != null) {
      _petState = 'Vui vẻ';
      _petMessage = _onboardingBedtimeInsight!;
      _petTask = 'Đã hoàn thành thiết lập mục tiêu giấc ngủ! 🎉';
      return;
    }

    if (_isScreenTimeExceeded) {
      _petState = 'Mệt mỏi';
      _petMessage =
          'Bạn đã dùng mạng xã hội / game quá 5 phút hôm nay rồi đó. Đứng dậy đi lại và thư giãn mắt đi nào!';
      if (!_isDailyTaskCompleted) {
        _petTask = 'Rời màn hình: Nhắm mắt thư giãn 5 phút.';
      }
      return;
    }

    // Thêm kiểm tra Calo tiêu thụ so với Calo mục tiêu
    final calTarget = targetCalories;
    if (_consumedCalories > calTarget + 200) {
      _petState = 'Mệt mỏi';
      _petMessage = 'Calo nạp vào đã vượt mức mục tiêu rồi ($consumedCalories / $calTarget kcal). Bạn nên hạn chế ăn vặt và vận động nhẹ nhàng nhé!';
      if (!_isDailyTaskCompleted) {
        _petTask = 'Đi bộ nhẹ nhàng 10 phút để tiêu hao năng lượng.';
      }
      return;
    }

    final isHydrationLow = _waterPercentage < 65;
    final isFatigued = _energyLevel < 0.45 || _bpm > 84;

    if (isHydrationLow) {
      _petState = 'Khát';
      _petMessage =
          'Mình thấy cơ thể bạn đang hơi thiếu nước. Bổ sung nước ngay sẽ giúp tỉnh táo hơn.';
      if (!_isDailyTaskCompleted) {
        _petTask = 'Uống 1 ly nước 250ml trong 15 phút tới.';
      }
      return;
    }

    if (isFatigued) {
      _petState = 'Mệt mỏi';
      _petMessage =
          'Nhịp cơ thể đang hơi căng, nghỉ một chút sẽ giúp bạn phục hồi tốt hơn.';
      if (!_isDailyTaskCompleted) {
        _petTask = 'Hít thở sâu 2 phút và vươn vai nhẹ nhàng.';
      }
      return;
    }

    // Phản ứng khen ngợi khi nạp calo hợp lý
    if (_consumedCalories >= calTarget * 0.8 && _consumedCalories <= calTarget + 200) {
      _petState = 'Vui vẻ';
      _petMessage = 'Hôm nay bạn nạp năng lượng rất điều độ ($consumedCalories / $calTarget kcal). Cơ thể bạn đang ở trạng thái cân bằng tuyệt vời!';
      if (!_isDailyTaskCompleted) {
        _petTask = 'Hoàn thành nốt mục tiêu vận động trong ngày.';
      }
      return;
    }

    _petState = 'Năng động';
    _petMessage =
        'Hôm nay bạn đang làm rất tốt. Giữ nhịp đều đặn, cơ thể sẽ cảm ơn bạn.';
    if (!_isDailyTaskCompleted) {
      _petTask = 'Đi bộ thêm 500 bước để chốt mục tiêu hôm nay.';
    }
  }

  void _simulateHeartRate() {
    final change = _random.nextInt(7) - 3;
    _bpm += change;

    if (_bpm < 60) {
      _bpm = 60;
    }
    if (_bpm > 100) {
      _bpm = 100;
    }
  }

  // Comment lại hàm random bước chân cũ
  // int _simulateSteps() {
  //   var stepDelta = 0;
  //   if (_random.nextDouble() > 0.6) {
  //     stepDelta = _random.nextInt(11) + 2;
  //     _steps += stepDelta;
  //   }
  //   return stepDelta;
  // }

  void _simulateWater() {
    _syncWaterProgress();
  }

  void _simulateRecoveryMetrics(int stepDelta) {
    // 1. Calories Burned calculated from actual steps (Thực tế)
    _caloriesBurned = (_steps * 0.04).round() + 80;
    _caloriesBurned = _caloriesBurned.clamp(80, 2500).toInt();

    // 2. HRV calculated from user mood and energy level (Tính thực tế)
    final hrvBase = _currentUser != null ? 62 : 55;
    final moodFactor = (3 - _moodIndex) * 5; // mood 0 -> +15, mood 3 -> +0
    final energyFactor = (_energyLevel * 10).round(); // energy 1.0 -> +10
    _hrv = hrvBase + moodFactor + energyFactor;
    _hrv = _hrv.clamp(40, 85).toInt();

    // 3. Resting HR calculated from age & mood (Thực tế)
    final birthYear = _currentUser?.birthYear ?? (DateTime.now().year - 22);
    final age = DateTime.now().year - birthYear;
    final baseResting = 58 + (age % 4); // 58 to 61 base
    final stressFactor = _moodIndex >= 2 ? (_moodIndex * 3) : 0; // stress adds heart rate
    _restingBpm = baseResting + stressFactor;
    _restingBpm = _restingBpm.clamp(50, 80).toInt();

    // 4. Deep Sleep Minutes calculated from mood and activity (Thực tế)
    final activityBonus = (_steps >= 8000) ? 20 : 0;
    final stressPenalty = _moodIndex >= 2 ? (_moodIndex * 15) : 0;
    _deepSleepMinutes = 200 + activityBonus - stressPenalty;
    _deepSleepMinutes = _deepSleepMinutes.clamp(120, 280).toInt();

    // Delta values are relatively stable (tỉ lệ tăng trưởng)
    _hrvDelta = (_moodIndex == 0) ? 12 : (_moodIndex == 3 ? -8 : 4);
    _calorieDelta = (_steps >= 10000) ? 25 : (_steps <= 2000 ? -12 : 8);
    _deepSleepDeltaMinutes = (_moodIndex == 0) ? 35 : (_moodIndex == 3 ? -25 : 15);
  }

  void _simulateEnergyAndMood() {
    final hydrationFactor = (_waterPercentage / 100).clamp(0.0, 1.0);
    final movementFactor = (_steps / _goal).clamp(0.0, 1.0);
    final heartFactor = ((100 - _bpm) / 40).clamp(0.0, 1.0);

    var targetEnergy =
        0.22 +
        (hydrationFactor * 0.24) +
        (movementFactor * 0.26) +
        (heartFactor * 0.28);
    targetEnergy = targetEnergy.clamp(0.35, 0.95).toDouble();

    _energyLevel += (targetEnergy - _energyLevel) * 0.22;
    _energyLevel += (_random.nextDouble() - 0.5) * 0.04;
    _energyLevel = _energyLevel.clamp(0.2, 1.0).toDouble();

    if (_energyLevel >= 0.8) {
      _moodIndex = 0;
    } else if (_energyLevel >= 0.6) {
      _moodIndex = 1;
    } else if (_energyLevel >= 0.4) {
      _moodIndex = 2;
    } else {
      _moodIndex = 3;
    }

    _updateSymptomsFromVitals();
  }

  void _simulateWeeklyActivity() {
    if (_ticks % 3 != 0) {
      return;
    }

    final trend = ((_steps / _goal).clamp(0.0, 1.0) - 0.6) * 0.02;
    for (var i = 0; i < _weeklyActivity.length; i++) {
      final drift = (_random.nextDouble() - 0.5) * 0.06;
      _weeklyActivity[i] = (_weeklyActivity[i] + trend + drift)
          .clamp(0.32, 0.98)
          .toDouble();
    }
  }

  void _updateHealthScore() {
    // 1. HRV Score (RMSSD): baseline 65 ms
    final scoreHrv = (100.0 - (65.0 - _hrv) * 10.0).clamp(0.0, 100.0);
    
    // 2. Resting HR Score (baseline 60 bpm)
    final scoreRhr = (_restingBpm <= 60)
        ? 100.0
        : (100.0 - (_restingBpm - 60) * 5.83).clamp(0.0, 100.0);
        
    // 3. Deep Sleep Score (ideal >= 120 mins)
    final scoreSleep = (_deepSleepMinutes >= 120)
        ? 100.0
        : (_deepSleepMinutes / 120.0 * 100.0).clamp(0.0, 100.0);
        
    // 4. Active Calories Score vs Active TDEE target (BMR * 0.375, clamped [300, 700])
    final activeCalorieGoal = (bmr * 0.375).clamp(300.0, 700.0);
    final scoreActivity = (_caloriesBurned / activeCalorieGoal * 100.0).clamp(0.0, 100.0);

    // Composite Health Score
    final raw = (scoreHrv * 0.25) +
                (scoreRhr * 0.20) +
                (scoreSleep * 0.30) +
                (scoreActivity * 0.25);
                
    _healthScore = raw.round().clamp(0, 100).toInt();
  }

  void _syncWaterProgress() {
    _waterLiters = (_waterLiters * 100).round() / 100;
    _waterPercentage = max(0, ((_waterLiters / _waterGoal) * 100).round());
  }

  void _updateSymptomsFromVitals() {
    _selectedSymptoms.clear();

    if (_energyLevel < 0.45) {
      _selectedSymptoms.add('Mất tập trung');
    }
    if (_bpm > 82) {
      _selectedSymptoms.add('Đau đầu nhẹ');
    }
    if (_waterPercentage < 65) {
      _selectedSymptoms.add('Mỏi cổ vai');
    }
    if (_deepSleepMinutes < 180) {
      _selectedSymptoms.add('Mất ngủ');
    }

    if (_selectedSymptoms.isEmpty) {
      _selectedSymptoms.add('Không có');
    }
  }

  // Hành động thủ công từ UI
  Future<void> addNutritionInfo(NutritionAnalysisResult result) async {
    _consumedCalories += result.calories;
    _consumedProtein += result.proteinG.round();
    _consumedCarbs += result.carbsG.round();
    _consumedFat += result.fatG.round();
    _todayFoods.add(result.name);
    await _saveNutritionData();

    if (result.waterLiters > 0) {
      _waterLiters += result.waterLiters;
      if (_waterLiters > 10.0) {
        _waterLiters = 10.0;
      }
      _syncWaterProgress();
      await _saveWaterData();
    }

    _simulateEnergyAndMood();
    _updateHealthScore();
    _refreshPetInsights();
    notifyListeners();
  }

  void addWater() {
    _waterLiters += 0.25;
    if (_waterLiters > 10.0) {
      _waterLiters = 10.0;
    }
    _syncWaterProgress();
    _saveWaterData();
    _simulateEnergyAndMood();
    _updateHealthScore();
    _refreshPetInsights();
    
    addRecentActivity(
      title: 'Đã cập nhật nước uống',
      subtitle: 'Thêm 250 ml vào mục tiêu ngày',
      trailing: DateFormatter.formatHourMinute(DateTime.now()),
      gifAssetPath: 'assets/icons/gif/water.gif',
      iconName: 'water_drop_rounded',
    );
    notifyListeners();
  }

  void removeWater() {
    _waterLiters -= 0.25;
    if (_waterLiters < 0) {
      _waterLiters = 0;
    }
    _syncWaterProgress();
    _saveWaterData();
    _simulateEnergyAndMood();
    _updateHealthScore();
    _refreshPetInsights();
    
    addRecentActivity(
      title: 'Đã bớt nước uống',
      subtitle: 'Giảm 250 ml mục tiêu ngày',
      trailing: DateFormatter.formatHourMinute(DateTime.now()),
      gifAssetPath: 'assets/icons/gif/water.gif',
      iconName: 'water_drop_rounded',
    );
    notifyListeners();
  }

  Future<void> _saveWaterData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_getKey('water_liters'), _waterLiters);
    } catch (e) {
      debugPrint('🚨 [HealthProvider] Lỗi khi lưu lượng nước: $e');
    }
  }

  void setMoodIndex(int value) {
    _moodIndex = value.clamp(0, 3).toInt();

    switch (_moodIndex) {
      case 0:
        _energyLevel = max(_energyLevel, 0.85);
        break;
      case 1:
        _energyLevel = _energyLevel.clamp(0.6, 0.8).toDouble();
        break;
      case 2:
        _energyLevel = _energyLevel.clamp(0.4, 0.62).toDouble();
        break;
      default:
        _energyLevel = min(_energyLevel, 0.42);
    }

    _updateSymptomsFromVitals();
    _updateHealthScore();
    _refreshPetInsights();
    notifyListeners();
  }

  void setEnergyLevel(double value) {
    _energyLevel = value.clamp(0.0, 1.0).toDouble();

    if (_energyLevel >= 0.8) {
      _moodIndex = 0;
    } else if (_energyLevel >= 0.6) {
      _moodIndex = 1;
    } else if (_energyLevel >= 0.4) {
      _moodIndex = 2;
    } else {
      _moodIndex = 3;
    }

    _updateSymptomsFromVitals();
    _updateHealthScore();
    _refreshPetInsights();
    notifyListeners();
  }

  void toggleSymptom(String symptom, bool selected) {
    if (symptom == 'Không có') {
      if (selected) {
        _selectedSymptoms
          ..clear()
          ..add('Không có');
      } else {
        _selectedSymptoms.remove('Không có');
      }
    } else {
      if (selected) {
        _selectedSymptoms
          ..remove('Không có')
          ..add(symptom);
      } else {
        _selectedSymptoms.remove(symptom);
      }
    }

    if (_selectedSymptoms.isEmpty) {
      _selectedSymptoms.add('Không có');
    }

    notifyListeners();
  }

  // Hỗ trợ tương thích với code cũ
  void updateSteps(int newSteps) {
    _steps = newSteps;
    _saveStepsToPrefs();
    _simulateEnergyAndMood();
    _updateHealthScore();
    _refreshPetInsights();
    notifyListeners();
  }

  Future<void> _saveStepsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_getKey('today_steps'), _steps);
    } catch (e) {
      debugPrint('🚨 [HealthProvider] Lỗi khi lưu bước chân: $e');
    }
  }

  void updateHeartRate(int newBpm) {
    _bpm = newBpm.clamp(60, 100).toInt();
    _simulateEnergyAndMood();
    _updateHealthScore();
    _refreshPetInsights();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _effectResetTimer?.cancel();
    _sensorService.dispose(); // Hủy lắng nghe luồng đếm bước chân
    _screenSubscription?.cancel(); // Hủy lắng nghe sự kiện màn hình
    _pokeSubscription?.cancel(); // Hủy lắng nghe Poke
    super.dispose();
  }

  // ─── AI Tasks Methods ─────────────────────────────────────

  /// Tự động gọi Gemini AI để sinh 3 nhiệm vụ cho ngày mới.
  /// Chỉ được gọi 1 lần/ngày (khi chưa có nhiệm vụ hoặc khi reset ngày mới).
  Future<void> _generateDailyAiTasks() async {
    if (_isLoadingAiTasks) return; // Tránh gọi trùng
    if (_aiTasks.isNotEmpty) return; // Đã có nhiệm vụ rồi, không tạo lại

    _isLoadingAiTasks = true;
    _aiTasksError = null;
    notifyListeners();

    try {
      final screenTimeService = ScreenTimeService();
      final screenUsage = await screenTimeService.getSocialMediaUsageToday();

      final tasks = await _geminiService.generateHealthTasks(
        steps: _steps,
        stepGoal: _goal,
        bpm: _bpm,
        waterLiters: _waterLiters,
        waterGoal: _waterGoal,
        energyLevel: _energyLevel,
        screenTimeData: screenUsage,
        heightCm: _currentUser?.heightCm,
        weightKg: _currentUser?.weightKg,
        birthYear: _currentUser?.birthYear,
        gender: _currentUser?.gender,
        activityLevel: _currentUser?.activityLevel,
        targetBedtime: _currentUser?.targetBedtime,
        targetWakeTime: _currentUser?.targetWakeTime,
      );
      // Đảm bảo luôn đúng 3 nhiệm vụ
      _aiTasks = tasks.take(3).toList();
      _aiTasksError = null;
      _lastAiFetchTime = DateTime.now();
      _saveAiTasks();
      debugPrint('✅ [HealthProvider] Đã tạo ${_aiTasks.length} nhiệm vụ AI cho ngày mới');
    } catch (e) {
      _aiTasksError = 'Không thể tải gợi ý AI: $e';
      debugPrint('🚨 [HealthProvider] Lỗi _generateDailyAiTasks: $e');
    }

    _isLoadingAiTasks = false;
    _saveAiTasks();
    notifyListeners();
  }

  /// Hoàn thành 1 nhiệm vụ AI → cộng EXP theo expReward của task đó.
  void completeAiTask(String taskId) {
    final index = _aiTasks.indexWhere((t) => t.id == taskId);
    if (index < 0) return;

    final task = _aiTasks[index];
    if (task.isCompleted) return; // Tránh hoàn thành trùng lặp để gian lận EXP
    final expGained = task.expReward;

    // Đánh dấu hoàn thành
    _aiTasks[index] = task.copyWith(isCompleted: true);

    // Cộng EXP
    _currentExp += expGained;
    var didLevelUp = false;
    if (_currentExp >= _expToNextLevel) {
      _level++;
      _currentExp -= _expToNextLevel;
      didLevelUp = true;
    }

    _petTask = 'Hoàn thành "${task.title}"! +$expGained EXP';
    _triggerPetEnvironmentEffect(didLevelUp: didLevelUp);
    
    // Cộng EXP cho pet trên Firestore database
    _petService.gainExperience(_currentUserId, expGained);
    
    addRecentActivity(
      title: 'Nhiệm vụ AI hoàn thành',
      subtitle: task.title,
      trailing: DateFormatter.formatHourMinute(DateTime.now()),
      gifAssetPath: 'assets/icons/gif/bolt.gif',
      iconName: 'star_rounded',
    );

    _saveAiTasks();
    notifyListeners();
  }

  void _triggerPetEnvironmentEffect({required bool didLevelUp}) {
    _effectResetTimer?.cancel();
    _showLevelUpEffect = didLevelUp;
    _showTaskCompletedEffect = !didLevelUp;

    _effectResetTimer = Timer(const Duration(seconds: 4), () {
      _showLevelUpEffect = false;
      _showTaskCompletedEffect = false;
      notifyListeners();
    });
  }

  //Hàm hoàn thành nhiệm vụ (rule-based cũ)
  void completeDailyTask() {
    if (_isDailyTaskCompleted) return; // Tránh hoàn thành trùng lặp để gian lận EXP
    // Tăng 20 EXP mỗi khi hoàn thành nhiệm vụ AI giao
    _currentExp += 20;
    var didLevelUp = false;

    // Logic Lên cấp
    if (_currentExp >= _expToNextLevel) {
      _level++;
      _currentExp -= _expToNextLevel; // Giữ lại phần EXP dư
      didLevelUp = true;
    }

    _isDailyTaskCompleted = true;
    _saveDailyTaskStatus(true);

    // Đổi nhiệm vụ thành trạng thái hoàn thành để UI cập nhật
    _petTask = 'Đã hoàn thành! Cậu làm tốt lắm.';
    _triggerPetEnvironmentEffect(didLevelUp: didLevelUp);
    
    // Cộng EXP cho pet trên Firestore database
    _petService.gainExperience(_currentUserId, 20);
    
    notifyListeners();
  }

  void _initRealSensors() {
    _sensorService.initPedometer((stepsFromDevice) async {
      if (_lastDeviceSteps == -1) {
        _lastDeviceSteps = stepsFromDevice;
        return;
      }
      
      if (stepsFromDevice < _lastDeviceSteps) {
        // Thiết bị có thể đã khởi động lại hoặc cảm biến reset
        _lastDeviceSteps = stepsFromDevice;
        return;
      }
      
      int delta = stepsFromDevice - _lastDeviceSteps;
      if (delta > 0) {
        _steps += delta;
        _lastDeviceSteps = stepsFromDevice;
        
        // Cập nhật SharedPreferences
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(_getKey('today_steps'), _steps);
        } catch (e) {
          debugPrint('🚨 [HealthProvider] Lỗi khi lưu số bước chân: $e');
        }
        
        _simulateEnergyAndMood();
        _updateHealthScore();
        _refreshPetInsights();
        notifyListeners();
      }
    });
  }

  // ─── Các phương thức đồng bộ SharedPreferences ──────────────────────

  Future<void> _saveAiTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = json.encode(_aiTasks.map((t) => t.toJson()).toList());
      await prefs.setString(_getKey('ai_tasks_json'), encoded);
      if (_lastAiFetchTime != null) {
        await prefs.setString(_getKey('last_ai_fetch_time'), _lastAiFetchTime!.toIso8601String());
      }
    } catch (e) {
      debugPrint('🚨 [HealthProvider] Lỗi khi lưu AI tasks: $e');
    }
  }

  Future<void> _saveDailyTaskStatus(bool completed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_getKey('is_daily_task_completed'), completed);
    } catch (e) {
      debugPrint('🚨 [HealthProvider] Lỗi khi lưu trạng thái daily task: $e');
    }
  }


  Future<void> _loadStateFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // Đảm bảo SharedPreferences đồng bộ giữa UI và Background Isolate
      _hasOnboardedBedtime = prefs.getBool(_getKey('has_onboarded_bedtime')) ?? false;
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month}-${now.day}';
      final lastResetStr = prefs.getString(_getKey('last_task_reset_date'));

      if (lastResetStr == todayStr) {
        _isDailyTaskCompleted = prefs.getBool(_getKey('is_daily_task_completed')) ?? false;
        _hasShownScreenTimeAlert = prefs.getBool(_getKey('has_shown_screentime_alert')) ?? false;
        
        // Tải số bước chân và lượng nước đã lưu
        _steps = prefs.getInt(_getKey('today_steps')) ?? 0;
        _waterLiters = prefs.getDouble(_getKey('water_liters')) ?? 0.0;
        _syncWaterProgress();

        final String? aiTasksStr = prefs.getString(_getKey('ai_tasks_json'));
        if (aiTasksStr != null && aiTasksStr.isNotEmpty) {
          final List<dynamic> decoded = json.decode(aiTasksStr);
          _aiTasks = decoded.map((item) => TaskSuggestion.fromJson(item as Map<String, dynamic>)).toList();
        } else {
          _aiTasks = [];
        }
        final String? lastAiFetchTimeStr = prefs.getString(_getKey('last_ai_fetch_time'));
        if (lastAiFetchTimeStr != null && lastAiFetchTimeStr.isNotEmpty) {
          _lastAiFetchTime = DateTime.tryParse(lastAiFetchTimeStr);
        }
        // Tải thêm thông tin dinh dưỡng
        _consumedCalories = prefs.getInt(_getKey('consumed_calories')) ?? 0;
        _consumedProtein = prefs.getInt(_getKey('consumed_protein')) ?? 0;
        _consumedCarbs = prefs.getInt(_getKey('consumed_carbs')) ?? 0;
        _consumedFat = prefs.getInt(_getKey('consumed_fat')) ?? 0;
        _todayFoods = prefs.getStringList(_getKey('today_foods')) ?? [];
        // Tải thông tin giấc ngủ đã lưu
        _sleepMinutes = prefs.getInt(_getKey('sleep_minutes')) ?? 465;
        _deepSleepMinutes = prefs.getInt(_getKey('deep_sleep_minutes')) ?? 198;

        // Tải Plan Items và Recent Activities
        final String? planItemsStr = prefs.getString(_getKey('plan_items_json'));
        if (planItemsStr != null && planItemsStr.isNotEmpty) {
          final List<dynamic> decoded = json.decode(planItemsStr);
          _planItems = decoded.map((item) => HomePlanItem.fromJson(item as Map<String, dynamic>)).toList();
        } else {
          _planItems = List.from(_defaultPlanItems);
        }

        final String? recentActStr = prefs.getString(_getKey('recent_activities_json'));
        if (recentActStr != null && recentActStr.isNotEmpty) {
          final List<dynamic> decoded = json.decode(recentActStr);
          _recentActivities = decoded.map((item) => RecentActivity.fromJson(item as Map<String, dynamic>)).toList();
        } else {
          _recentActivities = [];
        }

        _todayNote = prefs.getString(_getKey('today_note')) ?? '';
      } else {
        // Reset cho ngày mới
        _isDailyTaskCompleted = false;
        _hasShownScreenTimeAlert = false;
        _steps = 0;
        _waterLiters = 0.0;
        _syncWaterProgress();
        _aiTasks = [];
        _lastAiFetchTime = null;
        _consumedCalories = 0;
        _consumedProtein = 0;
        _consumedCarbs = 0;
        _consumedFat = 0;
        _todayFoods = [];
        _sleepMinutes = 465;
        _deepSleepMinutes = 198;
        _todayNote = '';
        _onboardingBedtimeInsight = null;
        _planItems = List.from(_defaultPlanItems);
        _recentActivities = [];
        await prefs.setString(_getKey('last_task_reset_date'), todayStr);
        await prefs.setBool(_getKey('is_daily_task_completed'), false);
        await prefs.setBool(_getKey('has_shown_screentime_alert'), false);
        await prefs.setInt(_getKey('today_steps'), 0);
        await prefs.setDouble(_getKey('water_liters'), 0.0);
        await prefs.setString(_getKey('ai_tasks_json'), '');
        await prefs.setString(_getKey('last_ai_fetch_time'), '');
        await prefs.setInt(_getKey('consumed_calories'), 0);
        await prefs.setInt(_getKey('consumed_protein'), 0);
        await prefs.setInt(_getKey('consumed_carbs'), 0);
        await prefs.setInt(_getKey('consumed_fat'), 0);
        await prefs.setStringList(_getKey('today_foods'), []);
        await prefs.setInt(_getKey('sleep_minutes'), 465);
        await prefs.setInt(_getKey('deep_sleep_minutes'), 198);
        await prefs.setString(_getKey('plan_items_json'), json.encode(_planItems.map((p) => p.toJson()).toList()));
        await prefs.setString(_getKey('recent_activities_json'), '[]');
        await prefs.setString(_getKey('today_note'), '');
      }
      notifyListeners();

      // Tự động tạo nhiệm vụ AI nếu chưa có (ngày mới hoặc lần đầu vào app)
      if (_aiTasks.isEmpty && _currentUserId.isNotEmpty) {
        _generateDailyAiTasks();
      }
    } catch (e) {
      debugPrint('🚨 [HealthProvider] Lỗi khi load trạng thái: $e');
    }
  }

  Future<void> _checkDayChange() async {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month}-${now.day}';
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastResetStr = prefs.getString(_getKey('last_task_reset_date'));
      if (lastResetStr != todayStr) {
        // Reset ngày mới
        _isDailyTaskCompleted = false;
        _hasShownScreenTimeAlert = false;
        _steps = 0;
        _waterLiters = 0.0;
        _syncWaterProgress();
        _aiTasks = [];
        _lastAiFetchTime = null;
        _consumedCalories = 0;
        _consumedProtein = 0;
        _consumedCarbs = 0;
        _consumedFat = 0;
        _todayFoods = [];
        _todayNote = '';
        _onboardingBedtimeInsight = null;
        _planItems = List.from(_defaultPlanItems);
        _recentActivities = [];
        await prefs.setString(_getKey('last_task_reset_date'), todayStr);
        await prefs.setBool(_getKey('is_daily_task_completed'), false);
        await prefs.setBool(_getKey('has_shown_screentime_alert'), false);
        await prefs.setInt(_getKey('today_steps'), 0);
        await prefs.setDouble(_getKey('water_liters'), 0.0);
        await prefs.setString(_getKey('ai_tasks_json'), '');
        await prefs.setString(_getKey('last_ai_fetch_time'), '');
        await prefs.setInt(_getKey('consumed_calories'), 0);
        await prefs.setInt(_getKey('consumed_protein'), 0);
        await prefs.setInt(_getKey('consumed_carbs'), 0);
        await prefs.setInt(_getKey('consumed_fat'), 0);
        await prefs.setStringList(_getKey('today_foods'), []);
        await prefs.setString(_getKey('plan_items_json'), json.encode(_planItems.map((p) => p.toJson()).toList()));
        await prefs.setString(_getKey('recent_activities_json'), '[]');
        await prefs.setString(_getKey('today_note'), '');
        notifyListeners();

        // Tự động tạo nhiệm vụ AI cho ngày mới
        if (_currentUserId.isNotEmpty) {
          _generateDailyAiTasks();
        }
      }
    } catch (e) {
      debugPrint('🚨 [HealthProvider] Lỗi khi check day change: $e');
    }
  }

  // --- HÀM GỌI AI PHÂN TÍCH VÀ CỘNG DỒN ---
  Future<bool> addMealRecord(String mealText) async {
    _isLoadingAI = true;
    notifyListeners();

    try {
      final result = await _geminiService.analyzeNutrition(mealText);
      _isLoadingAI = false;

      if (result != null && result.isValidFood) {
        _consumedCalories += result.totalCalories;
        _consumedProtein += result.totalProtein;
        _consumedCarbs += result.totalCarbs;
        _consumedFat += result.totalFat;
        _todayFoods.addAll(result.foodItems);

        _updateHealthScore();
        await _saveNutritionData();
        
        addRecentActivity(
          title: 'Ghi nhận bữa ăn AI',
          subtitle: '${result.foodItems.join(", ")} (+${result.totalCalories} kcal)',
          trailing: DateFormatter.formatHourMinute(DateTime.now()),
          gifAssetPath: 'assets/icons/gif/fire.gif',
          iconName: 'local_fire_department_rounded',
        );

        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('🚨 Lỗi AI phân tích thức ăn trong Provider: $e');
    }

    _isLoadingAI = false;
    notifyListeners();
    return false;
  }

  Future<void> _saveNutritionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_getKey('consumed_calories'), _consumedCalories);
      await prefs.setInt(_getKey('consumed_protein'), _consumedProtein);
      await prefs.setInt(_getKey('consumed_carbs'), _consumedCarbs);
      await prefs.setInt(_getKey('consumed_fat'), _consumedFat);
      await prefs.setStringList(_getKey('today_foods'), _todayFoods);
    } catch (e) {
      debugPrint('🚨 [HealthProvider] Lỗi khi lưu dinh dưỡng: $e');
    }
  }

  // --- CÁC PHƯƠNG THỨC ĐO GIẤC NGỦ CHỐNG GIAN LẬN ---

  void _initSleepTracking() {
    if (!Platform.isAndroid && !Platform.isIOS) {
      debugPrint('ℹ️ [HealthProvider] Không chạy trên mobile. Bỏ qua lắng nghe sự kiện màn hình.');
      return;
    }
    try {
      _screenSubscription = Screen().screenStateStream?.listen(
        _handleScreenStateEvent,
        onError: (error) {
          debugPrint('🚨 [HealthProvider] Lỗi Stream ScreenState: $error');
        }
      );
      debugPrint('✅ [HealthProvider] Đã khởi tạo lắng nghe sự kiện màn hình (Sleep Tracking)');
    } catch (e) {
      debugPrint('🚨 [HealthProvider] Không thể đăng ký lắng nghe sự kiện màn hình: $e');
    }
  }

  void _handleScreenStateEvent(ScreenStateEvent event) async {
    final now = DateTime.now();
    debugPrint('📱 [HealthProvider] Sự kiện màn hình: $event lúc $now');

    if (event == ScreenStateEvent.SCREEN_OFF) {
      // Xác định vùng rình rập (Bedtime ± 1.5 giờ)
      final targetBed = _currentUser?.targetBedtime ?? '23:00';
      if (_isTimeInTrackingWindow(now, targetBed)) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_getKey('temp_sleep_start'), now.toIso8601String());
          debugPrint('😴 [HealthProvider] Ghi nhận mốc ngủ giả định (temp_sleep_start): $now');
        } catch (e) {
          debugPrint('🚨 [HealthProvider] Lỗi khi lưu temp_sleep_start: $e');
        }
      }
    } else if (event == ScreenStateEvent.SCREEN_ON) {
      await _triggerWakeUpEvent(now);
    }
  }

  bool _isTimeInTrackingWindow(DateTime now, String targetBedtimeStr) {
    try {
      final parts = targetBedtimeStr.split(':');
      if (parts.length != 2) return false;
      final targetHour = int.parse(parts[0]);
      final targetMin = int.parse(parts[1]);

      final bedtimeToday = DateTime(now.year, now.month, now.day, targetHour, targetMin);

      final diff1 = now.difference(bedtimeToday).inMinutes.abs();
      final diff2 = now.difference(bedtimeToday.add(const Duration(days: 1))).inMinutes.abs();
      final diff3 = now.difference(bedtimeToday.subtract(const Duration(days: 1))).inMinutes.abs();

      final minDiff = [diff1, diff2, diff3].reduce(min);
      return minDiff <= 90; // ±1.5 giờ (90 phút)
    } catch (e) {
      debugPrint('🚨 [HealthProvider] Lỗi phân tích targetBedtime: $e');
      return false;
    }
  }

  Future<void> _triggerWakeUpEvent(DateTime wakeTime) async {
    if (_currentUserId.isEmpty) return;
    if (_shouldShowSleepConfirmation) return; // Đang chờ xác nhận mốc cũ, không đè lên

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final tempSleepStartStr = prefs.getString(_getKey('temp_sleep_start'));

      if (tempSleepStartStr != null && tempSleepStartStr.isNotEmpty) {
        final tempSleepStart = DateTime.tryParse(tempSleepStartStr);
        if (tempSleepStart != null) {
          final rawDuration = wakeTime.difference(tempSleepStart);
          if (rawDuration.inMinutes >= 30) {
            // Không kích hoạt wake-up nếu đang trong vùng Bedtime Tracking Window
            final targetBed = _currentUser?.targetBedtime ?? '23:00';
            if (_isTimeInTrackingWindow(wakeTime, targetBed)) {
              debugPrint('😴 [HealthProvider] Nhận SCREEN_ON nhưng vẫn trong Bedtime Tracking Window. Bỏ qua.');
              return;
            }

            // Chạy đối soát chống gian lận
            final actualSleepStart = await _runSleepAntiCheat(tempSleepStart, wakeTime);

            _sleepStartToConfirm = actualSleepStart;
            _sleepWakeToConfirm = wakeTime;
            _shouldShowSleepConfirmation = true;
            notifyListeners();
            debugPrint('😴 [HealthProvider] Yêu cầu xác nhận giấc ngủ: từ $actualSleepStart đến $wakeTime');
          }
        }
      }
    } catch (e) {
      debugPrint('🚨 [HealthProvider] Lỗi _triggerWakeUpEvent: $e');
    }
  }

  Future<void> checkSleepRecordOnAppOpen() async {
    if (_currentUserId.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final tempSleepStartStr = prefs.getString(_getKey('temp_sleep_start'));

      if (tempSleepStartStr != null && tempSleepStartStr.isNotEmpty) {
        final tempSleepStart = DateTime.tryParse(tempSleepStartStr);
        if (tempSleepStart != null) {
          final now = DateTime.now();
          final diff = now.difference(tempSleepStart);
          if (diff.inHours >= 1 && diff.inHours <= 24) {
            if (diff.inMinutes >= 30) {
              await _triggerWakeUpEvent(now);
            }
          } else if (diff.inHours > 24) {
            await prefs.remove(_getKey('temp_sleep_start'));
            debugPrint('🧹 [HealthProvider] Xóa mốc temp_sleep_start quá hạn 24 giờ.');
          }
        }
      }
    } catch (e) {
      debugPrint('🚨 [HealthProvider] Lỗi checkSleepRecordOnAppOpen: $e');
    }
  }

  Future<DateTime> _runSleepAntiCheat(DateTime start, DateTime wake) async {
    DateTime actualStart = start;

    if (!Platform.isAndroid) {
      debugPrint('🛡️ [Anti-Cheat] Không phải thiết bị Android. Bỏ qua đối soát app_usage.');
      return actualStart;
    }

    try {
      final appUsage = AppUsage();
      final infoList = await appUsage.getAppUsage(start, wake);

      final Map<String, String> targetApps = {
        'com.facebook.katana': 'Facebook',
        'com.zhiliaoapp.musically': 'TikTok',
        'com.ss.android.ugc.trill': 'TikTok',
        'com.google.android.youtube': 'YouTube',
        'com.instagram.android': 'Instagram',
        'com.tencent.ig': 'PUBG Mobile',
        'com.garena.game.kgvn': 'Liên Quân Mobile',
        'com.android.chrome': 'Chrome',
        'com.coccoc.trinhduyet': 'Cốc Cốc',
        'com.netflix.mediaclient': 'Netflix',
      };

      DateTime? latestForeground;
      for (var info in infoList) {
        if (targetApps.containsKey(info.packageName) && info.usage > Duration.zero) {
          final lastFore = info.lastForeground;
          if (lastFore.isAfter(start) && lastFore.isBefore(wake)) {
            if (latestForeground == null || lastFore.isAfter(latestForeground)) {
              latestForeground = lastFore;
            }
          }
        }
      }

      if (latestForeground != null) {
        actualStart = latestForeground;
        debugPrint('🛡️ [Anti-Cheat] Phát hiện dùng ứng dụng lướt web/mạng xã hội/game lúc $latestForeground. Dời mốc Actual Sleep Start thành: $actualStart');
      } else {
        debugPrint('🛡️ [Anti-Cheat] Không phát hiện gian lận. Mốc bắt đầu ngủ: $actualStart.');
      }
    } catch (e) {
      debugPrint('🚨 [Anti-Cheat] Lỗi truy vấn app_usage: $e');
    }

    return actualStart;
  }

  Future<void> confirmSleep(DateTime start, DateTime wake) async {
    final duration = wake.difference(start);
    _sleepMinutes = duration.inMinutes.clamp(0, 1440);
    _deepSleepMinutes = (_sleepMinutes * 0.23).round();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_getKey('temp_sleep_start'));
      await prefs.setInt(_getKey('sleep_minutes'), _sleepMinutes);
      await prefs.setInt(_getKey('deep_sleep_minutes'), _deepSleepMinutes);
    } catch (e) {
      debugPrint('🚨 [HealthProvider] Lỗi lưu kết quả giấc ngủ: $e');
    }

    _shouldShowSleepConfirmation = false;
    _sleepStartToConfirm = null;
    _sleepWakeToConfirm = null;
    
    addRecentActivity(
      title: 'Đã xác nhận giấc ngủ',
      subtitle: 'Ngủ: ${sleepDurationLabel} · Chất lượng ${sleepQuality}',
      trailing: DateFormatter.formatHourMinute(DateTime.now()),
      gifAssetPath: 'assets/icons/gif/sleep.gif',
      iconName: 'nightlight_round',
    );

    _isLoadingAI = true;
    _petMessage = 'Đang phân tích dữ liệu giấc ngủ của bạn...';
    notifyListeners();

    try {
      final targetBed = _currentUser?.targetBedtime ?? '23:00';
      final targetWake = _currentUser?.targetWakeTime ?? '07:00';
      final insight = await _geminiService.getSleepInsight(
        start: start,
        wake: wake,
        durationHours: _sleepMinutes / 60.0,
        targetBedtime: targetBed,
        targetWakeTime: targetWake,
      );
      _petMessage = insight;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_getKey('pet_message'), _petMessage);
    } catch (e) {
      debugPrint('🚨 [HealthProvider] Lỗi AI Sleep Insight: $e');
      _petMessage = 'Cảm ơn bạn đã cập nhật thông tin giấc ngủ.';
    }

    _isLoadingAI = false;
    _updateHealthScore();
    notifyListeners();
  }

  void dismissSleepConfirmation() async {
    _shouldShowSleepConfirmation = false;
    _sleepStartToConfirm = null;
    _sleepWakeToConfirm = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_getKey('temp_sleep_start'));
    } catch (e) {
      debugPrint('🚨 [HealthProvider] Lỗi xóa temp_sleep_start: $e');
    }
    notifyListeners();
  }

  DateTime normalizeSleepTimes(DateTime start, DateTime wake) {
    if (start.isAfter(wake)) {
      start = start.subtract(const Duration(days: 1));
    }
    return start;
  }

  // --- QUẢN LÝ LỊCH SỬ NHẬT KÝ SỨC KHỎE ---
  List<DiaryEntry> _diaryHistory = [];
  bool _isLoadingHistory = false;

  List<DiaryEntry> get diaryHistory => _diaryHistory;
  bool get isLoadingHistory => _isLoadingHistory;

  /// Tải lịch sử nhật ký từ Firestore
  Future<void> fetchDiaryHistory() async {
    if (_currentUserId.isEmpty) return;
    _isLoadingHistory = true;
    notifyListeners();

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('diaries')
          .orderBy('date', descending: true)
          .get();

      _diaryHistory = querySnapshot.docs
          .map((doc) => DiaryEntry.fromJson({
                ...doc.data(),
                'id': doc.id,
              }))
          .toList();
    } catch (e) {
      debugPrint('🚨 [HealthProvider] Lỗi khi tải lịch sử nhật ký: $e');
    }

    _isLoadingHistory = false;
    notifyListeners();
  }

  /// Lưu hoặc cập nhật nhật ký hôm nay lên Firestore
  Future<bool> saveCurrentDiaryEntry(String noteText) async {
    if (_currentUserId.isEmpty) return false;

    try {
      final now = DateTime.now();
      final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      
      // Tạo một đối tượng DiaryEntry mới
      final newEntry = DiaryEntry(
        id: dateStr,
        userId: _currentUserId,
        date: DateTime(now.year, now.month, now.day),
        stepCount: _steps,
        caloriesBurned: _caloriesBurned,
        waterIntakeLiters: _waterLiters,
        sleepMinutes: _sleepMinutes,
        deepSleepMinutes: _deepSleepMinutes,
        heartRateBpm: _bpm,
        restingHeartRate: _restingBpm,
        hrv: _hrv,
        moodIndex: _moodIndex,
        energyLevel: _energyLevel,
        symptoms: _selectedSymptoms.toList(),
        note: noteText,
        consumedCalories: _consumedCalories,
        consumedProtein: _consumedProtein,
        consumedCarbs: _consumedCarbs,
        consumedFat: _consumedFat,
        todayFoods: _todayFoods,
      );

      // Lưu lên Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('diaries')
          .doc(dateStr)
          .set(newEntry.toJson());

      // Tự động tính danh hiệu Gen Z hôm nay
      final title = TitleService.calculateTitle(newEntry);

      // Cập nhật Pet trên Firestore
      final petRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('pets')
          .doc('current_pet');

      await petRef.update({
        'current_title': title,
        'owner_name': _currentUser?.name ?? 'Bạn của Pet',
      });
      debugPrint('🏆 [HealthProvider] Đã chấm danh hiệu mới cho Pet: $title');

      // Cập nhật local note
      _todayNote = noteText;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_getKey('today_note'), noteText);

      // Cập nhật local list _diaryHistory
      final existingIndex = _diaryHistory.indexWhere((e) => e.id == dateStr);
      
      // Tặng EXP cho Pet nếu hôm nay chưa lưu nhật ký lần nào
      if (existingIndex < 0) {
        _diaryHistory.insert(0, newEntry);
        // Tặng +20 EXP cho pet
        await _petService.gainExperience(_currentUserId, 20);
        // Cập nhật hiển thị Pet
        _petTask = 'Đã hoàn thành check-in nhật ký hôm nay! +20 EXP';
        _triggerPetEnvironmentEffect(didLevelUp: false);
      } else {
        _diaryHistory[existingIndex] = newEntry;
      }

      _refreshPetInsights();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('🚨 [HealthProvider] Lỗi khi lưu nhật ký: $e');
      return false;
    }
  }

  /// Xóa một bản ghi nhật ký khỏi Firestore và cache
  Future<bool> deleteDiaryEntry(String entryId) async {
    if (_currentUserId.isEmpty) return false;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('diaries')
          .doc(entryId)
          .delete();

      // Nếu xóa nhật ký hôm nay, xóa luôn ghi chú trong SharedPreferences và state
      final now = DateTime.now();
      final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      if (entryId == dateStr) {
        _todayNote = '';
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_getKey('today_note'));
      }

      _diaryHistory.removeWhere((e) => e.id == entryId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('🚨 [HealthProvider] Lỗi khi xóa nhật ký: $e');
      return false;
    }
  }
}
