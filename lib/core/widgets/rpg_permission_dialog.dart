import 'package:flutter/material.dart';
import '../../services/screen_time_service.dart';

void showRpgPermissionDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF0C121E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFD7B56D), width: 2),
      ),
      title: const Row(
        children: [
          Icon(Icons.shield_outlined, color: Color(0xFFD7B56D), size: 26),
          SizedBox(width: 8),
          Text(
            'THỬ THÁCH RỜI MÀN HÌNH',
            style: TextStyle(
              color: Color(0xFFF4E2B6),
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🐉', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF162033),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFD7B56D).withOpacity(0.25),
                    ),
                  ),
                  child: const Text(
                    'Để kiểm chứng cậu có thực sự rời điện thoại, mình cần quyền xem dữ liệu dùng app hệ thống. Vui lòng cấp quyền giúp mình nhé!',
                    style: TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Hướng dẫn cấp quyền:\n1. Chọn "Đi đến Cài đặt" bên dưới.\n2. Chọn ứng dụng "SHCare" trong danh sách.\n3. Gạt bật công tắc "Cho phép truy cập dữ liệu sử dụng".',
            style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Để sau',
            style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold),
          ),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            await ScreenTimeService.openUsageSettings();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD7B56D),
            foregroundColor: Colors.black87,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text(
            'Đi đến Cài đặt',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}
