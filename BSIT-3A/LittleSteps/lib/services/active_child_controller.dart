import 'package:flutter/foundation.dart';

import '../models/child.dart';

/// A controller for managing the currently active child in the app.
class ActiveChildController extends ChangeNotifier {
  Child? _activeChild;

  /// Returns the currently active child, or null if none is chosen yet.
  Child? get activeChild => _activeChild;

  /// Sets the active child and notifies listeners of the change.
  void setActiveChild(Child child) {
    _activeChild = child;
    notifyListeners();
  }

  /// Clears the active child and notifies listeners of the change.
  void clearActiveChild() {
    _activeChild = null;
    notifyListeners();
  }
}
