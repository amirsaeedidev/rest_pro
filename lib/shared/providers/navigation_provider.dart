import 'package:flutter/material.dart';

class NavigationProvider extends ChangeNotifier {
  // The customer app's primary Scaffold owns the hamburger Drawer.
  // Screens nested inside it must open this exact Scaffold, not their own Scaffold.
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  // 0 = cart, 1 = home, 2 = recent orders.
  int _selectedIndex = 1;
  final List<int> _history = [];

  int get selectedIndex => _selectedIndex;

  void setIndex(int index) {
    if (index < 0 || index > 2 || index == _selectedIndex) return;

    _history.add(_selectedIndex);
    // Bound history so repeated tab changes cannot grow memory indefinitely.
    if (_history.length > 30) _history.removeAt(0);

    _selectedIndex = index;
    notifyListeners();
  }

  /// Returns to the previously selected tab. At the first tab state,
  /// falls back to Home instead of allowing the app to exit.
  bool handleBack() {
    if (_history.isNotEmpty) {
      _selectedIndex = _history.removeLast();
      notifyListeners();
      return true;
    }

    if (_selectedIndex != 1) {
      _selectedIndex = 1;
      notifyListeners();
      return true;
    }

    // At Home there is no previous in-app page; keep the app open.
    return false;
  }
}
