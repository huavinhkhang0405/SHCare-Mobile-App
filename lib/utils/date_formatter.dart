enum DayPart { morning, afternoon, evening, night }

class DateFormatter {
  const DateFormatter._();

  static const List<String> _weekdaysShortVi = <String>[
    'Th 2',
    'Th 3',
    'Th 4',
    'Th 5',
    'Th 6',
    'Th 7',
    'CN',
  ];

  static const List<String> _weekdaysFullVi = <String>[
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ nhật',
  ];

  static DateTime nowLocal() => DateTime.now().toLocal();

  static DayPart dayPartOf(DateTime dateTime) {
    final hour = dateTime.toLocal().hour;

    if (hour >= 5 && hour < 12) {
      return DayPart.morning;
    }
    if (hour >= 12 && hour < 18) {
      return DayPart.afternoon;
    }
    if (hour >= 18 && hour < 22) {
      return DayPart.evening;
    }

    return DayPart.night;
  }

  static String dayPartLabelVi(DateTime dateTime) {
    switch (dayPartOf(dateTime)) {
      case DayPart.morning:
        return 'Sáng';
      case DayPart.afternoon:
        return 'Chiều';
      case DayPart.evening:
        return 'Tối';
      case DayPart.night:
        return 'Khuya';
    }
  }

  static String greetingVi(DateTime dateTime) {
    switch (dayPartOf(dateTime)) {
      case DayPart.morning:
        return 'Chào buổi sáng';
      case DayPart.afternoon:
        return 'Chào buổi chiều';
      case DayPart.evening:
      case DayPart.night:
        return 'Chào buổi tối';
    }
  }

  static String formatDayMonth(DateTime dateTime) {
    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  static String formatDayMonthWithWeekday(
    DateTime dateTime, {
    bool shortWeekday = true,
  }) {
    final local = dateTime.toLocal();
    final weekday = shortWeekday
        ? _weekdaysShortVi[local.weekday - 1]
        : _weekdaysFullVi[local.weekday - 1];
    return '$weekday, ${formatDayMonth(local)}';
  }

  static String formatHourMinute(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
