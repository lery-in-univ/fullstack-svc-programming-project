import 'package:flutter/material.dart';
import '../../models/keyboard_config.dart';
import 'keyboard_key.dart';

/// A row of keyboard keys
///
/// This widget represents a single row in the keyboard layout, containing
/// multiple [KeyboardKey] widgets arranged horizontally.
class KeyboardRow extends StatelessWidget {
  /// List of key labels in this row
  final List<String> keys;

  /// Callback function when a key is pressed
  final void Function(String key) onKeyPressed;

  /// Whether shift is currently active
  final bool isShiftActive;

  /// Custom key width (optional)
  final double? keyWidth;

  /// Custom key height (optional)
  final double? keyHeight;

  const KeyboardRow({
    super.key,
    required this.keys,
    required this.onKeyPressed,
    this.isShiftActive = false,
    this.keyWidth,
    this.keyHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((key) {
        return KeyboardKey(
          label: _getDisplayLabel(key),
          onPressed: () => onKeyPressed(key),
          isSpecialKey: _isSpecialKey(key),
          isShiftActive: isShiftActive,
          width: _getKeyWidth(key),
          height: keyHeight,
        );
      }).toList(),
    );
  }

  /// Gets the display label for the key
  String _getDisplayLabel(String key) {
    if (key.toLowerCase() == 'backspace' ||
        key.toLowerCase() == 'shift' ||
        key.toLowerCase() == 'space' ||
        key.toLowerCase() == 'enter' ||
        key.toLowerCase() == 'symbol_toggle') {
      return key;
    }
    // Check if key has a shift mapping
    if (isShiftActive && KeyboardConfig.shiftMap.containsKey(key)) {
      return KeyboardConfig.shiftMap[key]!;
    }
    return isShiftActive ? key.toUpperCase() : key;
  }

  /// Determines if the key is a special key
  bool _isSpecialKey(String key) {
    final lowerKey = key.toLowerCase();
    return lowerKey == 'backspace' ||
        lowerKey == 'shift' ||
        lowerKey == 'space' ||
        lowerKey == 'enter' ||
        lowerKey == 'symbol_toggle';
  }

  /// Gets the width for a specific key based on ratios
  double _getKeyWidth(String key) {
    final baseWidth = keyWidth ?? 35.0;
    final lowerKey = key.toLowerCase();

    if (lowerKey == KeyboardConfig.spaceKey) {
      return baseWidth * KeyboardConfig.spaceKeyRatio;
    } else if (lowerKey == KeyboardConfig.backspaceKey ||
        lowerKey == KeyboardConfig.shiftKey ||
        lowerKey == KeyboardConfig.enterKey ||
        lowerKey == KeyboardConfig.symbolToggleKey) {
      return baseWidth * KeyboardConfig.specialKeyRatio;
    }
    return baseWidth * KeyboardConfig.normalKeyRatio;
  }
}
