import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final String? gender; 
  final double? heightCm; // Chiều cao (cm)
  final double? weightKg; // Cân nặng (kg)
  final int? birthYear; // Năm sinh
  final int stepGoal; // Mục tiêu bước chân/ngày
  final double waterGoalLiters; // Mục tiêu uống nước (lít/ngày)
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    this.gender,
    this.heightCm,
    this.weightKg
    this.birthYear,
    this.stepGoal = 10000,
    this.waterGoalLiters = 2.0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Chuyển từ JSON (Firestore) → Object
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      gender: json['gender'] as String?,
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      birthYear: json['birth_year'] as int?,
      stepGoal: (json['step_goal'] as int?) ?? 10000,
      waterGoalLiters: (json['water_goal_liters'] as num?)?.toDouble() ?? 2.0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return UserModel(id: doc.id, email: '', name: 'Unknown'); 
    }
    return UserModel(
      id: doc.id,
      email: data['email'] as String? ?? '',
      name: data['name'] as String? ?? '',
      avatarUrl: data['avatar_url'] as String?,
      gender: data['gender'] as String?,
      heightCm: (data['height_cm'] as num?)?.toDouble(),
      weightKg: (data['weight_kg'] as num?)?.toDouble(),
      birthYear: data['birth_year'] as int?,
      stepGoal: (data['step_goal'] as int?) ?? 10000,
      waterGoalLiters: (data['water_goal_liters'] as num?)?.toDouble() ?? 2.0,
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Chuyển từ Object → JSON (để lưu Firestore)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatar_url': avatarUrl,
      'gender': gender,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'birth_year': birthYear,
      'step_goal': stepGoal,
      'water_goal_liters': waterGoalLiters,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Tạo bản sao với một số trường được thay đổi
  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? avatarUrl,
    String? gender,
    double? heightCm,
    double? weightKg,
    int? birthYear,
    int? stepGoal,
    double? waterGoalLiters,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      gender: gender ?? this.gender,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      birthYear: birthYear ?? this.birthYear,
      stepGoal: stepGoal ?? this.stepGoal,
      waterGoalLiters: waterGoalLiters ?? this.waterGoalLiters,
      createdAt: createdAt,
    );
  }
}