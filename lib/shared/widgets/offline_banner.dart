import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_tokens.dart';
import '../providers/connectivity_provider.dart';

/// Wraps the whole app (mounted in the root builder, above the router) and
/// shows a slim banner while the device has no network. Every role sees it:
/// offline browsing is app-wide, and the offline-capable saves (sessions,
/// exams) tell the user their work is kept locally and synced later.
class OfflineBannerHost extends ConsumerWidget {
  final Widget child;

  const OfflineBannerHost({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isConnectedProvider);
    final tokens = context.tokens;

    return Column(
      children: [
        if (!isOnline)
          Material(
            // The palette's warning hue — the same role tokens.gold plays on
            // the exam result screen — with ink for readable text on it.
            color: tokens.gold,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_off, size: 16, color: tokens.ink),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'أنت غير متصل — سيتم الحفظ محليًا والمزامنة لاحقًا',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: child),
      ],
    );
  }
}
