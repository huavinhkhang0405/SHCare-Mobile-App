class NutritionAnalysisResult {
  final String name; // Tên món ăn hoặc đồ uống
  final String type; // 'food' hoặc 'drink'
  final int calories;
  final double carbsG;
  final double proteinG;
  final double fatG;
  final double waterLiters; // Chỉ số nước ước lượng
  final int confidencePercentage;
  final String assessment;

  NutritionAnalysisResult({
    required this.name,
    required this.type,
    required this.calories,
    required this.carbsG,
    required this.proteinG,
    required this.fatG,
    required this.waterLiters,
    required this.confidencePercentage,
    required this.assessment,
  });

  factory NutritionAnalysisResult.fromJson(Map<String, dynamic> json) {
    return NutritionAnalysisResult(
      name: json['name'] as String? ?? 'Thực phẩm chưa xác định',
      type: json['type'] as String? ?? 'food',
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0.0,
      proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0.0,
      fatG: (json['fat_g'] as num?)?.toDouble() ?? 0.0,
      waterLiters: (json['water_liters'] as num?)?.toDouble() ?? 0.0,
      confidencePercentage: (json['confidence_percentage'] as num?)?.toInt() ?? 80,
      assessment: json['assessment'] as String? ?? 'Không có phân tích bổ sung.',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'calories': calories,
      'carbs_g': carbsG,
      'protein_g': proteinG,
      'fat_g': fatG,
      'water_liters': waterLiters,
      'confidence_percentage': confidencePercentage,
      'assessment': assessment,
    };
  }
}
