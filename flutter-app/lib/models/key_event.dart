/// Represents different types of keyboard keys
enum KeyType {
  /// Normal alphanumeric or special character key
  normal,

  /// Backspace key for deleting characters
  backspace,

  /// Shift key for toggling case
  shift,

  /// Space key
  space,
}

/// Represents a keyboard key press event
class KeyboardEvent {
  /// The character associated with this key press
  final String character;

  /// The type of key that was pressed
  final KeyType type;

  /// Whether shift is currently active
  final bool isShiftActive;

  const KeyboardEvent({
    required this.character,
    required this.type,
    this.isShiftActive = false,
  });

  @override
  String toString() {
    return 'KeyboardEvent(character: $character, type: $type, isShiftActive: $isShiftActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is KeyboardEvent &&
      other.character == character &&
      other.type == type &&
      other.isShiftActive == isShiftActive;
  }

  @override
  int get hashCode => character.hashCode ^ type.hashCode ^ isShiftActive.hashCode;
}
