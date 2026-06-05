import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthSensorService {
  StreamSubscription<StepCount>? _stepCountStream;
  
  // Hàm này sẽ trả về số bước chân mỗi khi người dùng bước đi
  void initPedometer(Function(int) onStepCountUpdated) async {
    // 1. Kiểm tra và xin quyền
    bool granted = await _checkActivityRecognitionPermission();
    if (!granted) {
      debugPrint("🚨 Người dùng từ chối cấp quyền đếm bước!");
      return;
    }

    // 2. Nếu đã có quyền, bắt đầu lắng nghe cảm biến của máy
    try {
      _stepCountStream = Pedometer.stepCountStream.listen(
        (StepCount event) {
          debugPrint("👣 Cảm biến bắt được: ${event.steps} bước");
          onStepCountUpdated(event.steps);
        },
        onError: (error) {
          debugPrint("🚨 Lỗi cảm biến đếm bước: $error");
        },
      );
    } catch (e) {
      debugPrint("🚨 Không thể khởi tạo Pedometer: $e");
    }
  }

  // Logic xin quyền an toàn
  Future<bool> _checkActivityRecognitionPermission() async {
    PermissionStatus status = await Permission.activityRecognition.status;
    
    if (status.isGranted) {
      return true;
    }

    // Nếu chưa cấp, hiện popup xin quyền
    status = await Permission.activityRecognition.request();
    return status.isGranted;
  }

  void dispose() {
    _stepCountStream?.cancel();
  }
}