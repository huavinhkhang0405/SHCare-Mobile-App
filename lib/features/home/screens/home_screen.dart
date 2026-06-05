import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';

import '../../../core/providers/audio_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gif_icon.dart';
import '../providers/health_provider.dart';
import '../widgets/ai_pet_widget.dart';
import '../widgets/fantasy_environment.dart';
import '../widgets/home_sections.dart';

import '../../../models/pet_model.dart';
import '../../../services/pet/pet_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _petSectionKey = GlobalKey();
  bool _petTypingTriggered = false;
  final StringBuffer _typedTask = StringBuffer();
  Timer? _typingTimer;
  bool _isTyping = false;

  // --- THÊM CÁC BIẾN NÀY ĐỂ XỬ LÝ DỮ LIỆU PET GIẢ LẬP ---
  final PetService _petService = PetService();
  final String mockUserId = 'shcare_tester_001'; // User giả lập để test
  int _previousLevel = 1;
  String? _lastTask;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleScroll());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
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
                name: auth.userName,
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
              
              // =========================================================
              // KHU VỰC PET ĐÃ ĐƯỢC BỌC STREAM BUILDER
              // =========================================================
              StreamBuilder<PetModel>(
                stream: _petService.streamPetData(mockUserId),
                builder: (context, snapshot) {
                  // Khởi tạo pet mặc định nếu chưa có dữ liệu (Cấp 1, 0 EXP)
                  final pet = snapshot.data ?? PetModel(id: 'temp', userId: mockUserId);

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

                  final activeTasks = healthData.aiTasks.where((t) => !t.isCompleted && !t.isDismissed).toList();
                  final hasActiveAiTask = activeTasks.isNotEmpty;
                  final activeTask = hasActiveAiTask ? activeTasks.first : null;

                  final buttonText = activeTask != null
                      ? "Hoàn thành: ${activeTask.title} (+${activeTask.expReward} EXP)"
                      : "Hoàn thành nhiệm vụ (+20 EXP)";

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
                                  classType: 4,
                                  level: pet.level, 
                                  effect: isLevelUp 
                                      ? FantasyEnvironmentEffect.levelUp 
                                      : (healthData.showTaskCompletedEffect 
                                          ? FantasyEnvironmentEffect.taskCompleted 
                                          : FantasyEnvironmentEffect.none),
                                  petWidget: AIPetWidget(
                                    petState: animState,
                                    classType: 4,
                                    level: pet.level,
                                    isLevelUp: isLevelUp,
                                    userName: 'Khang', // Sau này đổi theo người dùng
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
                                  classType: 4,
                                  petMessage: pet.message.isNotEmpty ? pet.message : healthData.petMessage,
                                  typedTask: _petTypingTriggered
                                      ? (_isTyping
                                            ? '${_typedTask.toString()}|'
                                            : _typedTask.toString())
                                      : '',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // =========================================================
                      // NÚT HOÀN THÀNH NHIỆM VỤ DỰA TRÊN GỢI Ý
                      // =========================================================
                      if (!healthData.allTasksCompleted)
                        ElevatedButton.icon(
                          onPressed: () {
                            if (activeTask != null) {
                              healthData.completeAiTask(activeTask.id);
                            } else {
                              healthData.completeDailyTask();
                            }
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
}

class _PetDialogueCard extends StatelessWidget {
  final int classType;
  final String petMessage;
  final String typedTask;

  const _PetDialogueCard({
    required this.classType,
    required this.petMessage,
    required this.typedTask,
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
