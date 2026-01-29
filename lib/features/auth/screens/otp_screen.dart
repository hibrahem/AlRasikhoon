import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phoneNumber;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  String _otp = '';
  int _secondsRemaining = AppConstants.otpTimeoutSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _verifyOtp() async {
    if (_otp.length != AppConstants.otpLength) return;

    final authRepo = ref.read(authRepositoryProvider.notifier);
    final user = await authRepo.verifyOtp(_otp);

    if (!mounted) return;

    final authState = ref.read(authRepositoryProvider);

    if (authState.error == 'account_not_found') {
      context.go(AppRoutes.accountNotFound);
      return;
    }

    if (authState.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authState.error!),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Navigation will be handled by router redirect
  }

  Future<void> _resendOtp() async {
    final authRepo = ref.read(authRepositoryProvider.notifier);
    await authRepo.sendOtp(widget.phoneNumber);

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

    if (mounted) {
      setState(() => _secondsRemaining = AppConstants.otpTimeoutSeconds);
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال رمز التحقق'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('التحقق'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              // Instructions
              Text(
                'أدخل رمز التحقق',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'تم إرسال رمز التحقق إلى\n${widget.phoneNumber}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              // OTP input
              AppOtpField(
                onCompleted: (otp) {
                  setState(() => _otp = otp);
                  _verifyOtp();
                },
                onChanged: (otp) {
                  setState(() => _otp = otp);
                },
              ),
              const SizedBox(height: 32),
              // Verify button
              AppButton(
                text: 'تحقق',
                onPressed: _otp.length == AppConstants.otpLength
                    ? _verifyOtp
                    : null,
                isLoading: authState.isLoading,
                isFullWidth: true,
                size: AppButtonSize.large,
              ),
              const SizedBox(height: 24),
              // Resend section
              if (_secondsRemaining > 0)
                Text(
                  'إعادة الإرسال بعد $_secondsRemaining ثانية',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                  textAlign: TextAlign.center,
                )
              else
                TextButton(
                  onPressed: authState.isLoading ? null : _resendOtp,
                  child: const Text('إعادة إرسال الرمز'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
