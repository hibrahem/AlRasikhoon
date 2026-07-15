import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../data/repositories/auth_repository.dart';

/// Shows the shared sign-out confirmation dialog and, only when the user
/// confirms, signs the current session out.
///
/// Sign-out is destructive and always sits next to routine actions, so every
/// entry point — the الإعدادات screen and the admin AppBar (which has no
/// settings destination of its own) — funnels through this single gate so the
/// wording and behaviour stay identical across roles.
Future<void> confirmSignOut(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('هل تريد تسجيل الخروج؟'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(
            'تسجيل الخروج',
            style: TextStyle(color: AppColors.error),
          ),
        ),
      ],
    ),
  );

  if (confirmed ?? false) {
    await ref.read(authRepositoryProvider.notifier).signOut();
  }
}
