import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/audio_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gif_icon.dart';
import '../../home/screens/home_screen.dart';
import '../../home/widgets/music_play_button.dart';
import '../../stats/screens/stats_screen.dart';
import '../../tips/screens/tips_screen.dart';
import '../../home/providers/health_provider.dart';
import '../../journal/screens/journal_screen.dart';
import '../../social/screens/social_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const double _musicButtonSize = 48;
  static const double _musicButtonMargin = 12;
  static const String _musicButtonXRatioKey = 'music_button_x_ratio';
  static const String _musicButtonYRatioKey = 'music_button_y_ratio';

  double _musicButtonXRatio = 0.02;
  double _musicButtonYRatio = 0.15;

  @override
  void initState() {
    super.initState();
    _restoreMusicButtonPosition();

    // Gọi sau khi frame đầu tiên được vẽ để tránh xung đột Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<AudioProvider>().startBgm();
    });
  }

  // Biến lưu trữ vị trí tab hiện tại đang được chọn (mặc định là 0 - Trang chủ)
  int _currentIndex = 0;

  // Danh sách các màn hình tương ứng với từng tab
  final List<Widget> _screens = [
    const HomeScreen(),
    const StatsScreen(),
    const TipsScreen(),
    const JournalScreen(),
    const SocialScreen(),
  ];

  Future<void> _restoreMusicButtonPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final savedXRatio = prefs.getDouble(_musicButtonXRatioKey);
    final savedYRatio = prefs.getDouble(_musicButtonYRatioKey);

    if (!mounted || savedXRatio == null || savedYRatio == null) {
      return;
    }

    setState(() {
      _musicButtonXRatio = savedXRatio.clamp(0.0, 1.0).toDouble();
      _musicButtonYRatio = savedYRatio.clamp(0.0, 1.0).toDouble();
    });
  }

  Future<void> _saveMusicButtonPosition() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_musicButtonXRatioKey, _musicButtonXRatio);
    await prefs.setDouble(_musicButtonYRatioKey, _musicButtonYRatio);
  }

  double _positionFromRatio({
    required double ratio,
    required double min,
    required double max,
  }) {
    if (max <= min) {
      return min;
    }

    return min + ((max - min) * ratio.clamp(0.0, 1.0));
  }

  double _ratioFromPosition({
    required double position,
    required double min,
    required double max,
  }) {
    if (max <= min) {
      return 0;
    }

    return ((position - min) / (max - min)).clamp(0.0, 1.0).toDouble();
  }

  void _onMusicButtonPanUpdate({
    required DragUpdateDetails details,
    required double minLeft,
    required double maxLeft,
    required double minTop,
    required double maxTop,
  }) {
    final currentLeft = _positionFromRatio(
      ratio: _musicButtonXRatio,
      min: minLeft,
      max: maxLeft,
    );
    final currentTop = _positionFromRatio(
      ratio: _musicButtonYRatio,
      min: minTop,
      max: maxTop,
    );

    final nextLeft = (currentLeft + details.delta.dx)
        .clamp(minLeft, maxLeft)
        .toDouble();
    final nextTop = (currentTop + details.delta.dy)
        .clamp(minTop, maxTop)
        .toDouble();

    setState(() {
      _musicButtonXRatio = _ratioFromPosition(
        position: nextLeft,
        min: minLeft,
        max: maxLeft,
      );
      _musicButtonYRatio = _ratioFromPosition(
        position: nextTop,
        min: minTop,
        max: maxTop,
      );
    });
  }

  void _onMusicButtonPanEnd({
    required double minLeft,
    required double maxLeft,
    required double minTop,
    required double maxTop,
  }) {
    final currentLeft = _positionFromRatio(
      ratio: _musicButtonXRatio,
      min: minLeft,
      max: maxLeft,
    );
    final currentTop = _positionFromRatio(
      ratio: _musicButtonYRatio,
      min: minTop,
      max: maxTop,
    );

    _musicButtonXRatio = _ratioFromPosition(
      position: currentLeft,
      min: minLeft,
      max: maxLeft,
    );
    _musicButtonYRatio = _ratioFromPosition(
      position: currentTop,
      min: minTop,
      max: maxTop,
    );
    _saveMusicButtonPosition();
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe tín hiệu chọc ghẹo từ bạn bè realtime
    final healthProvider = context.watch<HealthProvider>();
    final pokeMessage = healthProvider.latestPokeMessage;
    if (pokeMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (healthProvider.latestPokeMessage != null) {
          _showPokeAlert(context, healthProvider.latestPokeMessage!);
          healthProvider.clearLatestPokeMessage();
        }
      });
    }

    return Scaffold(
      // 1. Phần thân sẽ hiển thị màn hình dựa theo index hiện tại
      body: LayoutBuilder(
        builder: (context, constraints) {
          final topPadding = MediaQuery.of(context).viewPadding.top;
          final minLeft = _musicButtonMargin;
          final minTop = topPadding + _musicButtonMargin;
          final maxLeftRaw =
              constraints.maxWidth - _musicButtonSize - _musicButtonMargin;
          final maxTopRaw =
              constraints.maxHeight - _musicButtonSize - _musicButtonMargin;
          final maxLeft = maxLeftRaw >= minLeft ? maxLeftRaw : minLeft;
          final maxTop = maxTopRaw >= minTop ? maxTopRaw : minTop;

          final clampedLeft = _positionFromRatio(
            ratio: _musicButtonXRatio,
            min: minLeft,
            max: maxLeft,
          );
          final clampedTop = _positionFromRatio(
            ratio: _musicButtonYRatio,
            min: minTop,
            max: maxTop,
          );

          return Stack(
            children: [
              Positioned.fill(
                child: IndexedStack(index: _currentIndex, children: _screens),
              ),
              Positioned(
                left: clampedLeft,
                top: clampedTop,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanUpdate: (details) => _onMusicButtonPanUpdate(
                    details: details,
                    minLeft: minLeft,
                    maxLeft: maxLeft,
                    minTop: minTop,
                    maxTop: maxTop,
                  ),
                  onPanEnd: (_) => _onMusicButtonPanEnd(
                    minLeft: minLeft,
                    maxLeft: maxLeft,
                    minTop: minTop,
                    maxTop: maxTop,
                  ),
                  child: const MusicPlayButton(),
                ),
              ),
            ],
          );
        },
      ),

      // 2. Thanh điều hướng dưới cùng (Sử dụng NavigationBar của Material 3)
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        // Sử dụng ClipRRect để bo góc thanh điều hướng giống thiết kế HTML (rounded-t-[3rem])
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (int index) {
              // Khi người dùng bấm tab khác, cập nhật lại index và vẽ lại giao diện
              setState(() {
                _currentIndex = index;
              });
            },
            // Tắt background mặc định để sử dụng màu cấu hình trong Theme
            backgroundColor: Theme.of(
              context,
            ).navigationBarTheme.backgroundColor,
            destinations: const [
              NavigationDestination(
                icon: GifIcon(
                  assetPath: AppGifIcons.home,
                  fallbackIcon: Icons.grid_view_outlined,
                ),
                selectedIcon: GifIcon(
                  assetPath: AppGifIcons.home,
                  fallbackIcon: Icons.grid_view,
                ),
                label: 'Trang chủ',
              ),
              NavigationDestination(
                icon: GifIcon(
                  assetPath: AppGifIcons.stats,
                  fallbackIcon: Icons.bar_chart_outlined,
                ),
                selectedIcon: GifIcon(
                  assetPath: AppGifIcons.stats,
                  fallbackIcon: Icons.bar_chart,
                ),
                label: 'Thống kê',
              ),
              NavigationDestination(
                icon: GifIcon(
                  assetPath: AppGifIcons.tips,
                  fallbackIcon: Icons.auto_awesome_outlined,
                ),
                selectedIcon: GifIcon(
                  assetPath: AppGifIcons.tips,
                  fallbackIcon: Icons.auto_awesome,
                ),
                label: 'Gợi ý',
              ),
              NavigationDestination(
                icon: GifIcon(
                  assetPath: AppGifIcons.journal,
                  fallbackIcon: Icons.description_outlined,
                ),
                selectedIcon: GifIcon(
                  assetPath: AppGifIcons.journal,
                  fallbackIcon: Icons.description,
                ),
                label: 'Nhật ký',
              ),
              NavigationDestination(
                icon: GifIcon(
                  assetPath: AppGifIcons.profile,
                  fallbackIcon: Icons.group_outlined,
                ),
                selectedIcon: GifIcon(
                  assetPath: AppGifIcons.profile,
                  fallbackIcon: Icons.group,
                ),
                label: 'Cộng đồng',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPokeAlert(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon chọc
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: AppColors.primarySurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.front_hand_rounded,
                    color: AppColors.primary,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Bị chọc ghẹo! 😂',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Tập luyện thôi! 🔥',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
