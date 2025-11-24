import 'package:flutter/material.dart';
import '../../models/key_event.dart';
import '../../models/keyboard_config.dart';
import 'keyboard_row.dart';
import 'keyboard_state.dart';

/// A QWERTY-style keyboard widget
///
/// This widget displays a full QWERTY keyboard layout with support for
/// uppercase/lowercase letters, backspace, shift, and space keys.
///
/// Example usage:
/// ```dart
/// QwertyKeyboard(
///   onKeyPressed: (KeyboardEvent event) {
///     // Handle key press
///   },
/// )
/// ```
class QwertyKeyboard extends StatefulWidget {
  /// Callback function when a key is pressed
  final void Function(KeyboardEvent event) onKeyPressed;

  const QwertyKeyboard({
    super.key,
    required this.onKeyPressed,
  });

  @override
  State<QwertyKeyboard> createState() => _QwertyKeyboardState();
}

class _QwertyKeyboardState extends State<QwertyKeyboard> {
  late final KeyboardState _keyboardState;

  @override
  void initState() {
    super.initState();
    _keyboardState = KeyboardState();
    _keyboardState.addListener(_onKeyboardStateChanged);
  }

  @override
  void dispose() {
    _keyboardState.removeListener(_onKeyboardStateChanged);
    _keyboardState.dispose();
    super.dispose();
  }

  void _onKeyboardStateChanged() {
    setState(() {});
  }

  void _handleKeyPress(String key) {
    final lowerKey = key.toLowerCase();

    // Handle special keys
    if (lowerKey == KeyboardConfig.shiftKey) {
      _keyboardState.toggleShift();
      widget.onKeyPressed(KeyboardEvent(
        character: '',
        type: KeyType.shift,
        isShiftActive: _keyboardState.isShiftActive,
      ));
      return;
    }

    if (lowerKey == KeyboardConfig.backspaceKey) {
      widget.onKeyPressed(const KeyboardEvent(
        character: '',
        type: KeyType.backspace,
      ));
      return;
    }

    if (lowerKey == KeyboardConfig.spaceKey) {
      widget.onKeyPressed(const KeyboardEvent(
        character: ' ',
        type: KeyType.space,
      ));
      return;
    }

    // Handle normal character keys
    final character = _keyboardState.isShiftActive ? key.toUpperCase() : key;
    widget.onKeyPressed(KeyboardEvent(
      character: character,
      type: KeyType.normal,
      isShiftActive: _keyboardState.isShiftActive,
    ));
  }

  /// Calculates the base key width based on screen width
  double _calculateBaseKeyWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth -
        (KeyboardConfig.keyboardHorizontalPadding * 2) -
        (KeyboardConfig.keyPadding * 2 * 10); // padding for 10 keys

    // Row 1 has 10 keys - use this as the base calculation
    return availableWidth / 10;
  }

  @override
  Widget build(BuildContext context) {
    final baseKeyWidth = _calculateBaseKeyWidth(context);

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Q W E R T Y U I O P
          KeyboardRow(
            keys: KeyboardConfig.qwertyLayout[0],
            onKeyPressed: _handleKeyPress,
            isShiftActive: _keyboardState.isShiftActive,
            keyWidth: baseKeyWidth,
          ),
          const SizedBox(height: KeyboardConfig.rowSpacing),

          // Row 2: A S D F G H J K L
          KeyboardRow(
            keys: KeyboardConfig.qwertyLayout[1],
            onKeyPressed: _handleKeyPress,
            isShiftActive: _keyboardState.isShiftActive,
            keyWidth: baseKeyWidth,
          ),
          const SizedBox(height: KeyboardConfig.rowSpacing),

          // Row 3: [Shift] Z X C V B N M [Backspace]
          KeyboardRow(
            keys: [
              KeyboardConfig.shiftKey,
              ...KeyboardConfig.qwertyLayout[2],
              KeyboardConfig.backspaceKey
            ],
            onKeyPressed: _handleKeyPress,
            isShiftActive: _keyboardState.isShiftActive,
            keyWidth: baseKeyWidth,
          ),
          const SizedBox(height: KeyboardConfig.rowSpacing),

          // Row 4: [Space]
          KeyboardRow(
            keys: [KeyboardConfig.spaceKey],
            onKeyPressed: _handleKeyPress,
            isShiftActive: _keyboardState.isShiftActive,
            keyWidth: baseKeyWidth,
          ),
        ],
      ),
    );
  }
}
