import 'package:flutter/foundation.dart';

/// Manages the state of the keyboard
///
/// This class tracks keyboard state such as whether shift is active
/// and provides methods to update the state.
class KeyboardState extends ChangeNotifier {
  bool _isShiftActive = false;
  bool _isSymbolMode = false;

  /// Whether shift is currently active
  bool get isShiftActive => _isShiftActive;

  /// Whether symbol mode is currently active
  bool get isSymbolMode => _isSymbolMode;

  /// Toggles the shift state
  void toggleShift() {
    _isShiftActive = !_isShiftActive;
    notifyListeners();
  }

  /// Toggles the symbol mode state
  void toggleSymbolMode() {
    _isSymbolMode = !_isSymbolMode;
    notifyListeners();
  }

  /// Sets shift to active
  void activateShift() {
    if (!_isShiftActive) {
      _isShiftActive = true;
      notifyListeners();
    }
  }

  /// Sets shift to inactive
  void deactivateShift() {
    if (_isShiftActive) {
      _isShiftActive = false;
      notifyListeners();
    }
  }

  /// Resets the keyboard state to default
  void reset() {
    _isShiftActive = false;
    _isSymbolMode = false;
    notifyListeners();
  }
}
