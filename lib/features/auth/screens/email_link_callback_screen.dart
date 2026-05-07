import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_text_field.dart';

/// Landing screen for Firebase email-link sign-in.
///
/// The email contains a link whose `continueUrl` is configured to land here
/// (see `ActionCodeSettings.url` in [AuthRepository]). On both web and mobile,
/// the URL carries `mode=signIn` and `oobCode` query parameters that Firebase
/// uses to complete authentication.
///
/// On mobile the deep link is also delivered to [AuthRepository] via
/// `app_links`; this screen still handles the case where the link is opened
/// while the app is already running and routed here.
class EmailLinkCallbackScreen extends ConsumerStatefulWidget {
  /// Optional override used by the router; when null we fall back to
  /// `Uri.base` (web) or read the route's `state.uri` upstream.
  final Uri? link;

  const EmailLinkCallbackScreen({super.key, this.link});

  @override
  ConsumerState<EmailLinkCallbackScreen> createState() =>
      _EmailLinkCallbackScreenState();
}

class _EmailLinkCallbackScreenState
    extends ConsumerState<EmailLinkCallbackScreen> {
  bool _started = false;
  bool _promptShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _completeSignIn());
  }

  Future<void> _completeSignIn() async {
    if (_started) return;
    _started = true;

    final link = widget.link?.toString() ?? (kIsWeb ? Uri.base.toString() : '');
    if (link.isEmpty) {
      _bailWithError('الرابط غير صالح');
      return;
    }

    await ref.read(authRepositoryProvider.notifier).signInWithEmailLink(link);
  }

  void _bailWithError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
    context.go(AppRoutes.login);
  }

  Future<void> _promptForEmail() async {
    if (_promptShown) return;
    _promptShown = true;

    final emailController = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('أدخل بريدك الإلكتروني'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('يرجى إدخال البريد الإلكتروني لإكمال تسجيل الدخول'),
            const SizedBox(height: 16),
            AppEmailField(
              controller: emailController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (value) =>
                  Navigator.of(dialogContext).pop(value.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(emailController.text.trim()),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (email == null || email.isEmpty) {
      context.go(AppRoutes.login);
      return;
    }

    final result = await ref
        .read(authRepositoryProvider.notifier)
        .signInWithPendingLink(email);

    if (!mounted) return;

    if (result == null) {
      final error = ref.read(authRepositoryProvider).error;
      if (error == 'account_not_found') {
        context.go(AppRoutes.accountNotFound);
      } else {
        _bailWithError(error ?? 'فشل تسجيل الدخول');
      }
    }
    // On success, the router redirect routes to the user's dashboard.
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authRepositoryProvider);

    if (authState.error == 'email_prompt_needed') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _promptForEmail());
    } else if (authState.error == 'account_not_found') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.accountNotFound);
      });
    } else if (authState.error != null && _started && !authState.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _bailWithError(authState.error!);
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                'جاري تسجيل الدخول...',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
