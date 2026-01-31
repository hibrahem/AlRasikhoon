import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  String? _emailError;
  bool _emailSent = false;
  bool _isFirstTimeUser = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendResetLink() async {
    // Validate
    final emailError = Validators.validateEmail(_emailController.text);
    if (emailError != null) {
      setState(() => _emailError = emailError);
      return;
    }
    setState(() => _emailError = null);

    // Use the new method that handles both pending users and existing users
    final authRepo = ref.read(authRepositoryProvider.notifier);
    final result = await authRepo.setupPendingUserAndSendReset(
      _emailController.text.trim(),
    );

    if (!mounted) return;

    final authState = ref.read(authRepositoryProvider);

    if (result == 'pending_user_setup') {
      // First-time user - account was just created
      setState(() {
        _emailSent = true;
        _isFirstTimeUser = true;
      });
    } else if (result == 'normal_reset') {
      // Existing user - normal password reset
      setState(() {
        _emailSent = true;
        _isFirstTimeUser = false;
      });
    } else if (authState.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authState.error!),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('استعادة كلمة المرور'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _emailSent ? _buildSuccessView() : _buildFormView(authState),
        ),
      ),
    );
  }

  Widget _buildFormView(AuthState authState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        // Icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.lock_reset,
            size: 40,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 24),
        // Title
        Text(
          'نسيت كلمة المرور؟',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'أدخل بريدك الإلكتروني وسنرسل لك رابط لإعادة تعيين كلمة المرور',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        // Email field
        AppEmailField(
          controller: _emailController,
          errorText: _emailError,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onChanged: (_) {
            if (_emailError != null) {
              setState(() => _emailError = null);
            }
          },
          onSubmitted: (_) => _handleSendResetLink(),
        ),
        const SizedBox(height: 24),
        // Send button
        AppButton(
          text: 'إرسال رابط الاستعادة',
          onPressed: _handleSendResetLink,
          isLoading: authState.isLoading,
          isFullWidth: true,
          size: AppButtonSize.large,
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    final title = _isFirstTimeUser ? 'تم تفعيل حسابك' : 'تم إرسال الرابط';
    final message = _isFirstTimeUser
        ? 'تم إنشاء حسابك وإرسال رابط تعيين كلمة المرور إلى\n${_emailController.text}'
        : 'تم إرسال رابط استعادة كلمة المرور إلى\n${_emailController.text}';
    final instructions = _isFirstTimeUser
        ? 'يرجى التحقق من بريدك الإلكتروني وتعيين كلمة مرور جديدة للدخول'
        : 'يرجى التحقق من بريدك الإلكتروني واتباع التعليمات';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Success icon
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _isFirstTimeUser ? Icons.verified_user : Icons.mark_email_read,
            size: 50,
            color: AppColors.success,
          ),
        ),
        const SizedBox(height: 32),
        // Title
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        // Message
        Text(
          message,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          instructions,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),
        // Back to login button
        AppButton(
          text: 'العودة لتسجيل الدخول',
          onPressed: () => context.pop(),
          isFullWidth: true,
          size: AppButtonSize.large,
        ),
        const SizedBox(height: 16),
        // Resend button
        TextButton(
          onPressed: () {
            setState(() {
              _emailSent = false;
              _isFirstTimeUser = false;
            });
          },
          child: const Text('إرسال رابط جديد'),
        ),
      ],
    );
  }
}
