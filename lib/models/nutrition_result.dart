class NutritionResult {
  final List<String> foodItems;
  final int totalCalories;
  final int totalProtein;
  final int totalCarbs;
  final int totalFat;
  final bool isValidFood; // Cờ kiểm tra xem người dùng có nhập hợp lệ hay không

  NutritionResult({
    required this.foodItems,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.isValidFood,
  });

  factory NutritionResult.fromJson(Map<String, dynamic> json) {
    return NutritionResult(
      foodItems: List<String>.from(json['food_items'] ?? []),
      totalCalories: (json['total_calories'] as num?)?.toInt() ?? 0,
      totalProtein: (json['total_protein'] as num?)?.toInt() ?? 0,
      totalCarbs: (json['total_carbs'] as num?)?.toInt() ?? 0,
      totalFat: (json['total_fat'] as num?)?.toInt() ?? 0,
      isValidFood: json['is_valid_food'] ?? false,
    );
  }
}
