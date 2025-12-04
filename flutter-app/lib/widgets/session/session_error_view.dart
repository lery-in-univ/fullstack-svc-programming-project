import 'package:flutter/material.dart';

class SessionErrorView extends StatelessWidget {
  final String? errorMessage;
  final String? websocketErrorMessage;
  final VoidCallback onRetry;

  const SessionErrorView({
    super.key,
    this.errorMessage,
    this.websocketErrorMessage,
    required this.onRetry,
  });

  String get _displayErrorMessage {
    return websocketErrorMessage ?? errorMessage ?? '알 수 없는 오류';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Card(
          color: Colors.red.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 8),
                Text(
                  '오류 발생',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.red),
                ),
                const SizedBox(height: 8),
                Text(
                  _displayErrorMessage,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('재시도'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(16.0),
          ),
        ),
      ],
    );
  }
}
