import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authRepo = ref.read(authRepositoryProvider.notifier);
    final result = await authRepo.signInWithUsernameAndPassword(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    final authState = ref.read(authRepositoryProvider);

    if (result == null) {
      if (authState.error == 'account_not_found') {
        context.go(AppRoutes.accountNotFound);
        return;
      }

      if (authState.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authState.error!),
            backgroundColor: context.tokens.maroon,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final authState = ref.watch(authRepositoryProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: tokens.green.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.menu_book,
                        size: 50,
                        color: tokens.green,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'الراسخون',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            color: tokens.green,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'تطبيق حفظ القرآن الكريم',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: tokens.sepia),
                    ),
                  ],
                ),
                const SizedBox(height: 48),

                AppTextField(
                  label: 'اسم المستخدم',
                  hint: 'username',
                  controller: _usernameController,
                  validator: Validators.validateUsername,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                const SizedBox(height: 20),

                AppPasswordField(
                  controller: _passwordController,
                  validator: Validators.validatePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleLogin(),
                ),
                const SizedBox(height: 32),

                AppButton(
                  text: 'تسجيل الدخول',
                  onPressed: _handleLogin,
                  isLoading: authState.isLoading,
                  isFullWidth: true,
                  size: AppButtonSize.large,
                ),
                const SizedBox(height: 24),

                Text(
                  'يجب أن يكون لديك حساب مسجل مسبقاً',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
