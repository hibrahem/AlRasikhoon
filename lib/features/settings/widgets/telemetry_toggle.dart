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
        // Describes what the code actually does, not what we wish it did:
        // switching off stops both SDKs on the spot, while switching back on
        // re-initialises them and is only guaranteed complete after the app
        // is reopened. See web/privacy.html §2.د.
        subtitle: const Text(
          'تساعدنا هذه التقارير على اكتشاف الأعطال وإصلاحها. '
          'لا تتضمن اسمك ولا بيانات حفظك. '
          'وعند إيقاف الخيار يتوقف الإرسال فورًا، '
          'أما إعادة تشغيله فقد تحتاج إلى إعادة فتح التطبيق ليعمل بالكامل.',
        ),
      ),
    );
  }
}
