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
      child: Container(
        width: width,
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: child,
      ),
    ),
  );
}