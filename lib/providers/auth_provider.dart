import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firebase/user_service.dart';

/// Quản lý trạng thái xác thực người dùng sử dụng Firebase Auth.
/// Hỗ trợ đăng nhập bằng email/password, Google, Facebook.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  
  bool _isLoading = false;
  String? _errorMessage;
  UserModel? _currentUserModel;

  bool get isLoggedIn => firebase_auth.FirebaseAuth.instance.currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  UserModel? get currentUser => _currentUserModel;
  
  String get userName => _currentUserModel?.name ?? 
                         firebase_auth.FirebaseAuth.instance.currentUser?.displayName ?? 
                         firebase_auth.FirebaseAuth.instance.currentUser?.email?.split('@').first ?? '';
  String get userEmail => _currentUserModel?.email ?? 
                          firebase_auth.FirebaseAuth.instance.currentUser?.email ?? '';

  AuthProvider() {
    loadCurrentUserModel();
  }

  /// Tải thông tin người dùng từ Firestore
  Future<void> loadCurrentUserModel() async {
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      try {
        _currentUserModel = await _userService.getUser(firebaseUser.uid);
        if (_currentUserModel == null) {
          _currentUserModel = UserModel(
            id: firebaseUser.uid,
            email: firebaseUser.email ?? '',
            name: firebaseUser.displayName ?? firebaseUser.email?.split('@').first ?? 'User',
          );
        }
      } catch (e) {
        debugPrint('Lỗi tải thông tin user từ Firestore: $e');
      }
      notifyListeners();
    }
  }

  /// Đăng nhập bằng email / password
  Future<bool> loginWithEmail(String email, String password) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      if (email.isEmpty || password.isEmpty) {
        _errorMessage = 'Vui lòng điền đầy đủ thông tin';
        _setLoading(false);
        return false;
      }

      final credential = await _authService.signInWithEmail(email, password);
      if (credential != null && credential.user != null) {
        // Kiểm tra xem đã xác thực email hay chưa
        if (!credential.user!.emailVerified) {
          await _authService.signOut();
          _errorMessage = 'Tài khoản chưa được xác thực email. Vui lòng kiểm tra hộp thư.';
          _setLoading(false);
          return false;
        }
        await loadCurrentUserModel();
      }
      _setLoading(false);
      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        _errorMessage = 'Tài khoản không tồn tại hoặc sai mật khẩu';
      } else if (e.code == 'wrong-password') {
        _errorMessage = 'Mật khẩu không chính xác';
      } else if (e.code == 'invalid-email') {
        _errorMessage = 'Email không hợp lệ';
      } else if (e.code == 'user-disabled') {
        _errorMessage = 'Tài khoản này đã bị khóa';
      } else {
        _errorMessage = e.message ?? 'Đăng nhập thất bại';
      }
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = e.toString().contains('email-not-verified')
          ? 'Tài khoản chưa được xác thực email. Vui lòng kiểm tra hộp thư.'
          : 'Đã xảy ra lỗi. Vui lòng thử lại.';
      _setLoading(false);
      return false;
    }
  }

  /// Đăng ký tài khoản mới
  Future<bool> registerWithEmail(String name, String email, String password) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      if (name.isEmpty || email.isEmpty || password.isEmpty) {
        _errorMessage = 'Vui lòng điền đầy đủ thông tin';
        _setLoading(false);
        return false;
      }

      final credential = await _authService.signUpWithEmail(email, password);
      if (credential != null && credential.user != null) {
        await credential.user!.updateDisplayName(name);
        // Gửi email xác thực
        await credential.user!.sendEmailVerification();
        
        // Tạo User Document ban đầu trên Firestore (chưa có chiều cao, cân nặng...)
        final userModel = UserModel(
          id: credential.user!.uid,
          email: email.trim(),
          name: name.trim(),
        );
        await _userService.saveUser(userModel);
        
        // Đăng xuất ngay sau khi đăng ký để bắt buộc người dùng xác thực và đăng nhập lại
        await _authService.signOut();
      }
      _setLoading(false);
      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _errorMessage = 'Email này đã được sử dụng bởi một tài khoản khác';
      } else if (e.code == 'invalid-email') {
        _errorMessage = 'Email không hợp lệ';
      } else if (e.code == 'weak-password') {
        _errorMessage = 'Mật khẩu quá yếu (phải chứa từ 6 ký tự)';
      } else {
        _errorMessage = e.message ?? 'Đăng ký thất bại';
      }
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'Đã xảy ra lỗi. Vui lòng thử lại.';
      _setLoading(false);
      return false;
    }
  }

  /// Đăng nhập bằng Google
  Future<bool> loginWithGoogle() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final credential = await _authService.signInWithGoogle();
      if (credential != null && credential.user != null) {
        // Kiểm tra xem đã có document trên Firestore chưa
        final exists = await _userService.getUser(credential.user!.uid);
        if (exists == null) {
          final userModel = UserModel(
            id: credential.user!.uid,
            email: credential.user!.email ?? '',
            name: credential.user!.displayName ?? credential.user!.email?.split('@').first ?? 'User',
          );
          await _userService.saveUser(userModel);
          _currentUserModel = userModel;
        } else {
          _currentUserModel = exists;
        }
        notifyListeners();
      }
      _setLoading(false);
      return credential != null;
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        _errorMessage = 'Email này đã được sử dụng với phương thức đăng nhập khác (ví dụ: Facebook hoặc Email).';
      } else {
        _errorMessage = e.message ?? 'Không thể đăng nhập bằng Google';
      }
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'Không thể đăng nhập bằng Google';
      _setLoading(false);
      return false;
    }
  }

  /// Đăng nhập bằng Facebook
  Future<bool> loginWithFacebook() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final credential = await _authService.signInWithFacebook();
      if (credential != null && credential.user != null) {
        // Kiểm tra xem đã có document trên Firestore chưa
        final exists = await _userService.getUser(credential.user!.uid);
        if (exists == null) {
          final userModel = UserModel(
            id: credential.user!.uid,
            email: credential.user!.email ?? '',
            name: credential.user!.displayName ?? credential.user!.email?.split('@').first ?? 'User',
          );
          await _userService.saveUser(userModel);
          _currentUserModel = userModel;
        } else {
          _currentUserModel = exists;
        }
        notifyListeners();
      }
      _setLoading(false);
      return credential != null;
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        _errorMessage = 'Email của tài khoản Facebook này đã được đăng ký bằng phương thức khác (ví dụ: Google hoặc Email).';
      } else {
        _errorMessage = e.message ?? 'Không thể đăng nhập bằng Facebook';
      }
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'Không thể đăng nhập bằng Facebook';
      _setLoading(false);
      return false;
    }
  }

  /// Lưu thông tin onboarding lên Firestore
  Future<bool> saveOnboardingData({
    required int birthYear,
    required String gender,
    required double heightCm,
    required double weightKg,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        _errorMessage = 'Không tìm thấy thông tin đăng nhập.';
        _setLoading(false);
        return false;
      }

      final updatedModel = UserModel(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? _currentUserModel?.email ?? '',
        name: firebaseUser.displayName ?? _currentUserModel?.name ?? 'User',
        birthYear: birthYear,
        gender: gender,
        heightCm: heightCm,
        weightKg: weightKg,
        createdAt: _currentUserModel?.createdAt,
      );

      await _userService.saveUser(updatedModel);
      _currentUserModel = updatedModel;
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Lỗi lưu thông tin cơ thể: $e';
      _setLoading(false);
      return false;
    }
  }

  /// Cập nhật thông tin cá nhân (Họ tên, Năm sinh, Giới tính, Chiều cao, Cân nặng)
  Future<bool> updateProfile({
    required String name,
    required int birthYear,
    required String gender,
    required double heightCm,
    required double weightKg,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        _errorMessage = 'Không tìm thấy thông tin đăng nhập.';
        _setLoading(false);
        return false;
      }

      // Cập nhật tên hiển thị trên Firebase Auth
      await firebaseUser.updateDisplayName(name);

      final updatedModel = UserModel(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? _currentUserModel?.email ?? '',
        name: name,
        birthYear: birthYear,
        gender: gender,
        heightCm: heightCm,
        weightKg: weightKg,
        createdAt: _currentUserModel?.createdAt,
      );

      await _userService.saveUser(updatedModel);
      _currentUserModel = updatedModel;
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Lỗi cập nhật thông tin: $e';
      _setLoading(false);
      return false;
    }
  }

  /// Đăng xuất
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.signOut();
      _currentUserModel = null;
    } catch (e) {
      debugPrint('Lỗi khi đăng xuất: $e');
    } finally {
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
