import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  late Map<String, String> _localizedStrings;

  Future<bool> load() async {
    try {
      String jsonString = await rootBundle.loadString('assets/data/${locale.languageCode}.json');
      Map<String, dynamic> jsonMap = json.decode(jsonString);
      _localizedStrings = jsonMap.map((key, value) {
        return MapEntry(key, value.toString());
      });
      return true;
    } catch (e) {
      debugPrint('Error loading translations for ${locale.languageCode}: $e');
      _localizedStrings = {};
      return false;
    }
  }

  String translate(String key, {Map<String, String>? arguments}) {
    String value = _localizedStrings[key] ?? key;
    if (arguments != null) {
      arguments.forEach((key, val) {
        value = value.replaceAll('{$key}', val);
      });
    }
    return value;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['vi', 'en', 'ja', 'ko', 'zh'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(LocalizationsDelegate<AppLocalizations> old) => false;
}

extension LocalizationExtension on BuildContext {
  String tr(String key, {Map<String, String>? arguments}) {
    return AppLocalizations.of(this)?.translate(key, arguments: arguments) ?? key;
  }
}
