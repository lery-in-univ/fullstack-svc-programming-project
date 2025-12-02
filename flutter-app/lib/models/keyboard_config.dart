/// Configuration for the QWERTY keyboard layout
class KeyboardConfig {
  /// Standard QWERTY keyboard layout with special characters
  static const List<List<String>> qwertyLayout = [
    ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
    ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
    ['z', 'x', 'c', 'v', 'b', 'n', 'm'],
    ['(', ')', 'space', ';', "'", 'enter'],
  ];

  /// Special character mappings when shift is active
  static const Map<String, String> shiftMap = {
    '(': '{',
    ')': '}',
  };

  /// Special keys that have different behavior
  static const String backspaceKey = 'backspace';
  static const String shiftKey = 'shift';
  static const String spaceKey = 'space';
  static const String enterKey = 'enter';

  /// Key sizes
  static const double normalKeyHeight = 42.0;

  /// Key width ratios (relative to base key width)
  static const double normalKeyRatio = 1.0;
  static const double specialKeyRatio = 1.5; // backspace, shift
  static const double spaceKeyRatio = 5.0;

  /// Key spacing
  static const double keyPadding = 4.0;
  static const double rowSpacing = 8.0;

  /// Keyboard padding
  static const double keyboardHorizontalPadding = 0.0;
}
