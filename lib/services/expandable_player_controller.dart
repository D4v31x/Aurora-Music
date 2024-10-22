import 'package:flutter/material.dart';

class ExpandablePlayerController extends ChangeNotifier {
  bool _isExpanded = false;
  bool get isExpanded => _isExpanded;


  void expand() {
    _isExpanded = true;
    notifyListeners();
  }

  void collapse() {
    _isExpanded = false;
    notifyListeners();
  }

  void toggle() {
    _isExpanded = !_isExpanded;
    notifyListeners();
  }
}