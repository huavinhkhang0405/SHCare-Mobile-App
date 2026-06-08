import 'package:flutter/material.dart';
import '../providers/health_provider.dart';

class SleepConfirmationBottomSheet extends StatefulWidget {
  final HealthProvider healthData;

  const SleepConfirmationBottomSheet({super.key, required this.healthData});

  @override
  State<SleepConfirmationBottomSheet> createState() => _SleepConfirmationBottomSheetState();
}

class _SleepConfirmationBottomSheetState extends State<SleepConfirmationBottomSheet> {
  late DateTime _start;
  late DateTime _wake;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    // Ưu tiên confirmedSleepStart/Wake trước để giữ nguyên trạng thái khi mở lại sheet
    _start = widget.healthData.confirmedSleepStart ?? 
             widget.healthData.sleepStartToConfirm ?? 
             DateTime.now().subtract(const Duration(hours: 8));
    _wake = widget.healthData.confirmedSleepWake ?? 
            widget.healthData.sleepWakeToConfirm ?? 
            DateTime.now();
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    return '$hours tiếng $minutes phút';
  }

  Duration get _sleepDuration {
    DateTime normalizedStart = _start;
    DateTime normalizedWake = _wake;
    if (normalizedWake.isBefore(normalizedStart)) {
      normalizedWake = normalizedWake.add(const Duration(days: 1));
    }
    return normalizedWake.difference(normalizedStart);
  }

  Future<void> _selectStartTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
      helpText: 'Chọn giờ bắt đầu ngủ',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFD7B56D),
              onPrimary: Colors.black,
              surface: Color(0xFF162033),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        final newStart = DateTime(_start.year, _start.month, _start.day, picked.hour, picked.minute);
        _start = widget.healthData.normalizeSleepTimes(newStart, _wake);
        _isEditing = true;
      });
    }
  }

  Future<void> _selectWakeTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_wake),
      helpText: 'Chọn giờ thức dậy',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFD7B56D),
              onPrimary: Colors.black,
              surface: Color(0xFF162033),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        final newWake = DateTime(_wake.year, _wake.month, _wake.day, picked.hour, picked.minute);
        _wake = widget.healthData.normalizeSleepTimes(_start, newWake);
        _isEditing = true;
      });
    }
  }

  void _save() {
    // Đóng sheet ngay lập tức để tránh độ trễ cảm ứng & lag
    Navigator.pop(context);
    widget.healthData.confirmSleep(_start, _wake);
    
    // Hiển thị thông báo SnackBar xác nhận
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFFD7B56D)),
            SizedBox(width: 8),
            Text('😴 Xác nhận giờ ngủ thành công!'),
          ],
        ),
        backgroundColor: Color(0xFF162033),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0C121E),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Row(
            children: [
              Icon(Icons.nightlight_round, color: Color(0xFFD7B56D), size: 24),
              SizedBox(width: 8),
              Text(
                'XÁC NHẬN GIỜ NGỦ',
                style: TextStyle(
                  color: Color(0xFFF4E2B6),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Nhấn vào các khung giờ bên dưới để điều chỉnh nếu có sự sai lệch với thực tế giấc ngủ của bạn.',
            style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BẮT ĐẦU NGỦ',
                      style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Material(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: const Color(0xFFD7B56D).withValues(alpha: 0.3)),
                      ),
                      child: InkWell(
                        onTap: () => _selectStartTime(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          alignment: Alignment.center,
                          child: Text(
                            _formatTime(_start),
                            style: const TextStyle(color: Color(0xFFD7B56D), fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'THỨC DẬY',
                      style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Material(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: const Color(0xFFD7B56D).withValues(alpha: 0.3)),
                      ),
                      child: InkWell(
                        onTap: () => _selectWakeTime(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          alignment: Alignment.center,
                          child: Text(
                            _formatTime(_wake),
                            style: const TextStyle(color: Color(0xFFD7B56D), fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Tổng thời gian ngủ: ${_formatDuration(_sleepDuration)}',
              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD7B56D),
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: Text(
              _isEditing ? 'Lưu thay đổi' : 'Chính xác, lưu lại',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Đóng',
              style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
