import 'package:flutter/material.dart';

class ExpandablePlayerController extends ChangeNotifier {
  bool _isExpanded = false;
  bool _isVisible = false;

  bool get isExpanded => _isExpanded;
  bool get isVisible => _isVisible;

  void expand() {
    _isExpanded = true;
    _isVisible = true;
    notifyListeners();
  }

  void collapse() {
    _isExpanded = false;
    notifyListeners();
  }

  void show() {
    _isVisible = true;
    notifyListeners();
  }

  void hide() {
    _isVisible = false;
    _isExpanded = false;
    notifyListeners();
  }

  void toggle() {
    _isExpanded = !_isExpanded;
    notifyListeners();
  }
}