import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shcare_app/models/pet_model.dart';

class PetService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // Biến Cache lưu danh sách các câu nói "Hoàn thành nhiệm vụ" trong bộ nhớ RAM
  List<String> _cachedCompletedQuotes = [];

  // Hàm phụ trợ: Load và Parse JSON
  Future<void> _loadQuotesIfNeeded() async {
    // Nếu đã load rồi thì bỏ qua, tránh đọc file disk nhiều lần gây lag
    if (_cachedCompletedQuotes.isNotEmpty) return;

    try {
      // 1. Đọc nội dung file JSON
      final String response = await rootBundle.loadString('assets/data/quotes.json');
      
      // 2. Chuyển String thành kiểu Map/JSON của Dart
      final data = json.decode(response);
      final List<dynamic> quotesList = data['quotes'];

      // 3. Lọc lấy những câu có event_type là "task_completed"
      _cachedCompletedQuotes = quotesList
          .where((q) => q['event_type'] == 'task_completed')
          .map((q) => q['text'] as String)
          .toList();
          
    } catch (e) {
      print("🚨 Lỗi khi load quotes.json: $e");
      // Fallback an toàn nếu có lỗi file
      _cachedCompletedQuotes = [
        "Tuyệt vời! Cứ giữ vững phong độ này nhé!",
        "Chủ nhân xịn quá! Năng lượng của mình đang tràn trề!"
      ];
    }
  }

  // Khởi tạo Pet cấp 1 cho người dùng mới
  Future<void> initializePet(String userId) async {
    final petRef = _db
        .collection('users')
        .doc(userId)
        .collection('pets')
        .doc('current_pet');

    final snapshot = await petRef.get();
    if (!snapshot.exists) {
      final newPet = PetModel(
        id: 'current_pet',
        userId: userId,
        level: 1,
        currentExp: 0,
        expToNextLevel: 100,
        state: 'Năng động',
        message: 'Chào bạn! Hôm nay mình cùng nhau rèn sức khỏe nhé.',
        currentTask: 'Đi bộ 500 bước để khởi động ngày mới.',
        isTaskCompleted: false,
      );
      await petRef.set(newPet.toJson());
    }
  }

  // 1. Lắng nghe dữ liệu Pet theo thời gian thực
  Stream<PetModel> streamPetData(String userId) {
    if (userId.isEmpty) {
      return Stream.value(PetModel(id: 'current_pet', userId: ''));
    }

    return _db
        .collection('users')
        .doc(userId)
        .collection('pets')
        .doc('current_pet')
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) {
            // Lazy initialization ngầm dưới nền
            initializePet(userId);
            return PetModel(
              id: 'current_pet',
              userId: userId,
              level: 1,
              currentExp: 0,
              expToNextLevel: 100,
              state: 'Năng động',
              message: 'Chào bạn! Hôm nay mình cùng nhau rèn sức khỏe nhé.',
              currentTask: 'Đi bộ 500 bước để khởi động ngày mới.',
              isTaskCompleted: false,
            );
          }
          return PetModel.fromFirestore(snapshot);
        });
  }

  // 2. Logic cộng EXP khi làm nhiệm vụ sức khoẻ
  Future<void> gainExperience(String userId, int expGained) async {
    // Đảm bảo quotes đã được load trước khi xử lý logic
    await _loadQuotesIfNeeded();

    final petRef = _db
        .collection('users')
        .doc(userId)
        .collection('pets')
        .doc('current_pet');

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(petRef);
      
      if (!snapshot.exists) {
        final newPet = PetModel(
          id: 'current_pet',
          userId: userId,
          currentExp: expGained,
        );
        transaction.set(petRef, newPet.toJson());
        return;
      }

      final pet = PetModel.fromFirestore(snapshot);
      int newExp = pet.currentExp + expGained;
      int newLevel = pet.level;
      int nextLevelExp = pet.expToNextLevel;
      String newState = 'Vui vẻ'; 

      while (newExp >= nextLevelExp) {
        newExp -= nextLevelExp;
        newLevel++;
        nextLevelExp = (nextLevelExp * 1.5).round(); 
      }

      // Lấy ngẫu nhiên 1 câu nói từ Cache
      final random = Random();
      String randomMessage = _cachedCompletedQuotes.isNotEmpty
          ? _cachedCompletedQuotes[random.nextInt(_cachedCompletedQuotes.length)]
          : "Tuyệt vời lắm!";

      final updatedPet = pet.copyWith(
        currentExp: newExp,
        level: newLevel,
        expToNextLevel: nextLevelExp,
        state: newState,
        message: randomMessage, // Cập nhật câu nói từ JSON vào đây
        isTaskCompleted: true, 
      );

      transaction.update(petRef, updatedPet.toJson());
    });
  }
}