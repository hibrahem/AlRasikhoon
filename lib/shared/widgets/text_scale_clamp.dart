import 'package:flutter/widgets.dart';

/// Caps the device font-size setting for everything below it.
///
/// Wrapped around the whole app (see `AlRasikhoonApp`): moderate accessibility
/// scaling passes through, but an extreme setting (some Android skins offer
/// 2×) is held at [maxScaleFactor] — beyond it, dense Arabic layouts such as
/// the خطة الحفظ dialog degrade into mid-word line breaks.
class TextScaleClamp extends StatelessWidget {
  /// The largest text scale the app honors.
  static const double maxScaleFactor = 1.3;

  final Widget child;

  const TextScaleClamp({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: maxScaleFactor,
      child: child,
    );
  }
}
