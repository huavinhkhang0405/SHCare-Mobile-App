import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class SecurityService {
  static const _storage = FlutterSecureStorage();
  static final _auth = LocalAuthentication();
  
  static const _pinKey = 'security_pin_code';

  static Future<bool> isBiometricsSupported() async {
    try {
      final canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      return false;
    }
  }

  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  static Future<bool> authenticateBiometrics(String localizedReason) async {
    try {
      final isSupported = await isBiometricsSupported();
      if (!isSupported) return false;

      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  static Future<void> savePIN(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
  }

  static Future<String?> getPIN() async {
    return await _storage.read(key: _pinKey);
  }

  static Future<void> clearPIN() async {
    await _storage.delete(key: _pinKey);
  }

  static Future<bool> verifyPIN(String pin) async {
    final savedPin = await getPIN();
    return savedPin == pin;
  }

  static Future<bool> hasPIN() async {
    final pin = await getPIN();
    return pin != null && pin.isNotEmpty;
  }
}
