import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/audio_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gif_icon.dart';
import '../../../utils/date_formatter.dart';
import '../../home/providers/health_provider.dart';
import '../widget/journal_sections.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  DateTime _now = DateFormatter.nowLocal();
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _now = DateFormatter.nowLocal();
      });
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final healthData = context.watch<HealthProvider>();
    final selectedSymptoms = healthData.selectedSymptoms;
    final dateLabel = DateFormatter.formatDayMonthWithWeekday(_now);
    final timeLabel = DateFormatter.formatHourMinute(_now);
    final dayPartLabel = DateFormatter.dayPartLabelVi(_now);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const JournalHeader(),
              const SizedBox(height: 16),
              JournalSectionHeader(
                title: 'Cảm xúc hôm nay',
                actionLabel: '$dateLabel · $timeLabel · $dayPartLabel',
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 102,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: kMoodOptions.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final mood = kMoodOptions[index];
                    final isSelected = index == healthData.moodIndex;
                    return GestureDetector(
                      onTap: () async {
                        final healthProvider = context.read<HealthProvider>();
                        final audioProvider = context.read<AudioProvider>();
                        final messenger = ScaffoldMessenger.of(context);

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
                                  ? 'Da kich hoat playlist giam cang thang: mua roi + piano cham.'
                                  : 'Da chuyen ve playlist thuong ngay theo tam trang hien tai.',
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
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? mood.color
                              : AppColors.cardBg,
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
                            const SizedBox(height: 8),
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
                onDecrease: () => context.read<HealthProvider>().removeWater(),
                onIncrease: () => context.read<HealthProvider>().addWater(),
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
                      maxLines: 4,
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
                        onPressed: () {},
                        icon: const GifIcon(
                          assetPath: AppGifIcons.save,
                          fallbackIcon: Icons.save_rounded,
                          fallbackColor: Colors.white,
                          size: 18,
                        ),
                        label: const Text('Lưu check-in hôm nay'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
      ),
    );
  }
}
