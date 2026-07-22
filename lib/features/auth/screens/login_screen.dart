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
                // The official vertical lockup — drop + typed Reem Kufi
                // wordmark and tagline, same mark as the app icon and splash.
                // One flat ink per surface (brand rule): green on the
                // parchment page, cream on the dark page. It carries its own
                // wordmark ("الراسخون في حفظ كتاب الله"), so no title text.
                Image.asset(
                  Theme.of(context).brightness == Brightness.dark
                      ? 'assets/brand/lockup-cream.png'
                      : 'assets/brand/lockup-green.png',
                  height: 180,
                  fit: BoxFit.contain,
                  semanticLabel: 'الراسخون',
                ),
                const SizedBox(height: 48),

                AppTextField(
                  label: 'اسم المستخدم',
                  hint: 'أدخل اسم المستخدم',
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
