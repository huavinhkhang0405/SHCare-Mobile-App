import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Lưu thông tin user lên Firestore
  Future<void> saveUser(UserModel user) async {
    await _db.collection('users').doc(user.id).set(user.toJson());
  }

  // Lấy thông tin user từ Firestore
  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserModel.fromFirestore(doc);
    }
    return null;
  }
}
