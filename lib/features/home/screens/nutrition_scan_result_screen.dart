import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/nutrition_analysis_result.dart';
import '../../../utils/nutrition_analysis_limiter.dart';
import '../providers/health_provider.dart';

class NutritionScanResultScreen extends StatelessWidget {
  const NutritionScanResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Nhận tham số truyền qua từ màn hình Preview
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final result = args['result'] as NutritionAnalysisResult;
    final imagePath = args['imagePath'] as String;

    final totalMacros = result.carbsG + result.proteinG + result.fatG;
    final double carbsPercent = totalMacros > 0 ? (result.carbsG / totalMacros) : 0.0;
    final double proteinPercent = totalMacros > 0 ? (result.proteinG / totalMacros) : 0.0;
    final double fatPercent = totalMacros > 0 ? (result.fatG / totalMacros) : 0.0;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text(
          'Kết quả phân tích AI',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const SizedBox.shrink(), // Vô hiệu hóa nút back để tránh bấm nhầm mà chưa lưu
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thông tin cơ bản về món ăn
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.cardBorder),
                  boxShadow: AppColors.softShadow,
                ),
                child: Row(
                  children: [
                    // Ảnh thumbnail
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          File(imagePath),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: result.type == 'drink'
                                  ? AppColors.waterTint
                                  : AppColors.fireTint,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              result.type == 'drink' ? 'ĐỒ UỐNG' : 'MÓN ĂN',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: result.type == 'drink'
                                    ? AppColors.waterIcon
                                    : AppColors.fireIcon,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            result.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Độ tin cậy: ${result.confidencePercentage}%',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Card hiển thị lượng Calo nổi bật
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'LƯỢNG CALO ƯỚC TÍNH',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white70,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${result.calories} kcal',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Phân tích dinh dưỡng đa lượng (Macronutrients)
              const Text(
                'Thành phần dinh dưỡng',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.cardBorder),
                  boxShadow: AppColors.softShadow,
                ),
                child: Column(
                  children: [
                    // Carbs progress bar
                    _buildMacroRow(
                      label: 'Carbohydrates (Đường/Bột)',
                      value: '${result.carbsG.toStringAsFixed(1)}g',
                      percentage: carbsPercent,
                      color: AppColors.accent,
                    ),
                    const SizedBox(height: 16),
                    // Protein progress bar
                    _buildMacroRow(
                      label: 'Protein (Đạm)',
                      value: '${result.proteinG.toStringAsFixed(1)}g',
                      percentage: proteinPercent,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 16),
                    // Fat progress bar
                    _buildMacroRow(
                      label: 'Lipid (Chất béo)',
                      value: '${result.fatG.toStringAsFixed(1)}g',
                      percentage: fatPercent,
                      color: Colors.orange,
                    ),
                    
                    // Lượng nước nếu có
                    if (result.waterLiters > 0) ...[
                      const Divider(height: 32, color: AppColors.cardBorder),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.local_drink_rounded, color: AppColors.waterIcon, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Nước chứa trong phần ăn',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${(result.waterLiters * 1000).round()} ml',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.waterIcon,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Đánh giá từ chuyên gia AI
              const Text(
                'Nhận xét từ AI Health Coach',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF111826),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFD7B56D), width: 1.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.psychology_alt_rounded, color: Color(0xFFD7B56D), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        result.assessment,
                        style: const TextStyle(
                          color: Color(0xFFF5F1E6),
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Các nút lưu
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // Trở lại màn hình chính không lưu
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.textHint),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Bỏ qua',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () async {
                          // Tăng số lần quét
                          await NutritionAnalysisLimiter.incrementScanCount();

                          if (!context.mounted) return;

                          // Lưu dinh dưỡng vào Provider
                          await context.read<HealthProvider>().addNutritionInfo(result);

                          if (!context.mounted) return;

                          // Hiển thị toast thông báo thành công
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Đã lưu ${result.name} (+${result.calories} kcal) thành công!',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              backgroundColor: AppColors.primary,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );

                          // Trở lại Dashboard
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Lưu & Nhật ký',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacroRow({
    required String label,
    required String value,
    required double percentage,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: 8,
            backgroundColor: AppColors.scaffoldBg,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
