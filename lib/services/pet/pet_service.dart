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
      String ownerName = 'Bạn của Pet';
      try {
        final userDoc = await _db.collection('users').doc(userId).get();
        if (userDoc.exists) {
          ownerName = (userDoc.data()?['name'] as String?) ?? 'Bạn của Pet';
        }
      } catch (e) {
        print("🚨 Lỗi khi lấy tên chủ Pet: $e");
      }

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
        currentTitle: 'Chúa tể ôm giường',
        ownerName: ownerName,
      );
      await petRef.set(newPet.toJson());
    }
  }

  // Cập nhật tên chủ sở hữu Pet
  Future<void> updateOwnerName(String userId, String newName) async {
    try {
      final petRef = _db
          .collection('users')
          .doc(userId)
          .collection('pets')
          .doc('current_pet');
      await petRef.update({'owner_name': newName});
    } catch (e) {
      print("🚨 Lỗi updateOwnerName: $e");
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
  Future<void> gainExperience(String userId, int expGained, {int goldGained = 0}) async {
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
          goldCoins: goldGained,
        );
        transaction.set(petRef, newPet.toJson());
        return;
      }

      final pet = PetModel.fromFirestore(snapshot);
      int newExp = pet.currentExp + expGained;
      int newLevel = pet.level;
      int nextLevelExp = pet.expToNextLevel;
      int newGold = pet.goldCoins + goldGained;
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
        goldCoins: newGold,
        state: newState,
        message: randomMessage, // Cập nhật câu nói từ JSON vào đây
        isTaskCompleted: true, 
      );

      transaction.update(petRef, updatedPet.toJson());
    });
  }

  // 3. Cập nhật trạng thái và tin nhắn của Pet trực tiếp
  Future<void> updatePetState(String userId, String state, String message) async {
    try {
      final petRef = _db
          .collection('users')
          .doc(userId)
          .collection('pets')
          .doc('current_pet');
      await petRef.update({
        'state': state,
        'message': message,
        'is_task_completed': false,
      });
    } catch (e) {
      // ignore: avoid_print
      print("🚨 Lỗi updatePetState: $e");
    }
  }

  // 4. Mua bùa đóng băng qua Firestore Transaction tránh lỗi Race Condition
  Future<void> purchaseStreakFreeze(String userId) async {
    final petRef = _db
        .collection('users')
        .doc(userId)
        .collection('pets')
        .doc('current_pet');

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(petRef);
      if (!snapshot.exists) {
        throw Exception('Thú cưng không tồn tại để mua bùa.');
      }

      final pet = PetModel.fromFirestore(snapshot);
      if (pet.goldCoins < 50) {
        throw Exception('Không đủ vàng để mua bùa đóng băng (Cần 50 🪙).');
      }

      final updatedPet = pet.copyWith(
        goldCoins: pet.goldCoins - 50,
        streakFreezeCount: pet.streakFreezeCount + 1,
      );

      transaction.update(petRef, updatedPet.toJson());
    });
  }

  // 5. Cập nhật Streak và Freeze Count
  Future<void> updateStreakAndFreeze(
    String userId, {
    required int newStreak,
    required int newFreeze,
    String? newState,
    String? newMessage,
  }) async {
    try {
      final petRef = _db
          .collection('users')
          .doc(userId)
          .collection('pets')
          .doc('current_pet');
      
      final Map<String, dynamic> updates = {
        'streak_count': newStreak,
        'streak_freeze_count': newFreeze,
      };
      if (newState != null) updates['state'] = newState;
      if (newMessage != null) updates['message'] = newMessage;

      await petRef.update(updates);
    } catch (e) {
      // ignore: avoid_print
      print("🚨 Lỗi updateStreakAndFreeze: $e");
    }
  }

  // 6. Lấy dữ liệu Pet một lần (không dùng Stream)
  Future<PetModel?> getPetData(String userId) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(userId)
          .collection('pets')
          .doc('current_pet')
          .get();
      if (doc.exists) {
        return PetModel.fromFirestore(doc);
      }
    } catch (e) {
      // ignore: avoid_print
      print("🚨 Lỗi getPetData: $e");
    }
    return null;
  }
}