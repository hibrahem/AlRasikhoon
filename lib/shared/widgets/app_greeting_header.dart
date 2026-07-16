import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_tokens.dart';

/// Scrolling greeting header for dashboard roots. Sits directly on the page
/// (no bar, no fill), scrolls away with content. Eyebrow `greeting` + bold
/// Amiri `title` on the start side; `trailing` (avatar / chip) on the end side.
class AppGreetingHeader extends StatelessWidget {
  final String? greeting;
  final String title;
  final Widget? trailing;

  const AppGreetingHeader({
    super.key,
    this.greeting,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (greeting != null)
                  Text(
                    greeting!,
                    style: GoogleFonts.cairo(fontSize: 12, color: tokens.sepia),
                  ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: GoogleFonts.amiri(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: tokens.ink,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
