import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_card.dart';
import '../providers/telemetry_enabled_provider.dart';

/// Lets the user turn diagnostics off. Default is on, matching the revised
/// privacy policy.
class TelemetryToggle extends ConsumerWidget {
  const TelemetryToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(telemetryEnabledProvider);

    return AppCard(
      child: SwitchListTile(
        value: enabled,
        onChanged: (value) =>
            ref.read(telemetryEnabledProvider.notifier).setEnabled(value),
        title: const Text('إرسال تقارير الأعطال والاستخدام'),
        subtitle: const Text(
          'تساعدنا هذه التقارير على اكتشاف الأعطال وإصلاحها. '
          'لا تتضمن اسمك ولا بيانات حفظك.',
        ),
      ),
    );
  }
}
