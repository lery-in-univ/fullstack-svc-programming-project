import 'package:flutter/material.dart';

class SessionNotInitializedView extends StatelessWidget {
  final VoidCallback onInitialize;

  const SessionNotInitializedView({
    super.key,
    required this.onInitialize,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onInitialize,
      icon: const Icon(Icons.power_settings_new),
      label: const Text('세션 초기화'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(16.0),
      ),
    );
  }
}
