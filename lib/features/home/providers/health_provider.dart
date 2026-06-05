import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/task_suggestion.dart';
import '../../../services/ai/gemini_service.dart';
import '../../../services/pet/pet_service.dart';
import '../../../models/nutrition_analysis_result.dart';
import '../../../services/sensor/health_sensor_service.dart';
import '../../../services/screen_time_service.dart';

class HealthProvider extends ChangeNotifier {
  String _currentUserEmail = 'shcare_tester_001';
  int _lastDeviceSteps = -1;
  bool _isScreenTimeExceeded = false;

  bool get isScreenTimeExceeded => _isScreenTimeExceeded;

  // Cấu hình môi trường và ngưỡng cảnh báo
  static const bool isDebugMode = true;
  static const int debugScreenTimeLimit = 5;
  static const int prodScreenTimeLimit = 120;

  bool _hasShownScreenTimeAlert = false;
  String _screenTimeDetails = '';

  bool get hasShownScreenTimeAlert => _hasShownScreenTimeAlert;
  String get screenTimeDetails => _screenTimeDetails;

  String _getKey(String key) {
    return '${_currentUserEmail}_$key';
  }

  void updateUser(String email) async {
    final cleanEmail = email.isNotEmpty
        ? email.replaceAll('@', '_').replaceAll('.', '_')
        : 'shcare_tester_001';

    if (_currentUserEmail != cleanEmail) {
      _currentUserEmail = cleanEmail;
      _lastDeviceSteps = -1; // Reset device steps baseline for the new profile
      _isScreenTimeExceeded = false;
      _hasShownScreenTimeAlert = false;
      _screenTimeDetails = '';
      
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_user_email', cleanEmail);
      } catch (e) {
        debugPrint('🚨 [HealthProvider] Lỗi khi lưu current_user_email: $e');
      }

      _loadStateFromPrefs();
      checkScreenTimeLimit();
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

  int get consumedCalories => _consumedCalories;
  int get consumedProtein => _consumedProtein;
  int get consumedCarbs => _consumedCarbs;
  int get consumedFat => _consumedFat;
  List<String> get todayFoods => _todayFoods;

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
  
  bool get allTasksCompleted {
    final activeAiTasks = _aiTasks.where((t) => !t.isCompleted && !t.isDismissed).toList();
    if (activeAiTasks.isNotEmpty) {
      return false;
    }
    return _isDailyTaskCompleted;
  }

  bool get canRefreshAiTasks {
    if (_isLoadingAiTasks) return false;
    if (allTasksCompleted) return true;
    if (_lastAiFetchTime == null) return true;

    final now = DateTime.now();
    final diff = now.difference(_lastAiFetchTime!);
    return diff.inHours >= 4;
  }

  String get petTask {
    if (allTasksCompleted) {
      return 'Nhiệm vụ đã hoàn thành';
    }
    final activeTasks = _aiTasks.where((t) => !t.isCompleted && !t.isDismissed).toList();
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
    final total = _weeklyActivity.fold<double>(0, (sum, item) => sum + item);
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

    if (_isScreenTimeExceeded) {
      _petState = 'Mệt mỏi';
      _petMessage =
          'Bạn đã dùng mạng xã hội / game quá 5 phút hôm nay rồi đó. Đứng dậy đi lại và thư giãn mắt đi nào!';
      if (!_isDailyTaskCompleted) {
        _petTask = 'Rời màn hình: Nhắm mắt thư giãn 5 phút.';
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
    if (_random.nextDouble() > 0.98) {
      _waterLiters += 0.1;
      if (_waterLiters > _waterGoal) {
        _waterLiters = _waterGoal;
      }
    }
    _syncWaterProgress();
  }

  void _simulateRecoveryMetrics(int stepDelta) {
    if (stepDelta > 0) {
      _caloriesBurned += max(
        1,
        (stepDelta * (0.03 + _random.nextDouble() * 0.03)).round(),
      );
    } else if (_random.nextDouble() > 0.9) {
      _caloriesBurned += 1;
    }
    _caloriesBurned = _caloriesBurned.clamp(320, 1200).toInt();

    _hrv += _random.nextInt(3) - 1;
    _hrv = _hrv.clamp(40, 72).toInt();

    final targetResting = (_bpm - 12 + (_random.nextInt(3) - 1))
        .clamp(52, 72)
        .toInt();
    if (_restingBpm < targetResting) {
      _restingBpm += 1;
    } else if (_restingBpm > targetResting) {
      _restingBpm -= 1;
    }

    if (_random.nextDouble() > 0.97) {
      _deepSleepMinutes += _random.nextInt(5) - 2;
      _deepSleepMinutes = _deepSleepMinutes.clamp(160, 250).toInt();
    }

    _hrvDelta += _random.nextInt(3) - 1;
    _hrvDelta = _hrvDelta.clamp(4, 14).toInt();

    _calorieDelta += _random.nextInt(3) - 1;
    _calorieDelta = _calorieDelta.clamp(6, 18).toInt();

    _deepSleepDeltaMinutes += _random.nextInt(5) - 2;
    _deepSleepDeltaMinutes = _deepSleepDeltaMinutes.clamp(8, 40).toInt();
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
    final stepScore = (_steps / _goal).clamp(0.0, 1.0);
    final hydrationScore = (_waterPercentage / 100).clamp(0.0, 1.0);
    final recoveryScore = ((_hrv - 40) / 30).clamp(0.0, 1.0);
    final sleepScore = (_deepSleepMinutes / 240).clamp(0.0, 1.0);
    final energyScore = _energyLevel.clamp(0.0, 1.0);

    final raw =
        (stepScore * 0.28) +
        (hydrationScore * 0.18) +
        (recoveryScore * 0.2) +
        (sleepScore * 0.2) +
        (energyScore * 0.14);

    _healthScore = (raw * 100).round().clamp(60, 98).toInt();
  }

  void _syncWaterProgress() {
    _waterLiters = (_waterLiters * 100).round() / 100;
    _waterPercentage = ((_waterLiters / _waterGoal) * 100)
        .round()
        .clamp(0, 100)
        .toInt();
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
      if (_waterLiters > _waterGoal) {
        _waterLiters = _waterGoal;
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
    if (_waterLiters > _waterGoal) {
      _waterLiters = _waterGoal;
    }
    _syncWaterProgress();
    _saveWaterData();
    _simulateEnergyAndMood();
    _updateHealthScore();
    _refreshPetInsights();
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
    super.dispose();
  }

  // ─── AI Tasks Methods ─────────────────────────────────────

  /// Gọi Gemini AI để sinh nhiệm vụ mới dựa trên chỉ số hiện tại.
  Future<void> refreshAiTasks() async {
    if (_isLoadingAiTasks) return; // Tránh gọi trùng

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
      );
      _aiTasks = tasks;
      _aiTasksError = null;
      _lastAiFetchTime = DateTime.now(); // Cập nhật thời điểm gọi AI thành công
      _saveAiTasks(); // Lưu lại danh sách nhiệm vụ AI mới và thời gian gọi
      debugPrint('✅ [HealthProvider] Đã nhận ${tasks.length} nhiệm vụ AI');
    } catch (e) {
      _aiTasksError = 'Không thể tải gợi ý AI: $e';
      debugPrint('🚨 [HealthProvider] Lỗi refreshAiTasks: $e');
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
    _petService.gainExperience(_currentUserEmail, expGained);
    
    _saveAiTasks();
    notifyListeners();
  }

  /// Bỏ qua (dismiss) 1 nhiệm vụ AI.
  void dismissAiTask(String taskId) {
    final index = _aiTasks.indexWhere((t) => t.id == taskId);
    if (index < 0) return;
    _aiTasks[index] = _aiTasks[index].copyWith(isDismissed: true);
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
    _petService.gainExperience(_currentUserEmail, 20);
    
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
      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month}-${now.day}";
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
      }
      notifyListeners();
    } catch (e) {
      debugPrint('🚨 [HealthProvider] Lỗi khi load trạng thái: $e');
    }
  }

  Future<void> _checkDayChange() async {
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month}-${now.day}";
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
        notifyListeners();
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
}
