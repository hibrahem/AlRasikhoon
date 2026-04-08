import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  String? _emailError;
  bool _isGoogleLoading = false;
  bool _linkSent = false;
  bool _linkChecked = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);

    final authRepo = ref.read(authRepositoryProvider.notifier);
    await authRepo.signInWithGoogle();

    if (!mounted) return;

    final authState = ref.read(authRepositoryProvider);

    if (authState.error == 'account_not_found') {
      context.go(AppRoutes.accountNotFound);
      return;
    }

    if (authState.error != null && authState.error != 'تم إلغاء تسجيل الدخول') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authState.error!),
          backgroundColor: AppColors.error,
        ),
      );
    }

    setState(() => _isGoogleLoading = false);
  }

  Future<void> _handleSendLink() async {
    final emailError = Validators.validateEmail(_emailController.text);
    if (emailError != null) {
      setState(() => _emailError = emailError);
      return;
    }
    setState(() => _emailError = null);

    final authRepo = ref.read(authRepositoryProvider.notifier);
    await authRepo.sendSignInLink(_emailController.text.trim());

    if (!mounted) return;

    final authState = ref.read(authRepositoryProvider);

    if (authState.emailLinkSent) {
      setState(() => _linkSent = true);
    } else if (authState.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authState.error!),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _handleEmailPromptNeeded() {
    // Cross-device: user clicked email link but email not stored locally
    final emailController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
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
              onSubmitted: (_) {
                Navigator.of(context).pop();
                _completeSignInWithEmail(emailController.text.trim());
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _completeSignInWithEmail(emailController.text.trim());
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeSignInWithEmail(String email) async {
    if (email.isEmpty) return;
    final authRepo = ref.read(authRepositoryProvider.notifier);
    await authRepo.signInWithPendingLink(email);

    if (!mounted) return;

    final authState = ref.read(authRepositoryProvider);
    if (authState.error == 'account_not_found') {
      context.go(AppRoutes.accountNotFound);
    } else if (authState.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authState.error!),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Web fallback: check if the current URL is a sign-in link.
  /// This handles the case where the deep link listener in AuthRepository
  /// missed the link due to initialization timing.
  void _checkForEmailLink() {
    if (!kIsWeb) return;
    final link = Uri.base.toString();
    ref.read(authRepositoryProvider.notifier).signInWithEmailLink(link);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authRepositoryProvider);

    // Web fallback: check URL for sign-in link on first build
    if (kIsWeb && !_linkChecked) {
      _linkChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkForEmailLink();
      });
    }

    // Handle cross-device email prompt
    if (authState.error == 'email_prompt_needed') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleEmailPromptNeeded();
      });
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _linkSent ? _buildLinkSentView() : _buildFormView(authState),
        ),
      ),
    );
  }

  Widget _buildFormView(AuthState authState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        // Logo and title
        Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.menu_book,
                size: 50,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'الراسخون',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'تطبيق حفظ القرآن الكريم',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 48),

        // Google Sign In Button
        _GoogleSignInButton(
          onPressed: _handleGoogleSignIn,
          isLoading: _isGoogleLoading,
        ),
        const SizedBox(height: 24),

        // Divider with "or"
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'أو',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 24),

        // Email field
        AppEmailField(
          controller: _emailController,
          errorText: _emailError,
          autofocus: false,
          textInputAction: TextInputAction.done,
          onChanged: (_) {
            if (_emailError != null) {
              setState(() => _emailError = null);
            }
          },
          onSubmitted: (_) => _handleSendLink(),
        ),
        const SizedBox(height: 24),

        // Send link button
        AppButton(
          text: 'إرسال رابط الدخول',
          onPressed: _handleSendLink,
          isLoading: authState.isLoading && !_isGoogleLoading,
          isFullWidth: true,
          size: AppButtonSize.large,
        ),
        const SizedBox(height: 32),

        // Footer
        Text(
          'يجب أن يكون لديك حساب مسجل مسبقاً',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildLinkSentView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 80),
        // Success icon
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read,
            size: 50,
            color: AppColors.success,
          ),
        ),
        const SizedBox(height: 32),
        // Title
        Text(
          'تم إرسال رابط الدخول',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        // Message
        Text(
          'تم إرسال رابط تسجيل الدخول إلى\n${_emailController.text}',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'يرجى فتح البريد الإلكتروني والضغط على الرابط لتسجيل الدخول',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),
        // Resend button
        AppButton(
          text: 'إرسال رابط جديد',
          onPressed: () {
            setState(() => _linkSent = false);
          },
          isFullWidth: true,
          size: AppButtonSize.large,
        ),
        const SizedBox(height: 16),
        // Change email button
        TextButton(
          onPressed: () {
            setState(() {
              _linkSent = false;
              _emailController.clear();
            });
          },
          child: const Text('تغيير البريد الإلكتروني'),
        ),
      ],
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const _GoogleSignInButton({
    required this.onPressed,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: const BorderSide(color: AppColors.border),
      ),
      child: isLoading
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.network(
                  'https://www.google.com/favicon.ico',
                  width: 24,
                  height: 24,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.g_mobiledata,
                    size: 24,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'تسجيل الدخول بواسطة Google',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
    );
  }
}
