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

import '../../../models/pet_model.dart';
import '../../../services/pet/pet_service.dart';
import 'package:image_picker/image_picker.dart';
import '../../../utils/nutrition_analysis_limiter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _petSectionKey = GlobalKey();
  bool _petTypingTriggered = false;
  final StringBuffer _typedTask = StringBuffer();
  Timer? _typingTimer;
  bool _isTyping = false;

  // --- THÊM CÁC BIẾN NÀY ĐỂ XỬ LÝ DỮ LIỆU PET GIẢ LẬP ---
  final PetService _petService = PetService();
  int _previousLevel = 1;
  String? _lastTask;

  int _remainingScans = 3;
  bool _isSleepSheetOpen = false;

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
    
    // Xin quyền thông báo và đăng ký dịch vụ chạy ngầm
    _requestNotificationPermissionAndRegisterWorkmanager();
  }

  Future<void> _requestNotificationPermissionAndRegisterWorkmanager() async {
    // Xin quyền thông báo (bắt buộc từ Android 13+)
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    // Đăng ký tác vụ định kỳ kiểm tra thời lượng dùng màn hình (15 phút một lần)
    try {
      await Workmanager().registerPeriodicTask(
        'wellbeing-screentime-periodic-task', // uniqueName
        'wellbeing-screentime-check', // taskName
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
    // Kích hoạt âm thanh cảnh báo hệ thống và rung máy
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'ScreenTimeWarning',
      barrierColor: Colors.black.withValues(alpha: 0.75), // Nền mờ cực sâu
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
    
    // Kích hoạt BottomSheet xác nhận giờ ngủ khi người dùng thức dậy / mở app
    _checkAndShowSleepConfirmation(healthData);

    // Kiểm tra và hiển thị cảnh báo thời gian sử dụng màn hình nếu vượt ngưỡng mà chưa hiện
    if (healthData.isScreenTimeExceeded && !healthData.hasShownScreenTimeAlert) {
      // Đánh dấu đã hiện ngay lập tức để tránh rebuild chồng chéo Dialog
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
                  final audioProvider = context.read<AudioProvider>();
                  await audioProvider.activateSleepPlaylist();

                  if (!context.mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Đã kích hoạt chế độ ngủ: Brown noise / Solfeggio 432Hz.',
                      ),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildNutritionScanCard(context, healthData),
              
              // =========================================================
              // KHU VỰC PET ĐÃ ĐƯỢC BỌC STREAM BUILDER
              // =========================================================
              StreamBuilder<PetModel>(
                stream: _petService.streamPetData(cleanUserId),
                builder: (context, snapshot) {
                  // Khởi tạo pet mặc định nếu chưa có dữ liệu (Cấp 1, 0 EXP)
                  final pet = snapshot.data ?? PetModel(id: 'temp', userId: cleanUserId);

                  // Logic tính toán hiệu ứng lên cấp
                  bool isLevelUp = false;
                  if (pet.level > _previousLevel) {
                    isLevelUp = true;
                    _previousLevel = pet.level;
                  } else if (pet.level < _previousLevel) {
                    _previousLevel = pet.level;
                  }

                  // Chuyển đổi state cho AIPetWidget
                  String animState = 'idle';
                  if (pet.state == 'Mệt mỏi' || pet.state == 'Khát') animState = 'tired';
                  if (pet.state == 'Năng động' || pet.state == 'Vui vẻ') animState = 'happy';

                  final activeTasks = healthData.aiTasks.where((t) => !t.isCompleted).toList();
                  final hasActiveAiTask = activeTasks.isNotEmpty;
                  final activeTask = hasActiveAiTask ? activeTasks.first : null;

                  final buttonText = activeTask != null
                      ? "Hoàn thành: ${activeTask.title} (+${activeTask.expReward} EXP)"
                      : "Đã hoàn thành tất cả nhiệm vụ hôm nay! 🎉";

                  return Column(
                    children: [
                      Container(
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
                              children: [
                                FantasyEnvironment(
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
                                const SizedBox(height: 16),
                                
                                // HIỂN THỊ THANH KINH NGHIỆM
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
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // =========================================================
                      // NÚT HOÀN THÀNH NHIỆM VỤ DỰA TRÊN GỢI Ý AI
                      // =========================================================
                      if (!healthData.hasOnboardedBedtime)
                        _PetOnboardingBedtimePanel(healthData: healthData)
                      else if (!healthData.allTasksCompleted && activeTask != null)
                        ElevatedButton.icon(
                          onPressed: () {
                            healthData.completeAiTask(activeTask.id);
                          },
                          icon: const Icon(Icons.star, color: Colors.black87),
                          label: Text(
                            buttonText,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD7B56D),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        )
                      else if (healthData.allTasksCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A2740),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD7B56D).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
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
                    ],
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
                Navigator.pop(context); // Close bottom sheet
                
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
                  assetPath: AppGifIcons.fire,
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
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
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
                            color: AppColors.primary.withValues(alpha: 0.1),
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
                          
                          navigator.pop(); // Close BottomSheet
                          
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
                          
                          navigator.pop(); // Close loading dialog
                          
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
      ..color = const Color(0xFFB58C3D).withValues(alpha: 0.35);

    final center = Offset(size.width * 0.5, size.height * 0.35);
    final ringRadius = size.width * 0.28;
    canvas.drawCircle(center, ringRadius, softPaint);
    canvas.drawCircle(center, ringRadius * 0.82, softPaint);

    for (int i = 0; i < 12; i++) {
      final angle = (i / 12) * pi * 2;
      final r1 = ringRadius * 0.82;
      final r2 = ringRadius * 0.95;
      final p1 = Offset(
        center.dx + cos(angle) * r1,
        center.dy + sin(angle) * r1,
      );
      final p2 = Offset(
        center.dx + cos(angle) * r2,
        center.dy + sin(angle) * r2,
      );
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

// =========================================================
// HỘP THOẠI CẢNH BÁO THỜI GIAN SỬ DỤNG MÀN HÌNH - PHONG CÁCH RPG
// =========================================================
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
      backgroundColor: const Color(0xFF0C121E), // Nền tối RPG sang trọng
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFD7B56D), width: 2), // Viền vàng đồng
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon cảnh báo phát sáng đập nhẹ (Pulse animation)
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5252).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5252).withValues(alpha: 0.3),
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
          // Tiêu đề cảnh báo
          const Text(
            'CẢNH BÁO SỨC KHỎE SỐ',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFFF4E2B6), // Chữ vàng đồng sáng
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          // Nội dung cảnh báo
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
          
          // Khung hiển thị chi tiết thời gian sử dụng
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
                        color: const Color(0xFFD7B56D).withValues(alpha: 0.8),
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
          
          // Lời khuyên của Pet
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🐉',
                style: TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF162033),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD7B56D).withValues(alpha: 0.3)),
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
          
          // Nút đóng "Đã hiểu & Sẽ chú ý"
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                // Kích hoạt âm thanh click và đóng dialog
                SystemSound.play(SystemSoundType.click);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD7B56D), // Màu vàng đồng RPG
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
                    border: Border.all(color: const Color(0xFFD7B56D).withValues(alpha: 0.2)),
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
                  color: const Color(0xFF1B5E20).withValues(alpha: 0.15),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
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

// =========================================================
// HỘP THOẠI XÁC NHẬN GIẤC NGỦ CHỐNG GIAN LẬN
// =========================================================
class _SleepConfirmationBottomSheet extends StatefulWidget {
  final HealthProvider healthData;

  const _SleepConfirmationBottomSheet({required this.healthData});

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
    _start = widget.healthData.sleepStartToConfirm ?? DateTime.now().subtract(const Duration(hours: 8));
    _wake = widget.healthData.sleepWakeToConfirm ?? DateTime.now();
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
                      Navigator.pop(context);
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
