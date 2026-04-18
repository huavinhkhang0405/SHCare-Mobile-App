// lib/models/user_model.dart

class UserModel {
  final String id;
  final String email;
  final String name;
  final double? height; // Dành cho team User Profile
  final double? weight; // Dành cho team User Profile
  final String? gender;
  
  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.height,
    this.weight,
    this.gender,
  });

  // Có thể viết sẵn luôn hàm chuyển đổi JSON từ Firebase ở đây
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      height: json['height']?.toDouble(),
      weight: json['weight']?.toDouble(),
      gender: json['gender'],
    );
  }
}