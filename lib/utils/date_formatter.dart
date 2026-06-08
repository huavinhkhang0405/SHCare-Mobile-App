import 'package:flutter/material.dart';
import '../core/config/app_localizations.dart';

enum DayPart { morning, afternoon, evening, night }

class DateFormatter {
  const DateFormatter._();

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

  static String dayPartLabel(DateTime dateTime, BuildContext context) {
    switch (dayPartOf(dateTime)) {
      case DayPart.morning:
        return context.tr('morning');
      case DayPart.afternoon:
        return context.tr('afternoon');
      case DayPart.evening:
        return context.tr('evening');
      case DayPart.night:
        return context.tr('night');
    }
  }

  static String greeting(DateTime dateTime, BuildContext context) {
    switch (dayPartOf(dateTime)) {
      case DayPart.morning:
        return context.tr('morning_greeting');
      case DayPart.afternoon:
        return context.tr('afternoon_greeting');
      case DayPart.evening:
      case DayPart.night:
        return context.tr('evening_greeting');
    }
  }

  static String formatDayMonth(DateTime dateTime) {
    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  static String formatDayMonthWithWeekday(
    DateTime dateTime,
    BuildContext context, {
    bool shortWeekday = true,
  }) {
    final local = dateTime.toLocal();
    final String key = shortWeekday
        ? 'weekday_short_${local.weekday}'
        : 'weekday_full_${local.weekday}';
    final weekday = context.tr(key);
    return '$weekday, ${formatDayMonth(local)}';
  }

  static String formatHourMinute(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
