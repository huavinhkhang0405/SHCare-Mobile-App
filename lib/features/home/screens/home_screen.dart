import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../../providers/auth_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:workmanager/workmanager.dart';

import '../../../core/providers/audio_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gif_icon.dart';
import '../providers/health_provider.dart';
import '../widgets/ai_pet_widget.dart';
import '../widgets/fantasy_environment.dart';
import '../widgets/home_sections.dart';
import '../../../core/widgets/rpg_permission_dialog.dart';
import '../widgets/sleep_confirmation_bottom_sheet.dart';
import '../widgets/share_preview_dialog.dart';

import '../../../models/pet_model.dart';
import '../../../models/task_suggestion.dart';
import '../../../services/screen_time_service.dart';
import '../../../services/pet/pet_service.dart';
import 'package:image_picker/image_picker.dart';
import '../../../utils/nutrition_analysis_limiter.dart';
import '../../../services/social/share_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _petSectionKey = GlobalKey();
  final GlobalKey _petRepaintKey = GlobalKey();
  bool _isSharing = false;
  bool _petTypingTriggered = false;
  final StringBuffer _typedTask = StringBuffer();
  Timer? _typingTimer;
  bool _isTyping = false;

  final PetService _petService = PetService();
  int _previousLevel = 1;
  String? _lastTask;

  int _remainingScans = 3;
  bool _isSleepSheetOpen = false;
  bool _isVerifyingTask = false;
  bool _isPurchasing = false;

  void _checkAndShowSleepConfirmation(HealthProvider healthData) {
    if (healthData.shouldShowSleepConfirmation && !_isSleepSheetOpen) {
      _isSleepSheetOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            isDismissible: false,
            enableDrag: false,
            builder: (context) => _SleepConfirmationBottomSheet(healthData: healthData),
          ).then((_) {
            _isSleepSheetOpen = false;
            if (healthData.shouldShowSleepConfirmation) {
              healthData.dismissSleepConfirmation();
            }
          });
        }
      });
    }
  }

  Future<void> _updateRemainingScans() async {
    final count = await NutritionAnalysisLimiter.getTodayScanCount();
    if (mounted) {
      setState(() {
        _remainingScans = (3 - count).clamp(0, 3);
      });
    }
  }

  void _showLimitReachedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFF111826),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFD7B56D), size: 28),
            SizedBox(width: 10),
            Text(
              'Hết lượt quét hôm nay',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Mỗi ngày bạn chỉ được quét tối đa 3 lần món ăn hoặc đồ uống để bảo toàn tài nguyên hệ thống. Hãy quay lại vào ngày mai nhé!',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Đồng ý',
              style: TextStyle(color: Color(0xFFD7B56D), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleScroll();
      _updateRemainingScans();
    });
    WidgetsBinding.instance.addObserver(this);
    
    context.read<HealthProvider>().startHeartRateSimulation();
    _requestNotificationPermissionAndRegisterWorkmanager();
  }

  Future<void> _requestNotificationPermissionAndRegisterWorkmanager() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    try {
      await Workmanager().registerPeriodicTask(
        'wellbeing-screentime-periodic-task',
        'wellbeing-screentime-check',
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
      debugPrint('✅ [WorkManager] Đăng ký periodic task thành công');
    } catch (e) {
      debugPrint('🚨 [WorkManager] Lỗi đăng ký periodic task: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _typingTimer?.cancel();
    context.read<HealthProvider>().stopHeartRateSimulation();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<HealthProvider>().checkScreenTimeLimit();
      context.read<HealthProvider>().checkSleepRecordOnAppOpen();
    }
  }

  void _handleScroll() {
    if (_petTypingTriggered) return;
    final context = _petSectionKey.currentContext;
    if (context == null) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenHeight = MediaQuery.of(context).size.height;
    final isVisible = offset.dy < screenHeight && offset.dy + size.height > 0;
    if (isVisible && !_petTypingTriggered) {
      setState(() => _petTypingTriggered = true);
      _startTyping(context);
    } else if (!isVisible && _petTypingTriggered) {
      _resetTyping();
      setState(() => _petTypingTriggered = false);
    }
  }

  void _showScreenTimeWarningDialog(BuildContext context, HealthProvider healthData) {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'ScreenTimeWarning',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (context, anim1, anim2) {
        return _ScreenTimeWarningDialog(healthData: healthData);
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curve,
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  void _showRpgPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0C121E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFD7B56D), width: 2),
        ),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Color(0xFFD7B56D), size: 26),
            SizedBox(width: 8),
            Text(
              'THỬ THÁCH RỜI MÀN HÌNH',
              style: TextStyle(
                color: Color(0xFFF4E2B6),
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🐉', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF162033),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD7B56D).withValues(alpha: 0.25)),
                    ),
                    child: const Text(
                      'Để kiểm chứng cậu có thực sự rời điện thoại, mình cần quyền xem dữ liệu dùng app hệ thống. Vui lòng cấp quyền giúp mình nhé!',
                      style: TextStyle(color: Colors.white, fontSize: 12, height: 1.4, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Hướng dẫn kích hoạt:\n1. Bấm nút "Đi đến Cài đặt" bên dưới.\n2. Chọn ứng dụng "SHCare" trong danh sách.\n3. Gạt bật công tắc "Cho phép truy cập dữ liệu sử dụng".',
              style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Để sau',
              style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ScreenTimeService.openUsageSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD7B56D),
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'Đi đến Cài đặt',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
  
  void _startTyping(BuildContext context) {
    final healthData = context.read<HealthProvider>();
    final task = healthData.petTask;
    if (task.isEmpty) return;
    _typingTimer?.cancel();
    _typedTask
      ..clear()
      ..write('');
    _isTyping = true;
    var index = 0;
    _typingTimer = Timer.periodic(const Duration(milliseconds: 36), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (index >= task.length) {
        _isTyping = false;
        timer.cancel();
        setState(() {});
        return;
      }
      _typedTask.write(task[index]);
      if (index % 2 == 0) {
        SystemSound.play(SystemSoundType.click);
      }
      index++;
      setState(() {});
    });
  }

  void _resetTyping() {
    _typingTimer?.cancel();
    _typedTask.clear();
    _isTyping = false;
  }

  @override
  Widget build(BuildContext context) {
    final healthData = context.watch<HealthProvider>();
    final auth = context.watch<AuthProvider>();
    
    _checkAndShowSleepConfirmation(healthData);

    if (healthData.isScreenTimeExceeded && !healthData.hasShownScreenTimeAlert) {
      healthData.markScreenTimeAlertAsShown();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showScreenTimeWarningDialog(context, healthData);
        }
      });
    }
    final currentTask = healthData.petTask;
    if (_lastTask != currentTask) {
      _lastTask = currentTask;
      if (_petTypingTriggered) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _startTyping(context);
        });
      }
    }

    final progress = (healthData.steps / healthData.goal).clamp(0.0, 1.0);
    final remainingSteps = (healthData.goal - healthData.steps).clamp(
      0,
      healthData.goal,
    );

    final cleanUserId = auth.currentUser?.id ?? firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeTopGreeting(
                name: auth.userName.isNotEmpty ? auth.userName : 'Khang',
                onProfileTap: () => _showProfileBottomSheet(context, auth),
              ),
              const SizedBox(height: 20),
              HomeDailySummaryCard(
                steps: healthData.steps,
                goal: healthData.goal,
                progress: progress,
                remainingSteps: remainingSteps,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: HomeQuickMetricCard(
                      icon: Icons.favorite_rounded,
                      gifAssetPath: AppGifIcons.heart,
                      title: 'Nhịp tim',
                      value: '${healthData.bpm} bpm',
                      subtitle: 'Ổn định',
                      color: AppColors.heartTint,
                      iconColor: AppColors.heartIcon,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: HomeQuickMetricCard(
                      icon: Icons.local_drink_rounded,
                      gifAssetPath: AppGifIcons.water,
                      title: 'Nước',
                      value: '${healthData.waterLiters} L',
                      subtitle: '${healthData.waterPercentage}% mục tiêu',
                      color: AppColors.waterTint,
                      iconColor: AppColors.waterIcon,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              HomeSleepHighlightCard(
                onTap: () async {
                  // Gọi BottomSheet và chờ kết quả trả về
                  final bool? isSaved = await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    isDismissible: false, // Ép không cho thoát ngang
                    enableDrag: false,
                    builder: (context) => _SleepConfirmationBottomSheet(healthData: healthData, isManualEdit: true),
                  );

                  // Nếu isSaved là true, hiển thị thông báo
                  if (isSaved == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 12),
                            Text(
                              'Đã cập nhật giấc ngủ thành công!',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        backgroundColor: const Color(0xFF162033), // Đồng nhất với màu nền Pet Panel
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFD7B56D), width: 1), // Viền vàng kim loại
                        ),
                        margin: const EdgeInsets.all(20),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              _buildNutritionScanCard(context, healthData),
              
              // =========================================================
              // KHU VỰC PET & NHIỆM VỤ ĐƯỢC GỘP CHUNG TRỰC TIẾP TRÊN HOME
              // =========================================================
              StreamBuilder<PetModel>(
                stream: _petService.streamPetData(cleanUserId),
                builder: (context, snapshot) {
                  final pet = snapshot.data ?? PetModel(id: 'temp', userId: cleanUserId);

                  bool isLevelUp = false;
                  if (pet.level > _previousLevel) {
                    isLevelUp = true;
                    _previousLevel = pet.level;
                  } else if (pet.level < _previousLevel) {
                    _previousLevel = pet.level;
                  }

                  String animState = 'idle';
                  if (pet.state == 'Mệt mỏi' || pet.state == 'Khát') animState = 'tired';
                  if (pet.state == 'Năng động' || pet.state == 'Vui vẻ') animState = 'happy';

                  final acceptedTasks = healthData.aiTasks.where((t) => t.isAccepted && !t.isCompleted).toList();
                  final acceptedTask = acceptedTasks.isNotEmpty ? acceptedTasks.first : null;
                  final pendingTasks = healthData.aiTasks.where((t) => !t.isAccepted && !t.isCompleted).toList();

                  return Container(
                    key: _petSectionKey,
                    margin: const EdgeInsets.symmetric(vertical: 24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111826),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFD7B56D), width: 2),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF162033), Color(0xFF0D1420)],
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 10,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: 0.08,
                              child: CustomPaint(painter: _RuneOverlayPainter()),
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            RepaintBoundary(
                              key: _petRepaintKey,
                              child: FantasyEnvironment(
                                classType: pet.classType,
                                level: pet.level, 
                                effect: isLevelUp 
                                    ? FantasyEnvironmentEffect.levelUp 
                                    : (healthData.showTaskCompletedEffect 
                                        ? FantasyEnvironmentEffect.taskCompleted 
                                        : FantasyEnvironmentEffect.none),
                                petWidget: AIPetWidget(
                                  petState: animState,
                                  classType: pet.classType,
                                  level: pet.level,
                                  isLevelUp: isLevelUp,
                                  userName: auth.userName.isNotEmpty ? auth.userName : 'Khang',
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Cấp ${pet.level}", 
                                  style: const TextStyle(color: Color(0xFFD7B56D), fontWeight: FontWeight.bold)
                                ),
                                Text(
                                  "${pet.currentExp} / ${pet.expToNextLevel} EXP", 
                                  style: const TextStyle(color: Colors.white70, fontSize: 12)
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: pet.expProgress,
                                minHeight: 8,
                                backgroundColor: Colors.black45,
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD7B56D)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Text("🔥", style: TextStyle(fontSize: 16)),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${pet.streakCount} ngày",
                                      style: const TextStyle(
                                        color: Color(0xFFFF8C00),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    const Text("❄️", style: TextStyle(fontSize: 16)),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${pet.streakFreezeCount} bùa",
                                      style: const TextStyle(
                                        color: Color(0xFF00BFFF),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    const Text("🪙", style: TextStyle(fontSize: 16)),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${pet.goldCoins} vàng",
                                      style: const TextStyle(
                                        color: Color(0xFFFFD700),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  height: 28,
                                  child: ElevatedButton.icon(
                                    onPressed: _isPurchasing
                                        ? null
                                        : () async {
                                            setState(() {
                                              _isPurchasing = true;
                                            });
                                            try {
                                              final success = await healthData.purchaseStreakFreeze();
                                              if (success && mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('🎉 Đã mua thành công 1 Bùa Đóng Băng! (-50 🪙)'),
                                                    backgroundColor: Colors.green,
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('🚨 ${e.toString().replaceAll('Exception: ', '')}'),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                            } finally {
                                              if (mounted) {
                                                setState(() {
                                                  _isPurchasing = false;
                                                });
                                              }
                                            }
                                          },
                                    icon: _isPurchasing
                                        ? const SizedBox(
                                            width: 10,
                                            height: 10,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 1.5,
                                              color: Colors.black54,
                                            ),
                                          )
                                        : const Icon(Icons.shopping_cart_rounded, size: 12, color: Colors.black87),
                                    label: const Text(
                                      "Mua bùa (50)",
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                       backgroundColor: const Color(0xFFD7B56D),
                                       padding: const EdgeInsets.symmetric(horizontal: 10),
                                       shape: RoundedRectangleBorder(
                                         borderRadius: BorderRadius.circular(20),
                                       ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            _PetDialogueCard(
                              classType: pet.classType,
                              petMessage: !healthData.hasOnboardedBedtime
                                  ? "Chào cậu! Để mình canh giấc ngủ cho cậu tốt nhất, bình thường cậu hay lên giường lúc mấy giờ nhỉ?"
                                  : (pet.message.isNotEmpty ? pet.message : healthData.petMessage),
                              typedTask: !healthData.hasOnboardedBedtime
                                  ? "Nhiệm vụ tân thủ: Thiết lập mục tiêu giấc ngủ"
                                  : (_petTypingTriggered
                                      ? (_isTyping
                                          ? '${_typedTask.toString()}|'
                                          : _typedTask.toString())
                                      : ''),
                              showRedDot: !healthData.hasOnboardedBedtime,
                            ),
                            
                            // ĐƯỜNG CHIA TÁCH TINH TẾ GỘP CHUNG TRUNG TÂM NHIỆM VỤ AI
                            const SizedBox(height: 16),
                            Divider(color: const Color(0xFFD7B56D).withOpacity(0.3), thickness: 1),
                            const SizedBox(height: 16),

                            if (!healthData.hasOnboardedBedtime)
                              _PetOnboardingBedtimePanel(healthData: healthData)
                            else if (healthData.allTasksCompleted)
                              Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A2740),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFD7B56D).withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.check_circle_rounded, color: Color(0xFFD7B56D), size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${healthData.completedTaskCount}/3 nhiệm vụ hoàn thành!',
                                          style: const TextStyle(
                                            color: Color(0xFFD7B56D),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _isSharing
                                          ? null
                                          : () async {
                                              setState(() => _isSharing = true);
                                              try {
                                                // 1. Chụp ảnh trước
                                                final imageBytes = await ShareService.captureWidgetAsImage(_petRepaintKey);
                                                if (!context.mounted) return;

                                                if (imageBytes == null) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Không thể tạo ảnh chia sẻ.'), backgroundColor: Colors.red),
                                                  );
                                                  return;
                                                }

                                                // 2. Hiển thị dialog xem trước
                                                bool confirmShare = false;
                                                await showDialog(
                                                  context: context,
                                                  barrierDismissible: false,
                                                  builder: (context) => SharePreviewDialog(
                                                    imageBytes: imageBytes,
                                                    onShare: () {
                                                      confirmShare = true;
                                                      Navigator.of(context).pop();
                                                    },
                                                    onCancel: () {
                                                      Navigator.of(context).pop();
                                                    },
                                                  ),
                                                );

                                                if (!confirmShare) return;

                                                // 3. Thực hiện chia sẻ
                                                await ShareService.shareAchievement(
                                                  pet: pet,
                                                  steps: healthData.steps,
                                                  completedTasks: healthData.completedTaskCount,
                                                  preCapturedImageBytes: imageBytes,
                                                );

                                                if (!context.mounted) return;

                                                final alreadyClaimed = await healthData.hasClaimedShareRewardToday();
                                                if (!alreadyClaimed) {
                                                  final rewarded = await healthData.claimShareReward();
                                                  if (rewarded && context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: const Text('🎉 Khoe thành tích thành công! Bạn nhận được +20 🪙'),
                                                        backgroundColor: Colors.green.shade700,
                                                      ),
                                                    );
                                                  }
                                                } else {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        content: Text('✅ Đã chia sẻ thành tích! (Bạn đã nhận thưởng chia sẻ của hôm nay rồi)'),
                                                        backgroundColor: Color(0xFF162033),
                                                      ),
                                                    );
                                                  }
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('🚨 Lỗi chia sẻ: ${e.toString().replaceAll('Exception: ', '')}'),
                                                      backgroundColor: Colors.red,
                                                    ),
                                                  );
                                                }
                                              } finally {
                                                if (mounted) setState(() => _isSharing = false);
                                              }
                                            },
                                      icon: _isSharing
                                          ? const SizedBox(
                                              width: 14, height: 14,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87),
                                            )
                                          : const Icon(Icons.share_rounded, size: 16),
                                      label: Text(
                                        _isSharing ? 'Đang chia sẻ...' : 'Khoe thành tích 📤',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFD7B56D),
                                        foregroundColor: Colors.black87,
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else if (acceptedTask != null) ...[
                              _ActiveTaskCard(
                                task: acceptedTask,
                                healthData: healthData,
                                isVerifyingTask: _isVerifyingTask,
                                onVerify: () async {
                                  if (acceptedTask.requiresImage) {
                                    final ImagePicker picker = ImagePicker();
                                    final XFile? photo = await picker.pickImage(
                                      source: ImageSource.camera,
                                      imageQuality: 50,
                                      maxWidth: 1024,
                                    );
                                    if (photo == null) return;

                                    setState(() {
                                      _isVerifyingTask = true;
                                    });

                                    try {
                                      final bytes = await photo.readAsBytes();
                                      final success = healthData.isGeminiConfigured
                                          ? await healthData.geminiService.verifyTaskWithImage(
                                              imageBytes: bytes,
                                              taskTitle: acceptedTask.title,
                                              taskDescription: acceptedTask.description,
                                            )
                                          : true;

                                      if (success) {
                                        await healthData.completeAiTask(acceptedTask.id);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('🎉 AI đã xác nhận hoàn thành: ${acceptedTask.title}! (+${acceptedTask.expReward} EXP)'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      } else {
                                        final isFruit = acceptedTask.title.toLowerCase().contains('trái cây') || 
                                                        acceptedTask.description.toLowerCase().contains('trái cây');
                                        final msg = isFruit 
                                            ? 'Chưa thấy trái cây đâu nha! Chụp lại rõ hơn đi nào! 🍎'
                                            : 'Chưa thấy bằng chứng nhiệm vụ đâu nha! Hãy chụp lại rõ ràng hơn đi nào! 📷';
                                        
                                        healthData.setPetMessage(msg, state: 'Mệt mỏi');
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(msg),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                        }
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('🚨 Lỗi xác thực hình ảnh: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(() {
                                          _isVerifyingTask = false;
                                        });
                                      }
                                    }
                                  } else {
                                    setState(() {
                                      _isVerifyingTask = true;
                                    });
                                    try {
                                      final isScreenFree = acceptedTask.type == 'sleep' || 
                                                           acceptedTask.title.toLowerCase().contains('rời màn hình') || 
                                                           acceptedTask.description.toLowerCase().contains('rời điện thoại');
                                      
                                      if (isScreenFree) {
                                        final hasPerm = await ScreenTimeService.checkUsagePermission();
                                        if (!hasPerm) {
                                          if (context.mounted) {
                                            _showRpgPermissionDialog(context);
                                          }
                                          return;
                                        }
                                        await healthData.verifyScreenFreeTask(acceptedTask.id);
                                      } else {
                                        await healthData.completeAiTask(acceptedTask.id);
                                      }

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('🎉 Đã hoàn thành nhiệm vụ: ${acceptedTask.title}! (+${acceptedTask.expReward} EXP)'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('🚨 ${e.toString().replaceAll('Exception: ', '')}'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(() {
                                          _isVerifyingTask = false;
                                        });
                                      }
                                    }
                                  }
                                },
                              ),
                            ] else ...[
                              _PendingTasksList(
                                tasks: pendingTasks,
                                onAccept: (task) async {
                                  try {
                                    final success = await healthData.acceptAiTask(task.id);
                                    if (success && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('⚔️ Đã nhận nhiệm vụ: ${task.title}. Bắt đầu rèn luyện!'),
                                          backgroundColor: Colors.blueAccent,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('🚨 ${e.toString().replaceAll('Exception: ', '')}'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                }
              ),

              const SizedBox(height: 20),
              const HomeSectionHeader(
                title: 'Lịch trình chăm sóc',
                actionLabel: 'Cả ngày',
              ),
              const SizedBox(height: 10),
              const HomePlanListCard(),
              const SizedBox(height: 20),
              const HomeSectionHeader(
                title: 'Hoạt động gần đây',
                actionLabel: 'Xem hết',
              ),
              const SizedBox(height: 10),
              const HomeRecentActivityCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNutritionScanCard(BuildContext context, HealthProvider healthData) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => _AiNutritionDiaryBottomSheet(
              healthData: healthData,
              remainingScans: _remainingScans,
              onScanPhoto: () async {
                Navigator.pop(context);
                
                final canScan = await NutritionAnalysisLimiter.canScanToday();
                if (!canScan) {
                  _showLimitReachedDialog();
                  return;
                }

                final ImagePicker picker = ImagePicker();
                final XFile? image = await picker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 1024,
                  maxHeight: 1024,
                  imageQuality: 85,
                );
                if (image != null) {
                  if (!context.mounted) return;
                  await Navigator.of(context).pushNamed(
                    '/nutrition_preview',
                    arguments: image.path,
                  );
                  _updateRemainingScans();
                }
              },
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: AppColors.softShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.fireTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const GifIcon(
                  assetPath: 'assets/gifs/fire.gif',
                  fallbackIcon: Icons.camera_alt_rounded,
                  fallbackColor: AppColors.fireIcon,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quét dinh dưỡng AI',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Đã nạp: ${healthData.caloriesConsumed} kcal · Còn $_remainingScans lượt quét',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textHint,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfileBottomSheet(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final currentEmail = auth.userEmail;
        final mockUsers = [
          {'email': 'admin@shcare.vn', 'name': 'Admin SHCare', 'avatar': '👑'},
          {'email': 'khang@shcare.vn', 'name': 'Huỳnh Vĩnh Khang', 'avatar': '👦'},
          {'email': 'test@shcare.vn', 'name': 'Tester SHCare', 'avatar': '🧪'},
          {'email': 'demo@shcare.vn', 'name': 'Demo User', 'avatar': '👤'},
        ];

        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Hồ sơ sức khỏe',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          auth.userName.isNotEmpty ? auth.userName[0].toUpperCase() : 'K',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.userName.isNotEmpty ? auth.userName : 'Huỳnh Vĩnh Khang',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              auth.userEmail.isNotEmpty ? auth.userEmail : 'khang@shcare.vn',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Hiện tại',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/profile');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_outline_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'Xem thông tin cá nhân',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: AppColors.textHint,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(color: AppColors.cardBorder),
                const SizedBox(height: 20),
                const Text(
                  'Chuyển hồ sơ người dùng',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: mockUsers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final u = mockUsers[index];
                      final isCurrent = u['email'] == currentEmail;
                      if (isCurrent) return const SizedBox.shrink();
                      
                      return InkWell(
                        onTap: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(context);
                          
                          navigator.pop();
                          
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const Center(
                              child: CircularProgressIndicator(color: AppColors.primary),
                            ),
                          );
                          
                          String pass = 'khang123';
                          if (u['email'] == 'admin@shcare.vn') pass = 'admin123';
                          if (u['email'] == 'test@shcare.vn') pass = 'test1234';
                          if (u['email'] == 'demo@shcare.vn') pass = 'demo1234';
                          
                          final success = await auth.loginWithEmail(u['email']!, pass);
                          
                          navigator.pop();
                          
                          if (success) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Đã chuyển đổi sang hồ sơ của ${u['name']}!'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Không thể chuyển đổi hồ sơ.'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.cardBorder),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Text(
                                u['avatar']!,
                                style: const TextStyle(fontSize: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      u['name']!,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      u['email']!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textHint,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.swap_horiz_rounded, color: AppColors.primary, size: 20),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(color: AppColors.cardBorder),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: AppColors.error),
                  title: const Text(
                    'Đăng xuất khỏi ứng dụng',
                    style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    auth.logout();
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                ),
              ],
            ),
          ),
        ),
      );
      },
    );
  }
}

class _PetDialogueCard extends StatelessWidget {
  final int classType;
  final String petMessage;
  final String typedTask;
  final bool showRedDot;

  const _PetDialogueCard({
    required this.classType,
    required this.petMessage,
    required this.typedTask,
    this.showRedDot = false,
  });

  static const Map<int, String> _classLabels = {
    1: 'Chiến binh',
    2: 'Cung thủ',
    3: 'Sát thủ',
    4: 'Pháp sư',
    5: 'Hiệp sĩ',
    6: 'Pháp sư gọi hồn',
    7: 'Cuồng chiến',
    8: 'Tu sĩ',
  };

  static const Map<int, String> _classSprites = {
    1: 'assets/images/sprites/sprite_r01_c01.png',
    2: 'assets/images/sprites/sprite_r02_c01.png',
    3: 'assets/images/sprites/sprite_r03_c01.png',
    4: 'assets/images/sprites/sprite_r04_c01.png',
    5: 'assets/images/sprites/sprite_r05_c01.png',
    6: 'assets/images/sprites/sprite_r06_c01.png',
    7: 'assets/images/sprites/sprite_r07_c01.png',
    8: 'assets/images/sprites/sprite_r08_c01.png',
  };

  static const Map<int, String> _classThoughts = {
    1: 'Nghe tiếng thép, cảm nhận lời thề.',
    2: 'Gió thì thầm phát bắn tiếp theo.',
    3: 'Bóng tối đồng hành cùng ta.',
    4: 'Ánh sáng huyền thuật tuân theo ý ta.',
    5: 'Danh dự là thanh kiếm bất diệt.',
    6: 'Linh hồn vong linh phục tùng ta.',
    7: 'Cơn cuồng nộ là sức mạnh vô biên.',
    8: 'Tĩnh tâm, vạn vật tự sáng tỏ.',
  };

  @override
  Widget build(BuildContext context) {
    final label = _classLabels[classType] ?? 'Pháp sư';
    final sprite = _classSprites[classType] ?? _classSprites[4]!;
    final thought = _classThoughts[classType] ?? _classThoughts[4]!;
    const borderColor = Color(0xFFD7B56D);
    const panelColor = Color(0xFF0C121E);
    const panelAccent = Color(0xFF152236);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF111A2A), panelColor],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(top: 0, left: 0, child: _PixelCorner(color: borderColor)),
          Positioned(
            top: 0,
            right: 0,
            child: _PixelCorner(color: borderColor, flipX: true),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: _PixelCorner(color: borderColor, flipY: true),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: _PixelCorner(color: borderColor, flipX: true, flipY: true),
          ),
          if (showRedDot)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent,
                      blurRadius: 4,
                      spreadRadius: 1,
                    )
                  ],
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: panelAccent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor, width: 2),
                    ),
                    child: Image.asset(
                      sprite,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: panelAccent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: borderColor, width: 1.5),
                    ),
                    child: Text(
                      label.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9,
                        letterSpacing: 0.8,
                        color: Color(0xFFF4E2B6),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tộc: $label',
                      style: const TextStyle(
                        color: Color(0xFFF4E2B6),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      thought,
                      style: const TextStyle(
                        color: Color(0xFFB6A27A),
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      petMessage,
                      style: const TextStyle(
                        color: Color(0xFFF5F1E6),
                        fontSize: 12,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E1A27),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor, width: 1.2),
                      ),
                      child: Text(
                        typedTask.isEmpty ? 'Quest: ' : 'Quest: $typedTask',
                        style: const TextStyle(
                          color: Color(0xFFE9D39B),
                          fontSize: 12,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PixelCorner extends StatelessWidget {
  final Color color;
  final bool flipX;
  final bool flipY;

  const _PixelCorner({
    required this.color,
    this.flipX = false,
    this.flipY = false,
  });

  @override
  Widget build(BuildContext context) {
    final matrix = Matrix4.identity()
      ..scale(flipX ? -1.0 : 1.0, flipY ? -1.0 : 1.0, 1.0);
    return Transform(
      alignment: Alignment.center,
      transform: matrix,
      child: SizedBox(
        width: 12,
        height: 12,
        child: CustomPaint(painter: _PixelCornerPainter(color)),
      ),
    );
  }
}

class _PixelCornerPainter extends CustomPainter {
  final Color color;

  const _PixelCornerPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const px = 2.0;
    canvas.drawRect(const Rect.fromLTWH(0, 0, px * 2, px), paint);
    canvas.drawRect(const Rect.fromLTWH(0, px, px, px), paint);
    canvas.drawRect(const Rect.fromLTWH(px, px, px, px), paint);
  }

  @override
  bool shouldRepaint(_PixelCornerPainter oldDelegate) => false;
}

class _RuneOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFB58C3D);
    final softPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFB58C3D).withOpacity(0.35);

    final center = Offset(size.width * 0.5, size.height * 0.35);
    final ringRadius = size.width * 0.28;
    canvas.drawCircle(center, ringRadius, softPaint);
    canvas.drawCircle(center, ringRadius * 0.82, softPaint);

    for (int i = 0; i < 12; i++) {
      final angle = (i / 12) * pi * 2;
      final r1 = ringRadius * 0.82;
      final r2 = ringRadius * 0.95;
      final p1 = Offset(center.dx + cos(angle) * r1, center.dy + sin(angle) * r1);
      final p2 = Offset(center.dx + cos(angle) * r2, center.dy + sin(angle) * r2);
      canvas.drawLine(p1, p2, paint);
    }

    final runeSize = size.width * 0.18;
    final runeRect = Rect.fromCenter(
      center: Offset(size.width * 0.2, size.height * 0.7),
      width: runeSize,
      height: runeSize,
    );
    final runeRect2 = Rect.fromCenter(
      center: Offset(size.width * 0.8, size.height * 0.68),
      width: runeSize * 0.8,
      height: runeSize * 0.8,
    );
    canvas.drawRect(runeRect, softPaint);
    canvas.drawLine(runeRect.topLeft, runeRect.bottomRight, softPaint);
    canvas.drawLine(runeRect.topRight, runeRect.bottomLeft, softPaint);
    canvas.drawRect(runeRect2, softPaint);
    canvas.drawLine(runeRect2.topLeft, runeRect2.bottomRight, softPaint);
  }

  @override
  bool shouldRepaint(_RuneOverlayPainter oldDelegate) => false;
}

class _ScreenTimeWarningDialog extends StatefulWidget {
  final HealthProvider healthData;

  const _ScreenTimeWarningDialog({required this.healthData});

  @override
  State<_ScreenTimeWarningDialog> createState() => _ScreenTimeWarningDialogState();
}

class _ScreenTimeWarningDialogState extends State<_ScreenTimeWarningDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0C121E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFD7B56D), width: 2),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5252).withOpacity(0.15),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5252).withOpacity(0.3),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFFF5252),
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'CẢNH BÁO SỨC KHỎE SỐ',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFFF4E2B6),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Bạn đã dành quá nhiều thời gian cho Game hoặc Mạng xã hội hôm nay!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.query_stats_rounded,
                      size: 14,
                      color: Color(0xFFD7B56D),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Chi tiết hôm nay:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFD7B56D).withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.healthData.screenTimeDetails.isNotEmpty
                      ? widget.healthData.screenTimeDetails
                      : 'Đang tổng hợp dữ liệu ứng dụng...',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB6A27A),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🐉', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF162033),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD7B56D).withOpacity(0.3)),
                  ),
                  child: const Text(
                    'Bạn nên rời màn hình điện thoại ngay. Đi dạo 15 phút hoặc nhắm mắt thư giãn 5 phút nhé!',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                SystemSound.play(SystemSoundType.click);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD7B56D),
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: const Text(
                'Đã hiểu & Sẽ chú ý',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiNutritionDiaryBottomSheet extends StatefulWidget {
  final HealthProvider healthData;
  final VoidCallback onScanPhoto;
  final int remainingScans;

  const _AiNutritionDiaryBottomSheet({
    required this.healthData,
    required this.onScanPhoto,
    required this.remainingScans,
  });

  @override
  State<_AiNutritionDiaryBottomSheet> createState() => _AiNutritionDiaryBottomSheetState();
}

class _AiNutritionDiaryBottomSheetState extends State<_AiNutritionDiaryBottomSheet> {
  final TextEditingController _textController = TextEditingController();
  bool _isLoading = false;
  String? _successMessage;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF111826),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFFD7B56D), size: 24),
                const SizedBox(width: 10),
                const Text(
                  'Nhật ký Dinh dưỡng AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF162033),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD7B56D).withOpacity(0.2)),
                  ),
                  child: Text(
                    'Còn ${widget.remainingScans} lượt',
                    style: const TextStyle(
                      color: Color(0xFFD7B56D),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Gõ bữa ăn của bạn hoặc chụp ảnh để Gemini phân tích dinh dưỡng và so sánh với mục tiêu calo của bạn.',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            if (_successMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20).withOpacity(0.15),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            TextField(
              controller: _textController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Sáng nay mình ăn 1 bánh mì ốp la và uống 1 ly đen đá...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                fillColor: const Color(0xFF162033),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : widget.onScanPhoto,
                      icon: const Icon(Icons.camera_alt_rounded, size: 18),
                      label: const Text('Chụp ảnh quét', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD7B56D),
                        side: const BorderSide(color: Color(0xFFD7B56D), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              final text = _textController.text.trim();
                              if (text.isEmpty) return;

                              setState(() {
                                _isLoading = true;
                                _successMessage = null;
                              });

                              final success = await widget.healthData.addMealRecord(text);

                              setState(() {
                                _isLoading = false;
                              });

                              if (success) {
                                final lastMeal = widget.healthData.todayFoods.isNotEmpty
                                    ? widget.healthData.todayFoods.last
                                    : 'món ăn';
                                setState(() {
                                  _successMessage = 'Đã phân tích thành công và cộng dồn dinh dưỡng của "$lastMeal"!';
                                  _textController.clear();
                                });
                                Future.delayed(const Duration(milliseconds: 1500), () {
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                });
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Vui lòng nhập đúng mô tả món ăn thực tế!'),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                            )
                          : const Icon(Icons.auto_awesome, size: 18, color: Colors.black),
                      label: Text(
                        _isLoading ? 'Đang phân tích...' : 'Phân tích chữ',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD7B56D),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepConfirmationBottomSheet extends StatefulWidget {
  final HealthProvider healthData;
  final bool isManualEdit;

  const _SleepConfirmationBottomSheet({required this.healthData, this.isManualEdit = false});

  @override
  State<_SleepConfirmationBottomSheet> createState() => _SleepConfirmationBottomSheetState();
}

class _SleepConfirmationBottomSheetState extends State<_SleepConfirmationBottomSheet> {
  late DateTime _start;
  late DateTime _wake;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.isManualEdit) {
      _start = widget.healthData.confirmedSleepStart ?? DateTime.now().subtract(const Duration(hours: 8));
      _wake = widget.healthData.confirmedSleepWake ?? DateTime.now();
    } else {
      _start = widget.healthData.sleepStartToConfirm ?? widget.healthData.confirmedSleepStart ?? DateTime.now().subtract(const Duration(hours: 8));
      _wake = widget.healthData.sleepWakeToConfirm ?? widget.healthData.confirmedSleepWake ?? DateTime.now();
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    return '${hours} tiếng ${minutes} phút';
  }

  Future<void> _selectStartTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
      helpText: 'Chọn giờ bắt đầu ngủ',
    );
    if (picked != null) {
      setState(() {
        final newStart = DateTime(_start.year, _start.month, _start.day, picked.hour, picked.minute);
        _start = widget.healthData.normalizeSleepTimes(newStart, _wake);
      });
    }
  }

  Future<void> _selectWakeTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_wake),
      helpText: 'Chọn giờ thức dậy',
    );
    if (picked != null) {
      setState(() {
        final newWake = DateTime(_wake.year, _wake.month, _wake.day, picked.hour, picked.minute);
        _wake = newWake;
        _start = widget.healthData.normalizeSleepTimes(_start, _wake);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = _wake.difference(_start);
    final durationLabel = _formatDuration(duration);

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF111826),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: const Color(0xFFD7B56D), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Row(
            children: [
              Icon(Icons.nights_stay_rounded, color: Color(0xFFD7B56D), size: 24),
              SizedBox(width: 8),
              Text(
                'Chào buổi sáng! 🌅',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFD7B56D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!_isEditing) ...[
            Text(
              'Đêm qua có vẻ bạn đã đặt điện thoại xuống lúc ${_formatTime(_start)} và thức dậy lúc ${_formatTime(_wake)}.',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bạn đã ngủ $durationLabel đúng không?',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
          ] else ...[
            const Text(
              'Chỉnh sửa thời gian giấc ngủ của bạn:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectStartTime(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFD7B56D).withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white.withOpacity(0.05),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Bắt đầu ngủ',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatTime(_start),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectWakeTime(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFD7B56D).withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white.withOpacity(0.05),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Thức dậy',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatTime(_wake),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Tổng thời gian ngủ: $durationLabel',
                style: const TextStyle(
                  color: Color(0xFFD7B56D),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    if (!_isEditing) {
                      setState(() {
                        _isEditing = true;
                      });
                    } else {
                      setState(() {
                        _isEditing = false;
                        _start = widget.healthData.sleepStartToConfirm ?? _start;
                        _wake = widget.healthData.sleepWakeToConfirm ?? _wake;
                      });
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD7B56D),
                    side: const BorderSide(color: Color(0xFFD7B56D)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(_isEditing ? 'Hủy' : 'Chỉnh sửa giờ'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    await widget.healthData.confirmSleep(_start, _wake);
                    if (context.mounted) {
                      Navigator.pop(context, true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD7B56D),
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Chính xác, lưu lại',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () {
                widget.healthData.dismissSleepConfirmation();
                Navigator.pop(context);
              },
              child: const Text(
                'Bỏ qua lần này',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PetOnboardingBedtimePanel extends StatefulWidget {
  final HealthProvider healthData;
  const _PetOnboardingBedtimePanel({required this.healthData});

  @override
  State<_PetOnboardingBedtimePanel> createState() => _PetOnboardingBedtimePanelState();
}

class _PetOnboardingBedtimePanelState extends State<_PetOnboardingBedtimePanel> {
  String _selectedTime = '22:30';
  bool _isSaving = false;

  final List<String> _times = [
    '21:00', '21:30', '22:00', '22:30', '23:00', '23:30', '00:00', '00:30', '01:00', '01:30', '02:00'
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111826),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD7B56D), width: 1.5),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF162033), Color(0xFF0C121E)],
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'QUEST TÂN THỦ • CHỌN GIỜ ĐI NGỦ',
                style: TextStyle(
                  color: Color(0xFFD7B56D),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _times.length,
              itemBuilder: (context, index) {
                final time = _times[index];
                final isSelected = _selectedTime == time;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTime = time;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFD7B56D) : const Color(0xFF1F2937).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.white : const Color(0xFF374151),
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFFD7B56D).withOpacity(0.4),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                    child: Text(
                      time,
                      style: TextStyle(
                        color: isSelected ? Colors.black87 : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveBedtime,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD7B56D),
                disabledBackgroundColor: const Color(0xFFD7B56D).withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.black87,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Xác nhận giờ đi ngủ 🎯',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveBedtime() async {
    setState(() => _isSaving = true);
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user != null) {
      final bedtimeParts = _selectedTime.split(':');
      final bedHour = int.parse(bedtimeParts[0]);
      final bedMin = int.parse(bedtimeParts[1]);
      final wakeHour = (bedHour + 8) % 24;
      final wakeTime = '${wakeHour.toString().padLeft(2, '0')}:${bedMin.toString().padLeft(2, '0')}';

      final success = await auth.updateProfile(
        name: user.name,
        birthYear: user.birthYear ?? 1995,
        gender: user.gender ?? 'Khác',
        heightCm: user.heightCm ?? 170.0,
        weightKg: user.weightKg ?? 65.0,
        targetBedtime: _selectedTime,
        targetWakeTime: wakeTime,
      );

      if (success && mounted) {
        await widget.healthData.setHasOnboardedBedtime(true);
        widget.healthData.completeDailyTaskOnboardingBedtime();
        unawaited(widget.healthData.fetchBedtimeOnboardingInsight(_selectedTime, wakeTime));
      }
    }
    if (mounted) {
      setState(() => _isSaving = false);
    }
  }
}

// =========================================================
// WIDGET ĐẾM NGƯỢC GIỜ VÀNG (FLASH QUEST)
// =========================================================
class _FlashQuestTimerWidget extends StatefulWidget {
  final DateTime expiresAt;
  final VoidCallback onExpired;

  const _FlashQuestTimerWidget({
    required this.expiresAt,
    required this.onExpired,
  });

  @override
  State<_FlashQuestTimerWidget> createState() => _FlashQuestTimerWidgetState();
}

class _FlashQuestTimerWidgetState extends State<_FlashQuestTimerWidget> {
  Timer? _timer;
  late Duration _timeLeft;

  @override
  void initState() {
    super.initState();
    _calculateTimeLeft();
    _startTimer();
  }

  void _calculateTimeLeft() {
    final now = DateTime.now();
    if (now.isAfter(widget.expiresAt)) {
      _timeLeft = Duration.zero;
    } else {
      _timeLeft = widget.expiresAt.difference(now);
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _calculateTimeLeft();
        if (_timeLeft == Duration.zero) {
          _timer?.cancel();
          widget.onExpired();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_timeLeft == Duration.zero) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_off_rounded, size: 12, color: Colors.white60),
            SizedBox(width: 4),
            Flexible(
              child: Text(
                "Đã hết giờ vàng (EXP thường)",
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final minutes = _timeLeft.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = _timeLeft.inSeconds.remainder(60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.redAccent.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department_rounded, size: 12, color: Colors.redAccent),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              "🔥 GIỜ VÀNG (x2 EXP/🪙): $minutes:$seconds",
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// WIDGET HIỂN THỊ NHIỆM VỤ ĐANG THỰC HIỆN (ACTIVE TASK)
// =========================================================
class _ActiveTaskCard extends StatefulWidget {
  final TaskSuggestion task;
  final HealthProvider healthData;
  final bool isVerifyingTask;
  final VoidCallback onVerify;

  const _ActiveTaskCard({
    required this.task,
    required this.healthData,
    required this.isVerifyingTask,
    required this.onVerify,
  });

  @override
  State<_ActiveTaskCard> createState() => _ActiveTaskCardState();
}

class _ActiveTaskCardState extends State<_ActiveTaskCard> {
  Timer? _countdownTimer;
  Duration _timeLeft = Duration.zero;
  bool _isScreenFree = false;

  @override
  void initState() {
    super.initState();
    _checkScreenFree();
    _startTimer();
  }

  @override
  void didUpdateWidget(_ActiveTaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.id != widget.task.id || oldWidget.task.acceptedAt != widget.task.acceptedAt) {
      _countdownTimer?.cancel();
      _checkScreenFree();
      _startTimer();
    }
  }

  void _checkScreenFree() {
    _isScreenFree = widget.task.type == 'sleep' || 
                    widget.task.title.toLowerCase().contains('rời màn hình') || 
                    widget.task.description.toLowerCase().contains('rời điện thoại');
  }

  void _startTimer() {
    final isTimeBased = ['rest', 'sleep', 'screen_free'].contains(widget.task.type);
    if ((!_isScreenFree && !isTimeBased) || widget.task.acceptedAt == null) return;

    // Ưu tiên requiredDuration từ model, fallback về công thức cũ nếu task cũ chưa có
    final Duration taskDuration = widget.task.requiredDuration > Duration.zero
        ? widget.task.requiredDuration
        : Duration(minutes: (widget.task.expReward == 20) ? 3 : ((widget.task.expReward == 30) ? 5 : 10));
    final endTime = widget.task.acceptedAt!.add(taskDuration);
    
    _calculateTimeLeft(endTime);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _calculateTimeLeft(endTime);
        if (_timeLeft == Duration.zero) {
          _countdownTimer?.cancel();
        }
      });
    });
  }

  void _calculateTimeLeft(DateTime endTime) {
    final now = DateTime.now();
    if (now.isAfter(endTime)) {
      _timeLeft = Duration.zero;
    } else {
      _timeLeft = endTime.difference(now);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  bool _isEligibleToComplete() {
    if (widget.task.requiresImage) return true;
    if (widget.task.type == 'exercise') {
      final currentSteps = widget.healthData.steps;
      final startSteps = widget.task.startSteps;
      final delta = (currentSteps - startSteps).clamp(0, 999999);
      final target = widget.task.targetSteps > 0 ? widget.task.targetSteps : (widget.task.expReward * 100);
      return delta >= target;
    }
    if (widget.task.type == 'water') {
      final currentWater = widget.healthData.waterLiters;
      final startWater = widget.task.startWater;
      final delta = (currentWater - startWater).clamp(0.0, 10.0);
      final target = (widget.task.expReward == 20) ? 0.25 : ((widget.task.expReward == 30) ? 0.5 : 1.0);
      return delta >= target;
    }
    if (_isScreenFree || ['rest', 'sleep', 'screen_free'].contains(widget.task.type)) {
      return _timeLeft == Duration.zero;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isFlash = widget.task.isFlashQuest;
    
    Widget? progressWidget;
    if (widget.task.type == 'exercise') {
      final currentSteps = widget.healthData.steps;
      final startSteps = widget.task.startSteps;
      final delta = (currentSteps - startSteps).clamp(0, 999999);
      // Ưu tiên targetSteps từ model, fallback về công thức cũ nếu task cũ chưa có
      final target = widget.task.targetSteps > 0 ? widget.task.targetSteps : (widget.task.expReward * 100);
      final percent = target > 0 ? (delta / target).clamp(0.0, 1.0) : 0.0;
      
      progressWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🏃‍♂️ Tiến trình: $delta / $target bước',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                '${(percent * 100).round()}%',
                style: const TextStyle(color: Color(0xFFD7B56D), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD7B56D)),
              minHeight: 6,
            ),
          ),
        ],
      );
    } else if (widget.task.type == 'water') {
      final currentWater = widget.healthData.waterLiters;
      final startWater = widget.task.startWater;
      final delta = (currentWater - startWater).clamp(0.0, 10.0);
      final target = (widget.task.expReward == 20) ? 0.25 : ((widget.task.expReward == 30) ? 0.5 : 1.0);
      final percent = (delta / target).clamp(0.0, 1.0);

      progressWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '💧 Tiến trình: ${(delta * 1000).round()}ml / ${(target * 1000).round()}ml',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                '${(percent * 100).round()}%',
                style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
              minHeight: 6,
            ),
          ),
        ],
      );
    } else if ((_isScreenFree || ['rest', 'sleep', 'screen_free'].contains(widget.task.type)) && _timeLeft > Duration.zero) {
      final minutes = _timeLeft.inMinutes.remainder(60).toString().padLeft(2, '0');
      final seconds = _timeLeft.inSeconds.remainder(60).toString().padLeft(2, '0');
      progressWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, color: Colors.purpleAccent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '⏳ Hãy cất điện thoại đi! Thời gian còn lại: $minutes:$seconds',
                    style: const TextStyle(color: Colors.purpleAccent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFlash ? const Color(0xFFD7B56D) : const Color(0xFF1F3254),
          width: isFlash ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      isFlash ? '🔥 THỬ THÁCH GIỜ VÀNG' : '⚔️ NHIỆM VỤ ĐANG LÀM',
                      style: TextStyle(
                        color: isFlash ? const Color(0xFFD7B56D) : Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    if (isFlash && widget.task.expiresAt != null)
                      _FlashQuestTimerWidget(
                        expiresAt: widget.task.expiresAt!,
                        onExpired: () {
                          if (mounted) setState(() {});
                        },
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD7B56D).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+${widget.task.expReward} EXP',
                  style: const TextStyle(color: Color(0xFFD7B56D), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.task.title,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            widget.task.description,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
          ),
          if (progressWidget != null) progressWidget,
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.isVerifyingTask
                      ? null
                      : () {
                          if (!_isEligibleToComplete()) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Nhiệm vụ chưa hoàn thành! Hãy thực hiện đủ yêu cầu trước khi xác nhận.'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }
                          widget.onVerify();
                        },
                  icon: widget.isVerifyingTask
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black87,
                          ),
                        )
                      : Icon(
                          widget.task.requiresImage ? Icons.camera_alt_rounded : Icons.check_circle_rounded,
                          size: 16,
                        ),
                  label: Text(
                    widget.isVerifyingTask
                        ? 'Đang xác thực...'
                        : widget.task.requiresImage
                            ? 'Chụp ảnh xác thực'
                            : 'Xác nhận hoàn thành',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isEligibleToComplete() ? const Color(0xFFD7B56D) : Colors.grey.withOpacity(0.4),
                    foregroundColor: _isEligibleToComplete() ? Colors.black87 : Colors.white54,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF0C121E),
                      title: const Text('Hủy nhiệm vụ', style: TextStyle(color: Colors.white)),
                      content: const Text('Bạn có chắc muốn hủy nhiệm vụ này không?', style: TextStyle(color: Colors.white70)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Không', style: TextStyle(color: Colors.white38)),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            widget.healthData.resetFailedTask(widget.task.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('🗑️ Đã hủy nhiệm vụ.'), backgroundColor: Colors.orange),
                            );
                          },
                          child: const Text('Hủy nhiệm vụ', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text(
                  'Hủy',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =========================================================
// WIDGET DANH SÁCH GỢI Ý NHIỆM VỤ (PENDING TASKS)
// =========================================================
class _PendingTasksList extends StatelessWidget {
  final List<TaskSuggestion> tasks;
  final Function(TaskSuggestion) onAccept;

  const _PendingTasksList({
    required this.tasks,
    required this.onAccept,
  });

  static const Map<String, IconData> _typeIcons = {
    'water': Icons.water_drop_rounded,
    'exercise': Icons.directions_walk_rounded,
    'rest': Icons.self_improvement_rounded,
    'sleep': Icons.bedtime_rounded,
    'general': Icons.auto_awesome_rounded,
  };

  static const Map<String, Color> _typeColors = {
    'water': AppColors.waterTint,
    'exercise': AppColors.primarySurface,
    'rest': AppColors.sleepTint,
    'sleep': AppColors.sleepTint,
    'general': AppColors.fireTint,
  };

  static const Map<String, Color> _typeIconColors = {
    'water': AppColors.waterIcon,
    'exercise': AppColors.primary,
    'rest': AppColors.sleepIcon,
    'sleep': AppColors.sleepIcon,
    'general': AppColors.fireIcon,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚔️ BẢNG NHIỆM VỤ AI',
              style: TextStyle(
                color: Color(0xFFF4E2B6),
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Chọn 1 trong 3 nhiệm vụ đề xuất từ huấn luyện viên AI để bắt đầu:',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (tasks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Đang tạo nhiệm vụ sức khỏe cá nhân hóa cho bạn...',
              style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              final isFlash = task.isFlashQuest;
              
              final icon = _typeIcons[task.type] ?? Icons.auto_awesome_rounded;
              final bgColor = _typeColors[task.type] ?? AppColors.fireTint;
              final iconColor = _typeIconColors[task.type] ?? AppColors.fireIcon;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isFlash ? const Color(0xFFD7B56D) : Colors.white12,
                    width: isFlash ? 1.5 : 1.0,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: bgColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: iconColor.withOpacity(0.4), width: 1.2),
                      ),
                      child: Icon(icon, color: iconColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  task.title,
                                  style: const TextStyle(
                                    color: Color(0xFFF4E2B6),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (isFlash) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                                  ),
                                  child: const Text(
                                    'GIỜ VÀNG',
                                    style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ],
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                                  ),
                                  borderRadius: BorderRadius.circular(99),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFFD700).withOpacity(0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, size: 12, color: Colors.white),
                                    const SizedBox(width: 2),
                                    Text(
                                      '+${task.expReward} EXP',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            task.description,
                            style: const TextStyle(color: Color(0xFFB6A27A), fontSize: 12, height: 1.4),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: iconColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(color: iconColor.withOpacity(0.3), width: 1.0),
                                ),
                                child: Text(
                                  task.category,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: iconColor,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => onAccept(task),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD7B56D),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFD7B56D).withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add_rounded, size: 14, color: Colors.black87),
                                      SizedBox(width: 4),
                                      Text(
                                        'Nhận thử thách',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
