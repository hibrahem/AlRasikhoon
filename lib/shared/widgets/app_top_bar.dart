import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';

/// Slim, page-colored top bar for list & detail screens. Blends into the body
/// (no green slab), start-aligned title, optional actions, optional hairline.
/// Inherits colors/typography from the global AppBarTheme; adds only the
/// hairline. Use directly: `appBar: AppTopBar(title: '...')`.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showDivider;

  const AppTopBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.showDivider = true,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (showDivider ? 1 : 0));

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AppBar(
      title: Text(title),
      leading: leading,
      actions: actions,
      bottom: showDivider
          ? PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: tokens.hairline),
            )
          : null,
    );
  }
}
