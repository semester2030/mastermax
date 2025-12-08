import 'package:flutter/material.dart';

class RealEstateAndCarsProvider extends ChangeNotifier {
  bool _isCarTab = false;
  bool get isCarTab => _isCarTab;
  
  void setCarTab(bool value) {
    if (_isCarTab != value) {
      _isCarTab = value;
      notifyListeners();
    }
  }
} 