// lib/shared/widgets/states/loading_state.dart
import 'package:flutter/material.dart';
import 'shimmer_box.dart';

class LoadingState extends StatelessWidget {
  final int lines;
  const LoadingState({this.lines = 3, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < lines; i++) ...[
            const ShimmerBox(width: double.infinity, height: 72),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
