import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/audio_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gif_icon.dart';
import '../../../utils/date_formatter.dart';
import '../../../utils/nutrition_analysis_limiter.dart';
import 'package:image_picker/image_picker.dart';
import '../../home/providers/health_provider.dart';
import '../widget/journal_sections.dart';
import '../widget/journal_history_card.dart';
import '../widget/journal_stats_summary.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen>
    with SingleTickerProviderStateMixin {
  DateTime _now = DateFormatter.nowLocal();
  Timer? _clockTimer;
  late TabController _tabController;
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool _isSaving = false;
  bool _isNoteInitialized = false;
  String _searchQuery = '';
  int? _selectedMoodFilter;
  String? _selectedSymptomFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _now = DateFormatter.nowLocal();
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HealthProvider>().fetchDiaryHistory();
      final healthData = context.read<HealthProvider>();
      _noteController.text = healthData.todayNote;
      _isNoteInitialized = true;
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _tabController.dispose();
    _noteController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final healthData = context.watch<HealthProvider>();
    final selectedSymptoms = healthData.selectedSymptoms;
    final dateLabel = DateFormatter.formatDayMonthWithWeekday(_now);
    final timeLabel = DateFormatter.formatHourMinute(_now);
    final dayPartLabel = DateFormatter.dayPartLabelVi(_now);

    // Populate note text if not initialized yet
    if (!_isNoteInitialized && healthData.todayNote.isNotEmpty) {
      _noteController.text = healthData.todayNote;
      _isNoteInitialized = true;
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header cố định với TabBar bên dưới
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const JournalHeader(),
                  const SizedBox(height: 12),
                  TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.primary,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: const [
                      Tab(text: 'Check-in hôm nay'),
                      Tab(text: 'Lịch sử sức khỏe'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Check-in hôm nay
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        JournalSectionHeader(
                          title: 'Cảm xúc hôm nay',
                          actionLabel: '$dateLabel · $timeLabel · $dayPartLabel',
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 112,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: kMoodOptions.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final mood = kMoodOptions[index];
                              final isSelected = index == healthData.moodIndex;
                              return GestureDetector(
                                onTap: () async {
                                  final healthProvider =
                                      context.read<HealthProvider>();
                                  final audioProvider =
                                      context.read<AudioProvider>();
                                  final messenger =
                                      ScaffoldMessenger.of(context);

                                  healthProvider.setMoodIndex(index);
                                  await audioProvider.applyMoodPlaylist(index);

                                  if (!mounted) {
                                    return;
                                  }

                                  final isStress = index >= 3;
                                  messenger.clearSnackBars();
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isStress
                                            ? 'Đã kích hoạt playlist giảm căng thẳng: mưa rơi + piano chậm.'
                                            : 'Đã chuyển về playlist thường ngày theo tâm trạng hiện tại.',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOut,
                                  width: 96,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected ? mood.color : AppColors.cardBg,
                                    borderRadius: BorderRadius.circular(
                                      AppColors.radiusMd,
                                    ),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.cardBorder,
                                      width: isSelected ? 2.0 : 1.0,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.15),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        mood.emoji,
                                        style: const TextStyle(fontSize: 26),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        mood.label,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        JournalHydrationCard(
                          glasses: healthData.waterGlasses,
                          onDecrease: () =>
                              context.read<HealthProvider>().removeWater(),
                          onIncrease: () =>
                              context.read<HealthProvider>().addWater(),
                        ),
                        const SizedBox(height: 20),
                        JournalEnergyCard(
                          energyLevel: healthData.energyLevel,
                          onChanged: (value) =>
                              context.read<HealthProvider>().setEnergyLevel(value),
                          onChangeEnd: (value) async {
                            final healthProvider = context.read<HealthProvider>();
                            final audioProvider = context.read<AudioProvider>();
                            await audioProvider.applyMoodPlaylist(
                              healthProvider.moodIndex,
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        const JournalSectionHeader(
                          title: 'Triệu chứng nhẹ',
                          actionLabel: 'Có thể bỏ qua',
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            borderRadius: BorderRadius.circular(AppColors.radiusMd),
                            border: Border.all(color: AppColors.cardBorder),
                            boxShadow: AppColors.softShadow,
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: kSymptomOptions
                                .map(
                                  (symptom) => FilterChip(
                                    selected: selectedSymptoms.contains(symptom),
                                    label: Text(symptom),
                                    selectedColor: AppColors.primarySurface,
                                    labelStyle: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: selectedSymptoms.contains(symptom)
                                          ? AppColors.primaryDark
                                          : AppColors.textSecondary,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    side: BorderSide(
                                      color: selectedSymptoms.contains(symptom)
                                          ? AppColors.primary
                                          : AppColors.cardBorder,
                                    ),
                                    onSelected: (selected) => context
                                        .read<HealthProvider>()
                                        .toggleSymptom(symptom, selected),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const JournalSectionHeader(
                          title: 'Nhật ký Dinh dưỡng AI',
                          actionLabel: 'Ước lượng bởi Gemini',
                        ),
                        const SizedBox(height: 10),
                        const _JournalNutritionCard(),
                        const SizedBox(height: 20),
                        const JournalSectionHeader(
                          title: 'Ghi chú nhanh',
                          actionLabel: 'Tự do',
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            borderRadius: BorderRadius.circular(AppColors.radiusMd),
                            border: Border.all(color: AppColors.cardBorder),
                            boxShadow: AppColors.softShadow,
                          ),
                          child: Column(
                            children: [
                              TextField(
                                controller: _noteController,
                                maxLines: 4,
                                onChanged: (value) {
                                  context.read<HealthProvider>().setTodayNote(value);
                                },
                                decoration: InputDecoration(
                                  hintText:
                                      'Ghi lại cảm nhận, mục tiêu hoặc điều cần cải thiện trong ngày...',
                                  hintStyle: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textHint,
                                  ),
                                  fillColor: AppColors.scaffoldBg,
                                  filled: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                  child: FilledButton.icon(
                                  onPressed: _isSaving
                                      ? null
                                      : () async {
                                          final messenger = ScaffoldMessenger.of(context);
                                          final healthProvider = context.read<HealthProvider>();

                                          setState(() {
                                            _isSaving = true;
                                          });

                                          final success = await healthProvider.saveCurrentDiaryEntry(
                                            _noteController.text,
                                          );

                                          if (!context.mounted) return;

                                          setState(() {
                                            _isSaving = false;
                                          });

                                          if (success) {
                                            messenger.showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Đã lưu nhật ký sức khỏe hôm nay thành công! 🎉',
                                                ),
                                                backgroundColor: Colors.green,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                              ),
                                            );
                                            // Tải lại lịch sử và chuyển sang tab Lịch sử
                                            await healthProvider.fetchDiaryHistory();
                                            if (context.mounted) {
                                              _tabController.animateTo(1);
                                            }
                                          } else {
                                            messenger.showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Lưu nhật ký thất bại. Vui lòng thử lại!',
                                                ),
                                                backgroundColor: Colors.red,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                              ),
                                            );
                                          }
                                        },
                                  icon: _isSaving
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const GifIcon(
                                          assetPath: AppGifIcons.save,
                                          fallbackIcon: Icons.save_rounded,
                                          fallbackColor: Colors.white,
                                          size: 18,
                                        ),
                                  label: Text(
                                    _isSaving
                                        ? 'Đang lưu...'
                                        : 'Lưu check-in hôm nay',
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppColors.radiusMd,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tab 2: Lịch sử sức khỏe
                  _buildHistoryTab(healthData),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab(HealthProvider healthData) {
    if (healthData.isLoadingHistory) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final history = healthData.diaryHistory;

    if (history.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => healthData.fetchDiaryHistory(),
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.book_outlined,
                  size: 72,
                  color: AppColors.textHint.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Chưa có nhật ký nào',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hãy hoàn thành check-in hôm nay để bắt đầu theo dõi hành trình sức khỏe của bạn.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    _tabController.animateTo(0);
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Tạo check-in ngay'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Lọc dữ liệu nhật ký
    final filteredHistory = history.where((entry) {
      // 1. Tìm kiếm query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesNote = entry.note?.toLowerCase().contains(query) ?? false;
        final matchesFood =
            entry.todayFoods.any((f) => f.toLowerCase().contains(query));
        if (!matchesNote && !matchesFood) return false;
      }

      // 2. Lọc theo tâm trạng
      if (_selectedMoodFilter != null && entry.moodIndex != _selectedMoodFilter) {
        return false;
      }

      // 3. Lọc theo triệu chứng
      if (_selectedSymptomFilter != null) {
        if (!entry.symptoms.contains(_selectedSymptomFilter)) {
          return false;
        }
      }

      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: () => healthData.fetchDiaryHistory(),
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          // Thống kê tổng quan
          JournalStatsSummary(history: history),
          const SizedBox(height: 20),

          // Thanh tìm kiếm
          TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim();
              });
            },
            decoration: InputDecoration(
              hintText: 'Tìm ghi chú, món ăn...',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.textHint),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                          _searchController.clear();
                        });
                      },
                    )
                  : null,
              fillColor: AppColors.cardBg,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Lọc nhanh Tâm trạng
          const Text(
            'Lọc theo tâm trạng:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip(
                  label: 'Tất cả',
                  isSelected: _selectedMoodFilter == null,
                  onSelected: (_) {
                    setState(() {
                      _selectedMoodFilter = null;
                    });
                  },
                ),
                ...List.generate(kMoodOptions.length, (index) {
                  final mood = kMoodOptions[index];
                  return _buildFilterChip(
                    label: '${mood.emoji} ${mood.label}',
                    isSelected: _selectedMoodFilter == index,
                    onSelected: (_) {
                      setState(() {
                        _selectedMoodFilter = index;
                      });
                    },
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Lọc nhanh Triệu chứng
          const Text(
            'Lọc theo triệu chứng:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip(
                  label: 'Tất cả',
                  isSelected: _selectedSymptomFilter == null,
                  onSelected: (_) {
                    setState(() {
                      _selectedSymptomFilter = null;
                    });
                  },
                ),
                ...kSymptomOptions.where((s) => s != 'Không có').map((symptom) {
                  return _buildFilterChip(
                    label: symptom,
                    isSelected: _selectedSymptomFilter == symptom,
                    onSelected: (_) {
                      setState(() {
                        _selectedSymptomFilter = symptom;
                      });
                    },
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Header danh sách các ngày
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lịch sử đã lưu (${filteredHistory.length})',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (_searchQuery.isNotEmpty ||
                  _selectedMoodFilter != null ||
                  _selectedSymptomFilter != null)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _searchController.clear();
                      _selectedMoodFilter = null;
                      _selectedSymptomFilter = null;
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Xóa lọc',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Thẻ nhật ký
          if (filteredHistory.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: const Column(
                children: [
                  Icon(Icons.search_off_rounded, size: 48, color: AppColors.textHint),
                  SizedBox(height: 12),
                  Text(
                    'Không tìm thấy nhật ký phù hợp',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredHistory.length,
              itemBuilder: (context, index) {
                final entry = filteredHistory[index];
                return JournalHistoryCard(
                  entry: entry,
                  onDelete: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final success =
                        await healthData.deleteDiaryEntry(entry.id);
                    if (success) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Đã xóa nhật ký thành công!'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Xóa nhật ký thất bại. Vui lòng thử lại!'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required ValueChanged<bool> onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        selectedColor: AppColors.primarySurface,
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.cardBorder,
        ),
        onSelected: onSelected,
      ),
    );
  }
}

// =========================================================
// AI NUTRITION JOURNAL CARD WIDGET
// =========================================================
class _JournalNutritionCard extends StatefulWidget {
  const _JournalNutritionCard();

  @override
  State<_JournalNutritionCard> createState() => _JournalNutritionCardState();
}

class _JournalNutritionCardState extends State<_JournalNutritionCard> {
  final TextEditingController _mealController = TextEditingController();

  @override
  void dispose() {
    _mealController.dispose();
    super.dispose();
  }

  void _showLimitReachedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFF111826),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Color(0xFFD7B56D), size: 28),
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
              style: TextStyle(
                  color: Color(0xFFD7B56D), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final healthData = context.watch<HealthProvider>();
    final calProgress = (healthData.consumedCalories /
            healthData.targetCalories.toDouble())
        .clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chỉ số Calories
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Calories đã nạp',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${healthData.consumedCalories} / ${healthData.targetCalories} kcal',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: calProgress,
              minHeight: 10,
              backgroundColor: AppColors.scaffoldBg,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),
          // Chỉ số các chất dinh dưỡng vi lượng (Protein, Carbs, Fat)
          Row(
            children: [
              Expanded(
                child: _buildMacroColumn(
                  label: 'Protein (Đạm)',
                  value: '${healthData.consumedProtein} g',
                  color: Colors.orangeAccent,
                ),
              ),
              Container(width: 1, height: 28, color: AppColors.cardBorder),
              Expanded(
                child: _buildMacroColumn(
                  label: 'Carbs (Đường)',
                  value: '${healthData.consumedCarbs} g',
                  color: Colors.lightBlueAccent,
                ),
              ),
              Container(width: 1, height: 28, color: AppColors.cardBorder),
              Expanded(
                child: _buildMacroColumn(
                  label: 'Fat (Béo)',
                  value: '${healthData.consumedFat} g',
                  color: Colors.pinkAccent,
                ),
              ),
            ],
          ),

          // Lịch sử các món ăn đã nhập
          if (healthData.todayFoods.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Các món ăn đã nạp hôm nay:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: healthData.todayFoods
                  .map((food) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color:
                              AppColors.primarySurface.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              width: 1.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.restaurant_menu_rounded,
                                size: 11, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              food,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ],

          const SizedBox(height: 20),
          const Divider(color: AppColors.cardBorder, height: 1),
          const SizedBox(height: 16),

          // Nhập món ăn bằng AI
          TextField(
            controller: _mealController,
            maxLines: 2,
            enabled: !healthData.isLoadingAI,
            decoration: InputDecoration(
              hintText:
                  'Nhập món ăn (ví dụ: Trưa nay mình ăn 1 dĩa cơm sườn bì chả và 1 ly trà đá)...',
              hintStyle: const TextStyle(
                fontSize: 12,
                color: AppColors.textHint,
              ),
              fillColor: AppColors.scaffoldBg,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: healthData.isLoadingAI
                      ? null
                      : () async {
                          final text = _mealController.text.trim();
                          if (text.isEmpty) return;

                          final provider = context.read<HealthProvider>();
                          final messenger = ScaffoldMessenger.of(context);
                          final success = await provider.addMealRecord(text);
                          if (!mounted) return;

                          if (success) {
                            _mealController.clear();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Đã phân tích thành công và cộng dồn dinh dưỡng!'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Vui lòng nhập đúng tên món ăn / thức uống thực tế!'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                  icon: healthData.isLoadingAI
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome, size: 14),
                  label: Text(
                    healthData.isLoadingAI
                        ? 'Đang phân tích...'
                        : 'Phân tích chữ',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    final canScan =
                        await NutritionAnalysisLimiter.canScanToday();
                    if (!canScan) {
                      if (context.mounted) {
                        _showLimitReachedDialog(context);
                      }
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
                    }
                  },
                  icon: const Icon(Icons.camera_alt_rounded, size: 14),
                  label: const Text(
                    'Chụp ảnh quét',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroColumn({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textHint,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}
