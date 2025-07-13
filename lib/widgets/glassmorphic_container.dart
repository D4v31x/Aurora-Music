import 'package:flutter/material.dart';
import 'dart:ui';

Widget glassmorphicContainer({
  required Widget child,
  double? width,
  EdgeInsetsGeometry? padding,
}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(15),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Builder(
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            width: width,
            padding: padding,
            decoration: BoxDecoration(
              color: isDark 
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isDark 
                  ? Colors.white.withOpacity(0.2)
                  : Colors.black.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: child,
          );
        },
      ),
    ),
  );
}