import 'package:flutter/material.dart';

/// Quản lý trạng thái xác thực người dùng.
/// Hỗ trợ đăng nhập bằng email/password, Google, Facebook.
class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _errorMessage;
  String _userName = '';
  String _userEmail = '';

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get userName => _userName;
  String get userEmail => _userEmail;

  // ─── Mock Test Accounts ──────────────────────────────────
  // Danh sách tài khoản mock để test đăng nhập.
  // Khi tích hợp Firebase Auth thật, xóa phần này.
  static const Map<String, _MockAccount> _mockAccounts = {
    'admin@shcare.vn': _MockAccount(
      password: 'admin123',
      name: 'Admin SHCare',
    ),
    'khang@shcare.vn': _MockAccount(
      password: 'khang123',
      name: 'Huỳnh Vĩnh Khang',
    ),
    'test@shcare.vn': _MockAccount(
      password: 'test1234',
      name: 'Tester SHCare',
    ),
    'demo@shcare.vn': _MockAccount(
      password: 'demo1234',
      name: 'Demo User',
    ),
  };

  /// Đăng nhập bằng email / password
  Future<bool> loginWithEmail(String email, String password) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      // Giả lập delay mạng
      await Future.delayed(const Duration(milliseconds: 1200));

      if (email.isEmpty || password.isEmpty) {
        _errorMessage = 'Vui lòng điền đầy đủ thông tin';
        _setLoading(false);
        return false;
      }

      if (password.length < 6) {
        _errorMessage = 'Mật khẩu phải có ít nhất 6 ký tự';
        _setLoading(false);
        return false;
      }

      // Kiểm tra trong danh sách mock accounts
      final normalizedEmail = email.toLowerCase().trim();
      final mockAccount = _mockAccounts[normalizedEmail];

      if (mockAccount == null) {
        _errorMessage = 'Tài khoản không tồn tại';
        _setLoading(false);
        return false;
      }

      if (mockAccount.password != password) {
        _errorMessage = 'Mật khẩu không chính xác';
        _setLoading(false);
        return false;
      }

      // Đăng nhập thành công
      _isLoggedIn = true;
      _userName = mockAccount.name;
      _userEmail = normalizedEmail;
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = 'Đã xảy ra lỗi. Vui lòng thử lại.';
      _setLoading(false);
      return false;
    }
  }

  /// Đăng ký tài khoản mới
  Future<bool> registerWithEmail(String name, String email, String password) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await Future.delayed(const Duration(milliseconds: 1200));

      if (name.isEmpty || email.isEmpty || password.isEmpty) {
        _errorMessage = 'Vui lòng điền đầy đủ thông tin';
        _setLoading(false);
        return false;
      }

      if (password.length < 6) {
        _errorMessage = 'Mật khẩu phải có ít nhất 6 ký tự';
        _setLoading(false);
        return false;
      }

      final normalizedEmail = email.toLowerCase().trim();

      // Kiểm tra email đã tồn tại
      if (_mockAccounts.containsKey(normalizedEmail)) {
        _errorMessage = 'Email này đã được đăng ký. Vui lòng đăng nhập.';
        _setLoading(false);
        return false;
      }

      // TODO: Tích hợp Firebase Auth thực tế
      // Đăng ký thành công (mock — chấp nhận mọi tài khoản mới)
      _isLoggedIn = true;
      _userName = name;
      _userEmail = normalizedEmail;
      _setLoading(false);
      return true;
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
      await Future.delayed(const Duration(milliseconds: 1500));
      // TODO: Tích hợp Google Sign-In thực tế
      _isLoggedIn = true;
      _userName = 'Google User';
      _userEmail = 'user@gmail.com';
      _setLoading(false);
      return true;
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
      await Future.delayed(const Duration(milliseconds: 1500));
      // TODO: Tích hợp Facebook Login thực tế
      _isLoggedIn = true;
      _userName = 'Facebook User';
      _userEmail = 'user@facebook.com';
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = 'Không thể đăng nhập bằng Facebook';
      _setLoading(false);
      return false;
    }
  }

  /// Đăng xuất
  void logout() {
    _isLoggedIn = false;
    _userName = '';
    _userEmail = '';
    _errorMessage = null;
    notifyListeners();
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

/// Cấu trúc nội bộ lưu thông tin tài khoản mock.
class _MockAccount {
  final String password;
  final String name;

  const _MockAccount({required this.password, required this.name});
}
