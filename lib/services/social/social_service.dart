import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../../../models/pet_model.dart';
import '../../../models/user_model.dart';

enum FriendRequestResult {
  sent,
  alreadyFriends,
  alreadyRequested,
  autoAccepted,
  selfConnect,
  notFound,
  error,
}

class SocialService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Loại bỏ dấu tiếng Việt để tạo mã kết bạn chuẩn hóa
  String _removeVietnameseDiacritics(String str) {
    const withDiacritics = 'àáãạảăắằẳẵặâấầẩẫậèéẹẻẽêềếểễệđìíĩỉịòóõọỏôốồổỗộơớờởỡợùúũụủưứừửữựỳỵỷỹý'
        'ÀÁÃẠẢĂẮẰẲẴẶÂẤẦẨẪẬÈÉẸẺẼÊỀẾỂỄỆĐÌÍĨỈỊÒÓÕỌỎÔỐỒỔỖỘƠỚỜỞỠỢÙÚŨỤỦƯỨỪỬỮỰỲỴỶỸÝ';
    const withoutDiacritics = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeediiiiiooooooooooooooooouuuuuuuuuuuyyyyy'
        'AAAAAAAAAAAAAAAAAEEEEEEEEEEEDIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYY';
    
    String result = str;
    for (int i = 0; i < withDiacritics.length; i++) {
      result = result.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }
    return result;
  }

  /// Kiểm tra mã kết bạn đã tồn tại trong hệ thống chưa
  Future<bool> checkFriendCodeExists(String code) async {
    if (code.trim().isEmpty) return false;
    final cleanCode = code.trim().toUpperCase();
    try {
      final querySnapshot = await _db
          .collection('users')
          .where('friend_code', isEqualTo: cleanCode)
          .limit(1)
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('🚨 [SocialService] Lỗi khi kiểm tra trùng mã: $e');
      return false;
    }
  }

  /// Sinh mã kết bạn thô (chưa check trùng)
  String generateFriendCode(String name) {
    final noDiacritics = _removeVietnameseDiacritics(name);
    final cleanName = noDiacritics.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final prefix = cleanName.length > 4 ? cleanName.substring(0, 4) : (cleanName.isNotEmpty ? cleanName : 'USER');
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final suffix = List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
    return '$prefix$suffix';
  }

  /// Sinh mã kết bạn độc nhất không trùng lặp (kiểm tra Firestore)
  Future<String> generateUniqueFriendCode(String name) async {
    String code = generateFriendCode(name);
    bool exists = await checkFriendCodeExists(code);
    int attempts = 0;

    while (exists && attempts < 5) {
      code = generateFriendCode(name);
      exists = await checkFriendCodeExists(code);
      attempts++;
    }

    // Nếu sau 5 lần vẫn trùng (xác suất cực thấp), append thêm miliseconds để đảm bảo độc nhất
    if (exists) {
      final prefix = code.length > 4 ? code.substring(0, 4) : code;
      final timeStr = DateTime.now().millisecondsSinceEpoch.toString();
      final suffix = timeStr.substring(max(0, timeStr.length - 4));
      code = '$prefix$suffix'.toUpperCase();
    }

    return code;
  }

  /// Kết bạn bằng mã code
  Future<bool> addFriendByCode(String code, String currentUserId) async {
    if (code.trim().isEmpty || currentUserId.isEmpty) return false;
    final cleanCode = code.trim().toUpperCase();

    try {
      // 1. Tìm người dùng có mã kết bạn trùng khớp
      final querySnapshot = await _db
          .collection('users')
          .where('friend_code', isEqualTo: cleanCode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return false; // Không tìm thấy mã kết bạn
      }

      final friendDoc = querySnapshot.docs.first;
      final friendId = friendDoc.id;

      if (friendId == currentUserId) {
        return false; // Không thể kết bạn với chính mình
      }

      final myUserDoc = await _db.collection('users').doc(currentUserId).get();
      if (!myUserDoc.exists) return false;

      final myUser = UserModel.fromFirestore(myUserDoc);

      // Nếu đã là bạn bè, trả về true luôn
      if (myUser.friends.contains(friendId)) {
        return true;
      }

      // 2. Cập nhật mảng bạn bè của hai bên thông qua transaction để đảm bảo toàn vẹn
      await _db.runTransaction((transaction) async {
        transaction.update(_db.collection('users').doc(currentUserId), {
          'friends': FieldValue.arrayUnion([friendId])
        });
        transaction.update(_db.collection('users').doc(friendId), {
          'friends': FieldValue.arrayUnion([currentUserId])
        });
      });

      return true;
    } catch (e) {
      print('🚨 [SocialService] Lỗi khi kết bạn: $e');
      return false;
    }
  }

  /// Hủy kết bạn
  Future<bool> removeFriend(String currentUserId, String friendId) async {
    if (currentUserId.isEmpty || friendId.isEmpty) return false;

    try {
      await _db.runTransaction((transaction) async {
        transaction.update(_db.collection('users').doc(currentUserId), {
          'friends': FieldValue.arrayRemove([friendId])
        });
        transaction.update(_db.collection('users').doc(friendId), {
          'friends': FieldValue.arrayRemove([currentUserId])
        });
      });
      return true;
    } catch (e) {
      print('🚨 [SocialService] Lỗi khi hủy kết bạn: $e');
      return false;
    }
  }

  /// Tìm bạn qua Facebook và tự động kết bạn
  Future<List<String>> linkFacebookFriends(String currentUserId) async {
    final List<String> addedFriendNames = [];
    if (currentUserId.isEmpty) return addedFriendNames;

    try {
      // 1. Kiểm tra xem người dùng có token Facebook hợp lệ không
      final AccessToken? accessToken = await FacebookAuth.instance.accessToken;
      if (accessToken == null) {
        print('⚠️ [SocialService] Không tìm thấy Access Token Facebook.');
        return addedFriendNames;
      }

      // 2. Gọi API để lấy danh sách bạn bè cùng dùng ứng dụng
      final Map<String, dynamic> userData = await FacebookAuth.instance.getUserData(fields: 'friends');
      final friendsData = userData['friends'] as Map<String, dynamic>?;
      if (friendsData == null) return addedFriendNames;

      final dataList = friendsData['data'] as List<dynamic>?;
      if (dataList == null || dataList.isEmpty) return addedFriendNames;

      // Trích xuất danh sách Facebook ID của bạn bè
      final List<String> friendFbIds = dataList
          .map((f) => f['id'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toList();

      if (friendFbIds.isEmpty) return addedFriendNames;

      // 3. Tìm các user trong hệ thống có facebook_id nằm trong danh sách trên
      // Firestore giới hạn whereIn 30 phần tử, ta take(30) cho an toàn
      final querySnapshot = await _db
          .collection('users')
          .where('facebook_id', whereIn: friendFbIds.take(30).toList())
          .get();

      if (querySnapshot.docs.isEmpty) return addedFriendNames;

      // 4. Lấy thông tin user hiện tại
      final myUserDoc = await _db.collection('users').doc(currentUserId).get();
      if (!myUserDoc.exists) return addedFriendNames;
      final myUser = UserModel.fromFirestore(myUserDoc);

      // 5. Kết bạn với từng người trong transaction hoặc batch
      final batch = _db.batch();
      bool hasUpdates = false;

      for (var friendDoc in querySnapshot.docs) {
        final friendId = friendDoc.id;
        final friendUser = UserModel.fromFirestore(friendDoc);

        if (friendId == currentUserId) continue;

        // Nếu chưa là bạn bè, tiến hành kết bạn cả 2 chiều
        if (!myUser.friends.contains(friendId)) {
          batch.update(_db.collection('users').doc(currentUserId), {
            'friends': FieldValue.arrayUnion([friendId])
          });
          batch.update(_db.collection('users').doc(friendId), {
            'friends': FieldValue.arrayUnion([currentUserId])
          });
          addedFriendNames.add(friendUser.name);
          hasUpdates = true;
        }
      }

      if (hasUpdates) {
        await batch.commit();
      }
    } catch (e) {
      print('🚨 [SocialService] Lỗi khi kết bạn qua Facebook: $e');
    }

    return addedFriendNames;
  }

  /// Lấy Bảng xếp hạng thú cưng của bạn bè (Leaderboard)
  /// Sử dụng song song hóa Future.wait thay cho collectionGroup để tránh bắt buộc khai báo Index trên Firebase Console
  Future<List<PetModel>> fetchLeaderboard(String currentUserId, List<String> friendIds) async {
    final List<PetModel> leaderboard = [];
    if (currentUserId.isEmpty) return leaderboard;

    try {
      // 1. Lấy thông tin Pet của chính mình
      final myPetDoc = await _db
          .collection('users')
          .doc(currentUserId)
          .collection('pets')
          .doc('current_pet')
          .get();

      if (myPetDoc.exists) {
        leaderboard.add(PetModel.fromFirestore(myPetDoc));
      }

      // 2. Lấy thông tin Pet của bạn bè song song (tối đa 29 bạn bè có thứ hạng cao nhất)
      if (friendIds.isNotEmpty) {
        final List<Future<DocumentSnapshot>> futures = friendIds.take(29).map((fId) {
          return _db
              .collection('users')
              .doc(fId)
              .collection('pets')
              .doc('current_pet')
              .get();
        }).toList();

        final snapshots = await Future.wait(futures);
        for (var doc in snapshots) {
          if (doc.exists) {
            leaderboard.add(PetModel.fromFirestore(doc));
          }
        }
      }

      // 3. Sắp xếp giảm dần theo Level, rồi đến EXP
      leaderboard.sort((a, b) {
        if (a.level != b.level) {
          return b.level.compareTo(a.level);
        }
        return b.currentExp.compareTo(a.currentExp);
      });
    } catch (e) {
      print('🚨 [SocialService] Lỗi khi lấy bảng xếp hạng: $e');
    }

    return leaderboard;
  }

  /// Gửi chọc ghẹo bạn bè (Poke)
  Future<bool> sendPoke(String friendId, String senderId, String senderName, String pokeType) async {
    if (friendId.isEmpty || senderId.isEmpty) return false;

    try {
      final pokeRef = _db
          .collection('users')
          .doc(friendId)
          .collection('pokes')
          .doc(); // Auto ID

      await pokeRef.set({
        'sender_id': senderId,
        'sender_name': senderName,
        'poke_type': pokeType,
        'timestamp': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('🚨 [SocialService] Lỗi khi gửi Poke: $e');
      return false;
    }
  }

  /// Lấy dòng dữ liệu Poke chọc ghẹo realtime
  Stream<QuerySnapshot> streamPokes(String userId) {
    if (userId.isEmpty) return const Stream.empty();
    return _db
        .collection('users')
        .doc(userId)
        .collection('pokes')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Xóa poke (Sau khi hiển thị xong thông báo) để dọn rác (Garbage Collection)
  Future<void> deletePoke(String userId, String pokeId) async {
    if (userId.isEmpty || pokeId.isEmpty) return;
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('pokes')
          .doc(pokeId)
          .delete();
    } catch (e) {
      print('🚨 [SocialService] Lỗi khi xóa Poke: $e');
    }
  }

  /// Gửi yêu cầu kết bạn bằng mã code
  Future<FriendRequestResult> sendFriendRequest(String code, String currentUserId) async {
    if (code.trim().isEmpty || currentUserId.isEmpty) return FriendRequestResult.notFound;
    final cleanCode = code.trim().toUpperCase();

    try {
      // 1. Tìm người dùng có mã kết bạn trùng khớp
      final querySnapshot = await _db
          .collection('users')
          .where('friend_code', isEqualTo: cleanCode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return FriendRequestResult.notFound; // Không tìm thấy mã kết bạn
      }

      final friendDoc = querySnapshot.docs.first;
      final friendId = friendDoc.id;

      if (friendId == currentUserId) {
        return FriendRequestResult.selfConnect; // Không thể kết bạn với chính mình
      }

      // 2. Kiểm tra thông tin của tôi
      final myUserDoc = await _db.collection('users').doc(currentUserId).get();
      if (!myUserDoc.exists) return FriendRequestResult.error;

      final myUser = UserModel.fromFirestore(myUserDoc);

      // Nếu đã là bạn bè, trả về alreadyFriends
      if (myUser.friends.contains(friendId)) {
        return FriendRequestResult.alreadyFriends;
      }

      // 3. Kiểm tra xem đã gửi yêu cầu kết bạn trước đó chưa (A gửi cho B)
      final outgoingDoc = await _db
          .collection('users')
          .doc(friendId)
          .collection('friend_requests')
          .doc(currentUserId)
          .get();

      if (outgoingDoc.exists) {
        return FriendRequestResult.alreadyRequested;
      }

      // 4. Kiểm tra xem đối phương có gửi yêu cầu kết bạn cho mình trước đó chưa (B gửi cho A)
      final incomingDoc = await _db
          .collection('users')
          .doc(currentUserId)
          .collection('friend_requests')
          .doc(friendId)
          .get();

      if (incomingDoc.exists) {
        // Tự động kết bạn hai chiều (Auto-Accept)
        await _db.runTransaction((transaction) async {
          // Thêm bạn bè hai bên
          transaction.update(_db.collection('users').doc(currentUserId), {
            'friends': FieldValue.arrayUnion([friendId])
          });
          transaction.update(_db.collection('users').doc(friendId), {
            'friends': FieldValue.arrayUnion([currentUserId])
          });
          // Xóa yêu cầu kết bạn cũ
          transaction.delete(_db
              .collection('users')
              .doc(currentUserId)
              .collection('friend_requests')
              .doc(friendId));
        });
        return FriendRequestResult.autoAccepted;
      }

      // 5. Nếu chưa có kết nối nào, tạo yêu cầu kết bạn mới
      await _db
          .collection('users')
          .doc(friendId)
          .collection('friend_requests')
          .doc(currentUserId)
          .set({
        'sender_id': currentUserId,
        'sender_name': myUser.name,
        'sender_avatar': myUser.avatarUrl,
        'timestamp': DateTime.now().toIso8601String(),
      });

      return FriendRequestResult.sent;
    } catch (e) {
      print('🚨 [SocialService] Lỗi khi gửi yêu cầu kết bạn: $e');
      return FriendRequestResult.error;
    }
  }

  /// Lấy danh sách yêu cầu kết bạn realtime
  Stream<QuerySnapshot> streamFriendRequests(String userId) {
    if (userId.isEmpty) return const Stream.empty();
    return _db
        .collection('users')
        .doc(userId)
        .collection('friend_requests')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Chấp nhận yêu cầu kết bạn (Thêm bạn bè 2 chiều và xóa yêu cầu)
  Future<bool> acceptFriendRequest(String currentUserId, String requesterId) async {
    if (currentUserId.isEmpty || requesterId.isEmpty) return false;

    try {
      await _db.runTransaction((transaction) async {
        // Thêm bạn bè hai bên
        transaction.update(_db.collection('users').doc(currentUserId), {
          'friends': FieldValue.arrayUnion([requesterId])
        });
        transaction.update(_db.collection('users').doc(requesterId), {
          'friends': FieldValue.arrayUnion([currentUserId])
        });
        // Xóa yêu cầu kết bạn
        transaction.delete(_db
            .collection('users')
            .doc(currentUserId)
            .collection('friend_requests')
            .doc(requesterId));
      });
      return true;
    } catch (e) {
      print('🚨 [SocialService] Lỗi khi chấp nhận kết bạn: $e');
      return false;
    }
  }

  /// Từ chối yêu cầu kết bạn (Xóa yêu cầu)
  Future<bool> declineFriendRequest(String currentUserId, String requesterId) async {
    if (currentUserId.isEmpty || requesterId.isEmpty) return false;

    try {
      await _db
          .collection('users')
          .doc(currentUserId)
          .collection('friend_requests')
          .doc(requesterId)
          .delete();
      return true;
    } catch (e) {
      print('🚨 [SocialService] Lỗi khi từ chối kết bạn: $e');
      return false;
    }
  }
}
