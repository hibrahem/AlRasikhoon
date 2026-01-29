import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/countries.dart';
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
  final _phoneController = TextEditingController();
  String? _phoneError;
  Country _selectedCountry = Countries.defaultCountry;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // Validate
    final error = Validators.validatePhone(_phoneController.text, _selectedCountry);
    if (error != null) {
      setState(() => _phoneError = error);
      return;
    }
    setState(() => _phoneError = null);

    // Format phone number
    final phoneNumber = Validators.formatPhoneWithCountryCode(
      _phoneController.text,
      country: _selectedCountry,
    );

    // Send OTP
    final authRepo = ref.read(authRepositoryProvider.notifier);
    await authRepo.sendOtp(phoneNumber);

    // Check for errors
    final authState = ref.read(authRepositoryProvider);
    if (authState.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authState.error!),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Navigate to OTP screen
    if (mounted && authState.verificationId != null) {
      context.push(AppRoutes.otp, extra: phoneNumber);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authRepositoryProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
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
                      style:
                          Theme.of(context).textTheme.headlineLarge?.copyWith(
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
                const Spacer(),
                // Phone input
                AppPhoneField(
                  controller: _phoneController,
                  errorText: _phoneError,
                  autofocus: true,
                  initialCountry: _selectedCountry,
                  onChanged: (_) {
                    if (_phoneError != null) {
                      setState(() => _phoneError = null);
                    }
                  },
                  onCountryChanged: (country) {
                    setState(() {
                      _selectedCountry = country;
                      _phoneError = null;
                    });
                  },
                ),
                const SizedBox(height: 24),
                // Login button
                AppButton(
                  text: 'تسجيل الدخول',
                  onPressed: _handleLogin,
                  isLoading: authState.isLoading,
                  isFullWidth: true,
                  size: AppButtonSize.large,
                ),
                const Spacer(),
                // Footer
                Text(
                  'سيتم إرسال رمز التحقق إلى رقم الجوال',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
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
