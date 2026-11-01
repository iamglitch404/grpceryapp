import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/features/auth/providers/authProviders.dart';
import 'package:app/features/auth/providers/authViewState.dart';
import 'package:app/features/auth/widgets/envelopeFrontPainter.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  Timer? _timer;

  bool get _isLoading => ref.read(forgotPasswordProvider).isLoading;
  bool get _otpSent => ref.read(forgotPasswordProvider).otpSent;
  bool get _otpVerified => ref.read(forgotPasswordProvider).otpVerified;
  bool get _resetSuccess => ref.read(forgotPasswordProvider).resetSuccess;
  bool get _obscurePassword => ref.read(forgotPasswordProvider).obscurePassword;
  bool get _obscureConfirmPassword =>
      ref.read(forgotPasswordProvider).obscureConfirmPassword;
  int get _resendTimer => ref.read(forgotPasswordProvider).resendTimer;

  void _startTimer() {
    ref.read(forgotPasswordProvider.notifier).setResendTimer(45);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        if (_resendTimer > 0) {
          ref.read(forgotPasswordProvider.notifier).decrementResendTimer();
        } else {
          timer.cancel();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_emailController.text.isEmpty || !_emailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ref.read(forgotPasswordProvider.notifier).setLoading(true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetOTP(
        _emailController.text.trim(),
      );
      if (!mounted) return;
      ref.read(forgotPasswordProvider.notifier).setOtpSent(true);
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP sent to your email'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send OTP: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) ref.read(forgotPasswordProvider.notifier).setLoading(false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the 6-digit OTP'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    ref.read(forgotPasswordProvider.notifier).setLoading(true);
    try {
      final isValid = await ref.read(authRepositoryProvider).checkOTPIsValid(
        _emailController.text.trim(),
        _otpController.text.trim(),
      );
      if (!mounted) return;
      if (isValid) {
        ref.read(forgotPasswordProvider.notifier).setOtpVerified(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid OTP'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) ref.read(forgotPasswordProvider.notifier).setLoading(false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ref.read(forgotPasswordProvider.notifier).setLoading(true);
    try {
      final success = await ref.read(authRepositoryProvider)
          .verifyOTPAndUpdatePassword(
            _emailController.text.trim(),
            _otpController.text.trim(),
            _passwordController.text,
          );
      if (success) {
        if (mounted) {
          ref.read(forgotPasswordProvider.notifier).setResetSuccess(true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid OTP or password update failed.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        ref.read(forgotPasswordProvider.notifier).setLoading(false);
      }
    }
  }

  Widget _buildEmailStep(double scale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildGraphic(scale * 0.85),
        SizedBox(height: 16 * scale),
        Text(
          'Reset your password',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24 * scale,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        SizedBox(height: 8 * scale),
        Text(
          'Enter your email address and we\'ll send you a\none-time password (OTP) to reset your password.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14 * scale,
            height: 1.5,
          ),
        ),
        SizedBox(height: 24 * scale),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16 * scale),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 20 * scale,
                spreadRadius: 2 * scale,
                offset: Offset(0, 4 * scale),
              ),
            ],
            border: Border.all(color: Colors.grey.shade100),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 16 * scale,
            vertical: 8 * scale,
          ),
          child: Row(
            children: [
              Icon(
                Icons.mail_outline,
                color: const Color(0xFF1E523A),
                size: 24 * scale,
              ),
              SizedBox(width: 16 * scale),
              Expanded(
                child: TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    labelStyle: TextStyle(
                      fontSize: 14 * scale,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                    floatingLabelStyle: TextStyle(
                      fontSize: 14 * scale,
                      color: const Color(0xFF1E523A),
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4 * scale),
                  ),
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Please enter your email'
                      : null,
                ),
              ),
              SizedBox(width: 8 * scale),
              Icon(
                Icons.mark_email_read_outlined,
                color: const Color(0xFF7CA690).withValues(alpha: 0.7),
                size: 24 * scale,
              ),
            ],
          ),
        ),
        SizedBox(height: 16 * scale),
        ElevatedButton(
          onPressed: _isLoading ? null : _sendOtp,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E523A),
            padding: EdgeInsets.symmetric(vertical: 18 * scale),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16 * scale),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? SizedBox(
                  height: 20 * scale,
                  width: 20 * scale,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Send OTP',
                      style: TextStyle(
                        fontSize: 16 * scale,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8 * scale),
                    Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                      size: 20 * scale,
                    ),
                  ],
                ),
        ),
        SizedBox(height: 16 * scale),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 16 * scale,
            vertical: 16 * scale,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9F8),
            borderRadius: BorderRadius.circular(12 * scale),
          ),
          child: Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                color: const Color(0xFF7CA690),
                size: 28 * scale,
              ),
              SizedBox(width: 16 * scale),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12 * scale,
                      height: 1.5,
                      fontFamily: 'Inter',
                    ),
                    children: const [
                      TextSpan(
                        text:
                            "We'll never share your email with anyone.\nYour account is ",
                      ),
                      TextSpan(
                        text: "100% secure",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      TextSpan(text: "."),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 32 * scale),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(child: Divider(color: Colors.grey.shade300)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16 * scale),
              child: Text(
                'Remembered?',
                style: TextStyle(color: Colors.grey, fontSize: 13 * scale),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300)),
          ],
        ),
        SizedBox(height: 8 * scale),
        Center(
          child: TextButton(
            onPressed: () =>
                ref.read(authViewStateProvider).switchView(AuthViewMode.login),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: 16 * scale,
                vertical: 8 * scale,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Back to Login',
                  style: TextStyle(
                    color: const Color(0xFF1E523A),
                    fontWeight: FontWeight.bold,
                    fontSize: 15 * scale,
                  ),
                ),
                SizedBox(width: 6 * scale),
                Icon(
                  Icons.arrow_forward,
                  color: const Color(0xFF1E523A),
                  size: 18 * scale,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpStep(double scale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 16 * scale),
        Center(
          child: Container(
            width: 72 * scale,
            height: 72 * scale,
            decoration: const BoxDecoration(
              color: Color(0xFFEDF5F1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Icon(
                    Icons.mail_outline,
                    color: const Color(0xFF1E523A),
                    size: 36 * scale,
                  ),
                  Container(
                    padding: EdgeInsets.all(2 * scale),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: const Color(0xFF7CA690),
                      size: 14 * scale,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: 24 * scale),
        Text(
          'Verify your email',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24 * scale,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        SizedBox(height: 12 * scale),
        Text(
          'We\'ve sent a 6-digit OTP to',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14 * scale,
            height: 1.5,
          ),
        ),
        Text(
          _emailController.text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFF1E523A),
            fontSize: 14 * scale,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
        SizedBox(height: 48 * scale),
        // 6-box OTP Input
        Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) {
                final text = _otpController.text;
                final isFocused =
                    text.length == index || (text.length == 6 && index == 5);
                final char = index < text.length ? text[index] : '';
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 45 * scale,
                  height: 55 * scale,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10 * scale),
                    border: Border.all(
                      color: isFocused
                          ? const Color(0xFF1E523A)
                          : Colors.grey.shade300,
                      width: isFocused ? 2 : 1,
                    ),
                    boxShadow: [
                      if (isFocused)
                        BoxShadow(
                          color: const Color(0xFF1E523A).withValues(alpha: 0.1),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    char,
                    style: TextStyle(
                      fontSize: 24 * scale,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                );
              }),
            ),
            // Invisible overlay for natural keyboard handling
            TextFormField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              cursorColor: Colors.transparent,
              style: const TextStyle(color: Colors.transparent, fontSize: 24),
              decoration: const InputDecoration(
                border: InputBorder.none,
                counterText: '',
                fillColor: Colors.transparent,
              ),
              onChanged: (_) => ref.read(forgotPasswordProvider.notifier).triggerRebuild(),
            ),
          ],
        ),
        SizedBox(height: 48 * scale),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Didn\'t receive the code? ',
              style: TextStyle(color: Colors.grey, fontSize: 14 * scale),
            ),
            GestureDetector(
              onTap: _resendTimer == 0 ? _sendOtp : null,
              child: Text(
                'Resend OTP ${_resendTimer > 0 ? ' (00:${_resendTimer.toString().padLeft(2, '0')})' : ''}',
                style: TextStyle(
                  color: _resendTimer == 0
                      ? const Color(0xFF1E523A)
                      : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 14 * scale,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 24 * scale),
        ElevatedButton(
          onPressed: _isLoading ? null : _verifyOtp,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E523A),
            padding: EdgeInsets.symmetric(vertical: 18 * scale),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16 * scale),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? SizedBox(
                  height: 20 * scale,
                  width: 20 * scale,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'Verify OTP',
                  style: TextStyle(
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
        ),
        SizedBox(height: 32 * scale),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 16 * scale,
            vertical: 16 * scale,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9F8),
            borderRadius: BorderRadius.circular(12 * scale),
          ),
          child: Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                color: const Color(0xFF7CA690),
                size: 28 * scale,
              ),
              SizedBox(width: 16 * scale),
              Expanded(
                child: Text(
                  'OTP is valid for 10 minutes.\nDo not share it with anyone.',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12 * scale,
                    height: 1.5,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStep(double scale) {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    final has8Chars = password.length >= 8;
    final hasUpperLower = RegExp(r'(?=.*[a-z])(?=.*[A-Z])').hasMatch(password);
    final hasNumberSpecial = RegExp(r'(?=.*\d)(?=.*[\W_])').hasMatch(password);
    final passwordsMatch = password.isNotEmpty && password == confirmPassword;

    int strength = 0;
    if (password.isNotEmpty) strength++;
    if (has8Chars) strength++;
    if (hasUpperLower) strength++;
    if (hasNumberSpecial) strength++;

    String strengthText = '';
    Color strengthColor = Colors.grey;
    if (strength == 0) {
      strengthText = '';
    } else if (strength < 2) {
      strengthText = 'Weak';
      strengthColor = Colors.red;
    } else if (strength < 4) {
      strengthText = 'Fair';
      strengthColor = Colors.orange;
    } else {
      strengthText = 'Strong';
      strengthColor = const Color(0xFF1E523A);
    }

    Widget buildCheckItem(String text, bool isMet) {
      return Padding(
        padding: EdgeInsets.only(bottom: 8 * scale),
        child: Row(
          children: [
            Icon(
              isMet ? Icons.check_circle : Icons.check_circle_outline,
              color: isMet ? const Color(0xFF1E523A) : Colors.grey.shade400,
              size: 20 * scale,
            ),
            SizedBox(width: 8 * scale),
            Text(
              text,
              style: TextStyle(
                color: isMet ? Colors.black87 : Colors.grey.shade600,
                fontSize: 13 * scale,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 16 * scale),
        Center(
          child: Container(
            width: 72 * scale,
            height: 72 * scale,
            decoration: const BoxDecoration(
              color: Color(0xFFEDF5F1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.lock_outline,
                color: const Color(0xFF1E523A),
                size: 32 * scale,
              ),
            ),
          ),
        ),
        SizedBox(height: 16 * scale),
        Text(
          'Create new password',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24 * scale,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        SizedBox(height: 12 * scale),
        Text(
          'Your new password must be different from\npreviously used passwords.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14 * scale,
            height: 1.5,
          ),
        ),
        SizedBox(height: 32 * scale),

        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16 * scale),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 20 * scale,
                    spreadRadius: 2 * scale,
                    offset: Offset(0, 4 * scale),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Column(
                children: [
                  // New Password Field
                  Padding(
                    padding: EdgeInsets.all(12 * scale),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 48 * scale,
                          height: 48 * scale,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F9F8),
                            borderRadius: BorderRadius.circular(12 * scale),
                          ),
                          child: Icon(
                            Icons.lock_outline,
                            color: const Color(0xFF7CA690),
                            size: 20 * scale,
                          ),
                        ),
                        SizedBox(width: 16 * scale),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'New Password',
                                style: TextStyle(
                                  fontSize: 11 * scale,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                enabled: !_resetSuccess,
                                style: TextStyle(
                                  fontSize: 16 * scale,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (_) => ref.read(forgotPasswordProvider.notifier).triggerRebuild(),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.grey,
                            size: 20 * scale,
                          ),
                          onPressed: () => ref
                              .read(forgotPasswordProvider.notifier)
                              .toggleObscurePassword(),
                        ),
                      ],
                    ),
                  ),

                  // Divider & Strength
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: List.generate(5, (index) {
                              return Expanded(
                                child: Container(
                                  height: 3 * scale,
                                  margin: EdgeInsets.only(right: 4 * scale),
                                  decoration: BoxDecoration(
                                    color: index < (strength / 4 * 5).ceil()
                                        ? strengthColor
                                        : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(
                                      2 * scale,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        SizedBox(width: 8 * scale),
                        Text(
                          strengthText,
                          style: TextStyle(
                            color: strengthColor,
                            fontSize: 11 * scale,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8 * scale),

                  // Confirm Password Field
                  Padding(
                    padding: EdgeInsets.all(12 * scale),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 48 * scale,
                          height: 48 * scale,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F9F8),
                            borderRadius: BorderRadius.circular(12 * scale),
                          ),
                          child: Icon(
                            Icons.lock_outline,
                            color: const Color(0xFF7CA690),
                            size: 20 * scale,
                          ),
                        ),
                        SizedBox(width: 16 * scale),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Confirm New Password',
                                style: TextStyle(
                                  fontSize: 11 * scale,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                enabled: !_resetSuccess,
                                style: TextStyle(
                                  fontSize: 16 * scale,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (_) => ref.read(forgotPasswordProvider.notifier).triggerRebuild(),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.grey,
                            size: 20 * scale,
                          ),
                          onPressed: () => ref
                              .read(forgotPasswordProvider.notifier)
                              .toggleObscureConfirmPassword(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (passwordsMatch &&
                has8Chars &&
                hasUpperLower &&
                hasNumberSpecial)
              Positioned(
                bottom: -10 * scale,
                right: 16 * scale,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E523A),
                    shape: BoxShape.circle,
                  ),
                  padding: EdgeInsets.all(4 * scale),
                  child: Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16 * scale,
                  ),
                ),
              ),
          ],
        ),

        SizedBox(height: 24 * scale),

        // Checklist
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8 * scale),
          child: Column(
            children: [
              buildCheckItem('At least 8 characters', has8Chars),
              buildCheckItem(
                'Include uppercase and lowercase letters',
                hasUpperLower,
              ),
              buildCheckItem(
                'Include numbers and special characters',
                hasNumberSpecial,
              ),
              buildCheckItem('Passwords match', passwordsMatch),
            ],
          ),
        ),

        SizedBox(height: 32 * scale),

        ElevatedButton(
          onPressed: _isLoading || _resetSuccess ? null : _resetPassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E523A),
            padding: EdgeInsets.symmetric(vertical: 18 * scale),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16 * scale),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? SizedBox(
                  height: 20 * scale,
                  width: 20 * scale,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Reset Password',
                      style: TextStyle(
                        fontSize: 16 * scale,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8 * scale),
                    Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                      size: 20 * scale,
                    ),
                  ],
                ),
        ),
        SizedBox(height: 24 * scale),

        if (_resetSuccess)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 16 * scale,
              vertical: 16 * scale,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9F8),
              borderRadius: BorderRadius.circular(12 * scale),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: const Color(0xFF7CA690),
                  size: 28 * scale,
                ),
                SizedBox(width: 16 * scale),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Password reset successful!',
                        style: TextStyle(
                          color: const Color(0xFF1A1A1A),
                          fontSize: 14 * scale,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4 * scale),
                      Text(
                        'You can now login with your new password.',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12 * scale,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        if (_resetSuccess) SizedBox(height: 24 * scale),

        Center(
          child: TextButton(
            onPressed: () =>
                ref.read(authViewStateProvider).switchView(AuthViewMode.login),
            child: Text(
              'Back to Login',
              style: TextStyle(
                color: const Color(0xFF1E523A),
                fontWeight: FontWeight.bold,
                fontSize: 15 * scale,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGraphic(double scale) {
    return SizedBox(
      height: 220 * scale,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 180 * scale,
            height: 180 * scale,
            decoration: const BoxDecoration(
              color: Color(0xFFEDF5F1),
              shape: BoxShape.circle,
            ),
          ),
          Positioned(
            top: 40 * scale,
            left: 50 * scale,
            child: Container(
              width: 6 * scale,
              height: 6 * scale,
              decoration: const BoxDecoration(
                color: Color(0xFFCBE0D5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 40 * scale,
            right: 50 * scale,
            child: Container(
              width: 8 * scale,
              height: 8 * scale,
              decoration: const BoxDecoration(
                color: Color(0xFFCBE0D5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 30 * scale,
            child: Container(
              width: 120 * scale,
              height: 80 * scale,
              decoration: BoxDecoration(
                color: const Color(0xFF1E523A),
                borderRadius: BorderRadius.circular(8 * scale),
              ),
            ),
          ),
          Positioned(
            top: 50 * scale,
            child: Container(
              width: 70 * scale,
              height: 90 * scale,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8 * scale),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10 * scale,
                    spreadRadius: 2 * scale,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.lock,
                  color: const Color(0xFF1E523A),
                  size: 36 * scale,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 30 * scale,
            child: CustomPaint(
              size: Size(120 * scale, 50 * scale),
              painter: EnvelopeFrontPainter(),
            ),
          ),
          Positioned(
            top: 20 * scale,
            right: 60 * scale,
            child: Transform.rotate(
              angle: -0.2,
              child: Icon(
                Icons.send,
                color: const Color(0xFF7CA690),
                size: 32 * scale,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(forgotPasswordProvider);
    final double sw = MediaQuery.sizeOf(context).width;
    final double scale = (sw / 375.0).clamp(0.85, 1.25);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: const Color(0xFF1A1A1A),
            size: 24 * scale,
          ),
          onPressed: () =>
              ref.read(authViewStateProvider).switchView(AuthViewMode.login),
        ),
        title: Text(
          'Forgot Password',
          style: TextStyle(
            color: const Color(0xFF1A1A1A),
            fontSize: 18 * scale,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 24.0 * scale,
                  vertical: 16.0 * scale,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.0, 0.05),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                        child: !_otpSent
                            ? Container(
                                key: const ValueKey('email'),
                                child: _buildEmailStep(scale),
                              )
                            : (!_otpVerified)
                            ? Container(
                                key: const ValueKey('otp'),
                                child: _buildOtpStep(scale),
                              )
                            : Container(
                                key: const ValueKey('password'),
                                child: _buildPasswordStep(scale),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
