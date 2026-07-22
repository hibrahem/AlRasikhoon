import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';

/// "بانتظار المزامنة" — marks a record that was saved offline on this device
/// and is still in Firestore's local write queue. Clears on its own once the
/// write reaches the server (the reconnect refresh refetches with
/// `hasPendingWrites == false`), so the chip needs no dismiss affordance.
class PendingSyncChip extends StatelessWidget {
  const PendingSyncChip({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tokens.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.gold),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_upload_outlined, size: 12, color: tokens.ink),
          const SizedBox(width: 4),
          Text(
            'بانتظار المزامنة',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: tokens.ink),
          ),
        ],
      ),
    );
  }
}
