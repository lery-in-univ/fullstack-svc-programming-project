/// Configuration for the QWERTY keyboard layout
class KeyboardConfig {
  /// Standard QWERTY keyboard layout
  static const List<List<String>> qwertyLayout = [
    ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
    ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
    ['z', 'x', 'c', 'v', 'b', 'n', 'm'],
    ['space', 'enter'],
  ];

  /// Numbers and special characters layout
  static const List<List<String>> symbolLayout = [
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['(', ')', '{', '}', ';', "'", ',', '+', '='],
    ['', '', '', '', '', '', ''],
    ['space', 'enter'],
  ];

  /// Special character mappings when shift is active
  static const Map<String, String> shiftMap = {};

  /// Special keys that have different behavior
  static const String backspaceKey = 'backspace';
  static const String shiftKey = 'shift';
  static const String spaceKey = 'space';
  static const String enterKey = 'enter';
  static const String symbolToggleKey = 'symbol_toggle';

  /// Key sizes
  static const double normalKeyHeight = 40.0;

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
