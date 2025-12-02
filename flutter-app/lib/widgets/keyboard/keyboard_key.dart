import 'package:flutter/material.dart';

/// A single key widget for the keyboard
///
/// This widget represents an individual key on the keyboard that can be
/// tapped to trigger a callback. It supports visual feedback and different
/// styles based on key type.
class KeyboardKey extends StatelessWidget {
  /// The text to display on the key
  final String label;

  /// Callback function when the key is pressed
  final VoidCallback onPressed;

  /// Whether this is a special key (shift, backspace, etc.)
  final bool isSpecialKey;

  /// Whether shift is currently active (for visual feedback)
  final bool isShiftActive;

  /// Custom width for the key (optional)
  final double? width;

  /// Custom height for the key (optional)
  final double? height;

  const KeyboardKey({
    super.key,
    required this.label,
    required this.onPressed,
    this.isSpecialKey = false,
    this.isShiftActive = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine key colors based on state
    final backgroundColor = _getBackgroundColor(theme);

    return Container(
      width: width,
      height: height ?? 42.0,
      margin: const EdgeInsets.all(1.0),
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6.0),
        elevation: 0.0,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6.0),
          child: Center(child: _buildKeyContent(Colors.black)),
        ),
      ),
    );
  }

  /// Builds the content of the key (text or icon)
  Widget _buildKeyContent(Color textColor) {
    // Special icons for special keys
    if (label.toLowerCase() == 'backspace') {
      return Icon(Icons.backspace_outlined, color: textColor, size: 20.0);
    } else if (label.toLowerCase() == 'shift') {
      return Icon(Icons.arrow_upward, color: textColor, size: 20.0);
    } else if (label.toLowerCase() == 'space') {
      return const SizedBox.shrink(); // Empty for space key
    } else if (label.toLowerCase() == 'enter') {
      return Icon(Icons.keyboard_return, color: textColor, size: 20.0);
    }

    // Regular text key
    return Text(
      label,
      style: TextStyle(
        color: textColor,
        fontSize: 18.0,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  /// Determines the background color based on key state
  Color _getBackgroundColor(ThemeData theme) {
    if (isSpecialKey) {
      if (isShiftActive && label.toLowerCase() == 'shift') {
        return Colors.grey.shade500;
      }
      return Colors.grey.shade300;
    }
    return Colors.grey.shade100;
  }
}
