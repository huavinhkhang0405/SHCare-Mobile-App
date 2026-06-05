import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Stream lắng nghe sự thay đổi trạng thái đăng nhập (đăng nhập/đăng xuất)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Lấy thông tin user hiện tại
  User? get currentUser => _auth.currentUser;

  // 1. Đăng nhập bằng Email và Password
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Lỗi đăng nhập Email: ${e.code} - ${e.message}');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('Lỗi không xác định khi đăng nhập Email: $e');
      }
      rethrow;
    }
  }

  // 2. Đăng ký bằng Email và Password
  Future<UserCredential?> signUpWithEmail(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Lỗi đăng ký Email: ${e.code} - ${e.message}');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('Lỗi không xác định khi đăng ký Email: $e');
      }
      rethrow;
    }
  }

  // 3. Đăng nhập bằng Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Kích hoạt luồng đăng nhập Google trên thiết bị
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // Người dùng hủy đăng nhập
        return null;
      }

      // Lấy thông tin xác thực từ tài khoản Google
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Tạo một thông tin xác thực Firebase mới từ Google token
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Đăng nhập vào Firebase bằng credential mới
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Lỗi đăng nhập Google với Firebase: ${e.code} - ${e.message}');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('Lỗi Google Sign-In: $e');
      }
      rethrow;
    }
  }

  // 4. Đăng nhập bằng Facebook
  Future<UserCredential?> signInWithFacebook() async {
    try {
      // Thực hiện đăng nhập Facebook thông qua SDK
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status == LoginStatus.success) {
        // Lấy access token từ kết quả đăng nhập thành công
        final AccessToken accessToken = result.accessToken!;

        // Tạo thông tin xác thực Firebase mới từ Facebook token
        final OAuthCredential credential = FacebookAuthProvider.credential(accessToken.tokenString);

        // Đăng nhập vào Firebase
        return await _auth.signInWithCredential(credential);
      } else if (result.status == LoginStatus.cancelled) {
        if (kDebugMode) {
          print('Người dùng hủy đăng nhập Facebook.');
        }
        return null;
      } else {
        throw Exception('Lỗi Facebook Auth: ${result.message}');
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Lỗi đăng nhập Facebook với Firebase: ${e.code} - ${e.message}');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('Lỗi Facebook Login: $e');
      }
      rethrow;
    }
  }

  // 5. Đăng xuất
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      await FacebookAuth.instance.logOut();
    } catch (e) {
      if (kDebugMode) {
        print('Lỗi khi đăng xuất: $e');
      }
      rethrow;
    }
  }
}
