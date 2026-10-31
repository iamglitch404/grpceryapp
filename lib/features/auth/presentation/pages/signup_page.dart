import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:cubepod/cubepod.dart';
import 'package:app/core/widgets/top_bar.dart';
import 'package:app/features/auth/presentation/state/auth_view_state.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _referralCodeController = TextEditingController();
  final _otpController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _referralCodeController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    try {
      final success = await CubePod.get<AuthRepository>().signUp(
        email,
        password,
        name,
        username: username.isNotEmpty ? username : null,
      );
      if (success && mounted) {
        _showOtpDialog(email);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signup failed or user exists.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception:', '').trim()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showOtpDialog(String email) {
    int step = 1; // 1: OTP, 2: Success
    final dialogOtpController = TextEditingController();
    bool isDialogLoading = false;
    bool isResending = false;
    String? inlineErrorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                step == 1 ? 'Verify OTP' : 'Success!',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
              ),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (step == 1) ...[
                      const Text(
                        'We sent a 6-digit OTP to your email.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: dialogOtpController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        onChanged: (val) {
                          if (inlineErrorMessage != null) {
                            setStateDialog(() => inlineErrorMessage = null);
                          }
                        },
                        style: const TextStyle(fontSize: 24, letterSpacing: 10, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          counterText: '',
                          hintText: '000000',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF42A769), width: 2),
                          ),
                        ),
                      ),
                      if (inlineErrorMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          inlineErrorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: isResending || isDialogLoading
                            ? null
                            : () async {
                                setStateDialog(() {
                                  isResending = true;
                                  inlineErrorMessage = null;
                                });
                                try {
                                  await CubePod.get<AuthRepository>().resendOTP(email);
                                  setStateDialog(() {
                                    inlineErrorMessage = 'OTP resent successfully!';
                                  });
                                } catch (e) {
                                  setStateDialog(() {
                                    inlineErrorMessage = 'Failed to resend OTP.';
                                  });
                                } finally {
                                  setStateDialog(() => isResending = false);
                                }
                              },
                        child: isResending
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Resend OTP', style: TextStyle(color: Color(0xFF42A769), fontWeight: FontWeight.bold)),
                      ),
                    ] else if (step == 2) ...[
                      const Icon(Icons.check_circle_outline, color: Color(0xFF42A769), size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'Successfully verified and logged in!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
              ),
              actions: [
                if (step != 2)
                  TextButton(
                    onPressed: isDialogLoading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                if (step == 1)
                  ElevatedButton(
                    onPressed: isDialogLoading
                        ? null
                        : () async {
                            if (dialogOtpController.text.length < 6) return;
                            setStateDialog(() => isDialogLoading = true);
                            
                            try {
                              final success = await CubePod.get<AuthRepository>().verifyOTPForSignup(
                                email,
                                dialogOtpController.text,
                                '',
                                _nameController.text.trim(),
                                _passwordController.text.trim(),
                                referralCode: _referralCodeController.text.trim(),
                                username: _usernameController.text.trim().isNotEmpty
                                    ? _usernameController.text.trim().toLowerCase()
                                    : null,
                              );
                              if (success) {
                                setStateDialog(() => step = 2);
                              } else {
                                setStateDialog(() => inlineErrorMessage = 'Invalid OTP or Verification Failed');
                              }
                            } finally {
                              setStateDialog(() => isDialogLoading = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF42A769), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: isDialogLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Verify', style: TextStyle(color: Colors.white)),
                  )
                else if (step == 2)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context); // Go back to dashboard
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF42A769), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Continue to Dashboard', style: TextStyle(color: Colors.white)),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAuthForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Full name
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'Full Name',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF39A968)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF39A968), width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter your name';
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Username Field
          TextFormField(
            controller: _usernameController,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
              LengthLimitingTextInputFormatter(30),
            ],
            decoration: InputDecoration(
              hintText: 'Username (e.g. alex_rider)',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              prefixIcon: const Icon(Icons.alternate_email_rounded, color: Color(0xFF1E523A)),
              filled: true,
              fillColor: const Color(0xFFF7F9F8),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF1E523A), width: 2),
              ),
            ),
            validator: (value) {
              if (value != null && value.isNotEmpty && value.length < 3) {
                return 'Username must be at least 3 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Email Field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'Email Address',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF1E523A)),
              filled: true,
              fillColor: const Color(0xFFF7F9F8),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF1E523A), width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter your email';
              if (!RegExp(r'^[a-z0-9.]+@gmail\.com$').hasMatch(value.toLowerCase())) {
                return 'Only @gmail.com email addresses are accepted';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Password Field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: 'Password',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF1E523A)),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              filled: true,
              fillColor: const Color(0xFFF7F9F8),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF1E523A), width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter your password';
              if (value.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Referral Code Field (Optional)
          TextFormField(
            controller: _referralCodeController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Referral Code (Optional)',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              prefixIcon: const Icon(Icons.card_giftcard_outlined, color: Color(0xFF1E523A)),
              filled: true,
              fillColor: const Color(0xFFF7F9F8),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF1E523A), width: 2),
              ),
            ),
          ),
          
          const SizedBox(height: 20),

          // Submit Button
          ElevatedButton(
            onPressed: _isLoading ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E523A),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              shadowColor: const Color(0xFF1E523A).withValues(alpha: 0.4),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Register Account',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
          
          const SizedBox(height: 32),

          // Social Logins
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('or continue with', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
              Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                await CubePod.get<AuthRepository>().loginWithOAuth('google');
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google Login Failed: $e'), backgroundColor: Colors.red));
                }
              }
            },
            icon: SvgPicture.asset('assets/icons/google.svg', width: 24, height: 24),
            label: const Text('Continue with Google', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: Colors.grey.shade300, width: 1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 16),

          // Security Reassurance
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F8F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF39A968).withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.shield_outlined, color: Color(0xFF39A968), size: 18),
                SizedBox(width: 8),
                Text(
                  'Your data is safe and secure with us.',
                  style: TextStyle(color: Color(0xFF185B3A), fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Toggle Sign up / Login
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Already have an account?',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              GestureDetector(
                onTap: () {
                  CubePod.get<AuthViewState>().switchView(AuthViewMode.login);
                },
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Text(
                    'Log In',
                    style: TextStyle(
                      color: Color(0xFF1E523A),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Skip / Guest Mode Button
          Center(
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.person_outline, color: Color(0xFF1E523A), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Continue as Guest',
                      style: TextStyle(
                        color: Color(0xFF1E523A),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final minHeight = mediaQuery.size.height - mediaQuery.padding.top - mediaQuery.padding.bottom - 56.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        automaticallyImplyLeading: false,
        title: const TopBar(
          horizontalPadding: 24.0,
          customActions: [],
        ),
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: minHeight > 0 ? minHeight : 0,
            ),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0, top: 16.0),
                child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Create your account',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Join us to access premium products',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Form
                        _buildAuthForm(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    );
  }
}
