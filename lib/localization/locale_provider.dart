import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class LocaleProvider extends InheritedWidget {
  final ui.Locale locale;
  final Function(ui.Locale) setLocale;

  const LocaleProvider({
    super.key,
    required this.locale,
    required this.setLocale,
    required super.child,
  });

  static LocaleProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LocaleProvider>();
  }

  @override
  bool updateShouldNotify(LocaleProvider old) {
    return locale != old.locale;
  }
}

