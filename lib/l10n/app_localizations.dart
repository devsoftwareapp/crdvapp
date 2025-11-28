import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  Map<String, String>? _localizedStrings;

  Future<bool> load() async {
    final String jsonString = await _loadJsonString();
    final Map<String, dynamic> jsonMap = json.decode(jsonString);

    _localizedStrings = jsonMap.map((key, value) {
      return MapEntry(key, value.toString());
    });

    return true;
  }

  Future<String> _loadJsonString() async {
    try {
      // ARB dosyasını yükle - assets/l10n/ klasöründen
      final String languageCode = locale.languageCode;
      final String countryCode = locale.countryCode ?? '';
      String fileName = 'intl_$languageCode';
      
      if (countryCode.isNotEmpty) {
        fileName = 'intl_${languageCode}_$countryCode';
      }
      
      return await rootBundle.loadString('assets/l10n/$fileName.arb');
    } catch (e) {
      // Fallback to English
      return await rootBundle.loadString('assets/l10n/intl_en_US.arb');
    }
  }

  String translate(String key) {
    return _localizedStrings?[key] ?? '**$key**';
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return [
      'en', 'tr', 'ar', 'cs', 'da', 'de', 'el', 'es', 'fa', 
      'fi', 'fr', 'hi', 'id', 'it', 'ja', 'ko', 'nl', 'no', 'pl', 
      'pt', 'ru', 'sv', 'th', 'uk', 'vi', 'zh'
    ].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
