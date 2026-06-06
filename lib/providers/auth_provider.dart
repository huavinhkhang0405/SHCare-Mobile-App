import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firebase/user_service.dart';
import '../services/pet/pet_service.dart';
import '../services/social/social_service.dart';

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
          // Tự sinh mã kết bạn độc nhất nếu chưa có
          final code = await SocialService().generateUniqueFriendCode(_currentUserModel!.name);
          _currentUserModel = _currentUserModel!.copyWith(friendCode: code);
          await _userService.saveUser(_currentUserModel!);
        } else if (_currentUserModel!.friendCode.isEmpty || 
                   !RegExp(r'^[A-Z0-9]+$').hasMatch(_currentUserModel!.friendCode)) {
          final code = await SocialService().generateUniqueFriendCode(_currentUserModel!.name);
          _currentUserModel = _currentUserModel!.copyWith(friendCode: code);
          await _userService.saveUser(_currentUserModel!);
        }
      } catch (e) {
        debugPrint('Lỗi tải thông tin user từ Firestore: $e');
      }
      notifyListeners();
    }
  }

  /// Nạp lại thông tin người dùng
  Future<void> reloadUserData() async {
    await loadCurrentUserModel();
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
        // Đảm bảo pet collection tồn tại (backward compatibility cho user cũ chưa có pet)
        await PetService().initializePet(credential.user!.uid);
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
        final code = await SocialService().generateUniqueFriendCode(name.trim());
        final userModel = UserModel(
          id: credential.user!.uid,
          email: email.trim(),
          name: name.trim(),
          friendCode: code,
        );
        await _userService.saveUser(userModel);
        
        // Tạo collection pet mặc định (level 1) cho tài khoản mới trên Firestore
        await PetService().initializePet(credential.user!.uid);
        
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
          final displayName = credential.user!.displayName ?? credential.user!.email?.split('@').first ?? 'User';
          final code = await SocialService().generateUniqueFriendCode(displayName);
          final userModel = UserModel(
            id: credential.user!.uid,
            email: credential.user!.email ?? '',
            name: displayName,
            friendCode: code,
          );
          await _userService.saveUser(userModel);
          _currentUserModel = userModel;
        } else {
          _currentUserModel = exists;
        }
        // Đảm bảo pet collection tồn tại cho user (tạo mới nếu chưa có)
        await PetService().initializePet(credential.user!.uid);
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
        // Trích xuất Facebook ID từ providerData
        String? facebookId;
        for (final profile in credential.user!.providerData) {
          if (profile.providerId == 'facebook.com') {
            facebookId = profile.uid;
            break;
          }
        }

        // Kiểm tra xem đã có document trên Firestore chưa
        final exists = await _userService.getUser(credential.user!.uid);
        if (exists == null) {
          final displayName = credential.user!.displayName ?? credential.user!.email?.split('@').first ?? 'User';
          final code = await SocialService().generateUniqueFriendCode(displayName);
          final userModel = UserModel(
            id: credential.user!.uid,
            email: credential.user!.email ?? '',
            name: displayName,
            facebookId: facebookId,
            friendCode: code,
          );
          await _userService.saveUser(userModel);
          _currentUserModel = userModel;
        } else {
          if (exists.facebookId != facebookId) {
            final updatedModel = exists.copyWith(facebookId: facebookId);
            await _userService.saveUser(updatedModel);
            _currentUserModel = updatedModel;
          } else {
            _currentUserModel = exists;
          }
        }
        // Đảm bảo pet collection tồn tại cho user (tạo mới nếu chưa có)
        await PetService().initializePet(credential.user!.uid);
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
    String activityLevel = 'Vừa phải',
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

      UserModel baseModel = _currentUserModel ?? UserModel(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        name: firebaseUser.displayName ?? firebaseUser.email?.split('@').first ?? 'User',
      );
      
      if (baseModel.friendCode.isEmpty || !RegExp(r'^[A-Z0-9]+$').hasMatch(baseModel.friendCode)) {
        final code = await SocialService().generateUniqueFriendCode(baseModel.name);
        baseModel = baseModel.copyWith(friendCode: code);
      }

      final updatedModel = baseModel.copyWith(
        birthYear: birthYear,
        gender: gender,
        heightCm: heightCm,
        weightKg: weightKg,
        isOnboarded: true,
        activityLevel: activityLevel,
      );

      await _userService.saveUser(updatedModel);
      await PetService().initializePet(firebaseUser.uid);
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

  /// Bỏ qua onboarding (lưu trạng thái đã bỏ qua lên Firestore)
  Future<bool> skipOnboarding() async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        _errorMessage = 'Không tìm thấy thông tin đăng nhập.';
        _setLoading(false);
        return false;
      }

      UserModel baseModel = _currentUserModel ?? UserModel(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        name: firebaseUser.displayName ?? firebaseUser.email?.split('@').first ?? 'User',
      );
      
      if (baseModel.friendCode.isEmpty || !RegExp(r'^[A-Z0-9]+$').hasMatch(baseModel.friendCode)) {
        final code = await SocialService().generateUniqueFriendCode(baseModel.name);
        baseModel = baseModel.copyWith(friendCode: code);
      }

      final updatedModel = baseModel.copyWith(
        isOnboarded: true,
      );

      await _userService.saveUser(updatedModel);
      await PetService().initializePet(firebaseUser.uid);
      _currentUserModel = updatedModel;
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Lỗi bỏ qua onboarding: $e';
      _setLoading(false);
      return false;
    }
  }

  /// Cập nhật thông tin cá nhân (Họ tên, Năm sinh, Giới tính, Chiều cao, Cân nặng, Cài đặt giấc ngủ, Tần suất tập luyện)
  Future<bool> updateProfile({
    required String name,
    required int birthYear,
    required String gender,
    required double heightCm,
    required double weightKg,
    String? targetBedtime,
    String? targetWakeTime,
    String? activityLevel,
    String? avatarUrl,
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

      UserModel baseModel = _currentUserModel ?? UserModel(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        name: name,
      );
      
      if (baseModel.friendCode.isEmpty || !RegExp(r'^[A-Z0-9]+$').hasMatch(baseModel.friendCode)) {
        final code = await SocialService().generateUniqueFriendCode(name);
        baseModel = baseModel.copyWith(friendCode: code);
      }

      final updatedModel = baseModel.copyWith(
        name: name,
        birthYear: birthYear,
        gender: gender,
        heightCm: heightCm,
        weightKg: weightKg,
        isOnboarded: true,
        targetBedtime: targetBedtime ?? baseModel.targetBedtime,
        targetWakeTime: targetWakeTime ?? baseModel.targetWakeTime,
        activityLevel: activityLevel ?? baseModel.activityLevel,
        avatarUrl: avatarUrl ?? baseModel.avatarUrl,
      );

      // Cập nhật local state trước để UI phản hồi lập tức
      _currentUserModel = updatedModel;
      notifyListeners();

      // Lưu lên Firestore với timeout 1 giây (nếu offline, Firestore sẽ tự động đồng bộ sau)
      try {
        await _userService.saveUser(updatedModel).timeout(const Duration(seconds: 1));
      } catch (e) {
        debugPrint('Firestore lưu offline/timeout: $e');
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = 'Lỗi cập nhật thông tin: $e';
      _setLoading(false);
      return false;
    }
  }

  /// Cập nhật riêng ảnh đại diện lên Firestore
  Future<bool> updateAvatar(String avatarUrl) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        _errorMessage = 'Không tìm thấy thông tin đăng nhập.';
        _setLoading(false);
        return false;
      }

      if (_currentUserModel == null) {
        _errorMessage = 'Thông tin người dùng chưa được tải.';
        _setLoading(false);
        return false;
      }

      final updatedModel = _currentUserModel!.copyWith(avatarUrl: avatarUrl);
      
      // Cập nhật local state trước để UI phản hồi lập tức
      _currentUserModel = updatedModel;
      notifyListeners();

      // Lưu lên Firestore với timeout 1 giây
      try {
        await _userService.saveUser(updatedModel).timeout(const Duration(seconds: 1));
      } catch (e) {
        debugPrint('Firestore lưu offline/timeout: $e');
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = 'Lỗi cập nhật ảnh đại diện: $e';
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

  /// Gửi email đặt lại mật khẩu
  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      if (email.isEmpty) {
        _errorMessage = 'Vui lòng nhập email';
        _setLoading(false);
        return false;
      }

      await _authService.sendPasswordResetEmail(email);
      _setLoading(false);
      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        _errorMessage = 'Tài khoản email này chưa được đăng ký.';
      } else if (e.code == 'invalid-email') {
        _errorMessage = 'Định dạng email không hợp lệ.';
      } else if (e.code == 'too-many-requests') {
        _errorMessage = 'Bạn đã gửi quá nhiều yêu cầu. Vui lòng thử lại sau.';
      } else {
        _errorMessage = e.message ?? 'Không thể gửi email đặt lại mật khẩu.';
      }
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'Đã xảy ra lỗi. Vui lòng thử lại.';
      _setLoading(false);
      return false;
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
