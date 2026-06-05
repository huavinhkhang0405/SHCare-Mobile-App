import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/ai/gemini_service.dart';

class NutritionScanPreviewScreen extends StatefulWidget {
  const NutritionScanPreviewScreen({super.key});

  @override
  State<NutritionScanPreviewScreen> createState() => _NutritionScanPreviewScreenState();
}

class _NutritionScanPreviewScreenState extends State<NutritionScanPreviewScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final GeminiService _geminiService = GeminiService();
  bool _isLoading = false;
  String _loadingMessage = 'Đang chuẩn bị gửi ảnh...';

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _startAnalysis(String imagePath) async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'AI đang nhận diện hình ảnh...';
    });

    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        throw Exception('Không tìm thấy tệp ảnh vừa chụp.');
      }

      final imageBytes = await file.readAsBytes();
      
      setState(() {
        _loadingMessage = 'Đang phân tích hàm lượng dinh dưỡng...';
      });

      final result = await _geminiService.analyzeNutritionImage(
        imageBytes,
        userDescription: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
      );

      if (!mounted) return;

      // Thành công, chuyển hướng qua màn hình hiển thị kết quả
      Navigator.of(context).pushReplacementNamed(
        '/nutrition_result',
        arguments: {
          'result': result,
          'imagePath': imagePath,
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: const Color(0xFF111826),
          title: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: AppColors.error),
              SizedBox(width: 10),
              Text('Phân tích thất bại', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Text(
            'Không thể phân tích thực phẩm. Lỗi: ${e.toString().replaceAll('Exception: ', '')}',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đồng ý', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = ModalRoute.of(context)!.settings.arguments as String;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text(
          'Xem trước hình ảnh',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Khung ảnh bo tròn nghệ thuật với hiệu ứng đổ bóng
                  Container(
                    height: MediaQuery.of(context).size.height * 0.4,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: AppColors.cardBorder, width: 2),
                      boxShadow: AppColors.softShadow,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Image.file(
                        File(imagePath),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Mô tả thêm (Tùy chọn)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Viết thêm mô tả giúp AI ước lượng calo chính xác hơn (ví dụ: bún chả ít bún, trà sữa trân châu 50% đường...)',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Ô nhập liệu mô tả
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.cardBorder),
                      boxShadow: AppColors.softShadow,
                    ),
                    child: TextField(
                      controller: _descriptionController,
                      maxLines: 3,
                      maxLength: 150,
                      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Nhập mô tả của bạn tại đây...',
                        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textHint),
                        contentPadding: const EdgeInsets.all(16),
                        border: InputBorder.none,
                        counterStyle: TextStyle(color: AppColors.textHint.withValues(alpha: 0.8)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Các nút điều khiển
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary, width: 2),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Hủy chụp',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
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
                            onPressed: () => _startAnalysis(imagePath),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Phân tích AI',
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
                ],
              ),
            ),
          ),

          // Loading Overlay cao cấp phong cách Fantasy/Glassmorphism
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.75),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111826),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFD7B56D), width: 2),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF162033), Color(0xFF0D1420)],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD7B56D)),
                        strokeWidth: 4,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _loadingMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Hệ thống AI đang tính toán lượng calories, chất béo, đạm và carbs...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFB6A27A),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
