import 'package:flutter/material.dart';

import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../data/auth_repository.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/presentation/widgets/app_snack_bar.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/social_login_row.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _passwordHasError = false;
  String _lastPasswordInput = '';
  String _lastConfirmPasswordInput = '';
  final _authRepository = AuthRepository();

  static const _compromisedPasswordMessage = '该密码曾出现在网络泄露中。为了账号安全，请换一个不同的新密码。';
  static const _shortPasswordMessage = '密码至少需要 8 位，请重新输入。';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleGithubLogin() async {
    try {
      await _authRepository.signInWithOAuth('github');
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, message: '登录失败，请稍后重试');
      }
    }
  }

  Future<void> _handleRegister() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      AppSnackBar.showWarning(context, '请填写所有字段');
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _passwordHasError = true;
      });
      AppSnackBar.showWarning(context, '两次输入的密码不一致');
      return;
    }

    setState(() {
      _isLoading = true;
      _passwordHasError = false;
      _lastPasswordInput = password;
      _lastConfirmPasswordInput = confirmPassword;
    });

    try {
      clerk.AuthError? clerkError;
      final errorSub = ClerkAuth.errorStreamOf(context).listen((error) {
        clerkError ??= error;
      });

      // 1. Initiate Sign Up (Sends OTP if using Clerk)
      try {
        await _authRepository.signUpWithEmail(
          email: email,
          password: password,
        );
        if (clerkError == null) {
          await Future<void>.delayed(const Duration(milliseconds: 150));
        }
      } finally {
        await errorSub.cancel();
      }

      if (clerkError != null) {
        throw clerkError!;
      }

      if (mounted) {
        // Save credentials if "Remember Me" is checked
        if (_reflectRememberMe) {
          await SecureStorageService.saveCredentials(
            email: email,
            password: password,
          );
        } else {
          await SecureStorageService.clearCredentials();
        }

        // 2. Navigate to Verification Page
        if (mounted) {
          context.push('/verification', extra: email);
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().toLowerCase();

        if (errorMessage.contains('already') ||
            errorMessage.contains('exists')) {
          AppSnackBar.showWarning(context, '该邮箱已注册，请直接登录');
        } else if (errorMessage.contains('data breach') ||
            errorMessage.contains('pwned') ||
            errorMessage.contains('online data breach') ||
            errorMessage.contains('form_password_pwned')) {
          setState(() {
            _passwordHasError = true;
          });
          AppSnackBar.showWarning(context, _compromisedPasswordMessage);
        } else if (errorMessage.contains('8 characters') ||
            errorMessage.contains('8 character') ||
            errorMessage.contains('passwords must be 8')) {
          setState(() {
            _passwordHasError = true;
          });
          AppSnackBar.showWarning(context, _shortPasswordMessage);
        } else if (errorMessage.contains('password') &&
            errorMessage.contains('weak')) {
          setState(() {
            _passwordHasError = true;
          });
          AppSnackBar.showWarning(context, '密码强度不足，请使用更强的密码');
        } else if (errorMessage.contains('network') ||
            errorMessage.contains('connection')) {
          AppSnackBar.showNetworkError(context);
        } else {
          AppSnackBar.showError(context, message: '注册失败: ${e.toString()}');
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _reflectRememberMe = false;
  bool _hasInput = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_checkInput);
    _passwordController.addListener(_checkInput);
    _confirmPasswordController.addListener(_checkInput);
  }

  void _checkInput() {
    final passwordInput = _passwordController.text;
    final confirmPasswordInput = _confirmPasswordController.text;
    final hasInput = _emailController.text.isNotEmpty &&
        passwordInput.isNotEmpty &&
        confirmPasswordInput.isNotEmpty;
    final shouldClearPasswordError = _passwordHasError &&
        (passwordInput != _lastPasswordInput ||
            confirmPasswordInput != _lastConfirmPasswordInput);
    if (hasInput != _hasInput || shouldClearPasswordError) {
      if (mounted) {
        setState(() {
          _hasInput = hasInput;
          if (shouldClearPasswordError) {
            _passwordHasError = false;
          }
          _lastPasswordInput = passwordInput;
          _lastConfirmPasswordInput = confirmPasswordInput;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.grey.shade700 : Colors.grey.shade200;
    final secondaryTextColor =
        isDark ? Colors.grey.shade400 : Colors.grey.shade500;
    final titleColor = isDark ? Colors.white : AppTheme.textPrimary;
    final iconColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: iconColor),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/auth');
            }
          },
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header Lottie
                SizedBox(
                  height: 150, // Reduced from 180
                  child: Lottie.asset('assets/lottie/watchtv_splash.json'),
                ),
                const SizedBox(height: 12),

                Text(
                  "创建您的账号",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),

                const SizedBox(height: 24), // Reduced from 32

                // Email
                AuthTextField(
                  controller: _emailController,
                  hintText: "邮箱",
                  prefixIcon: Icons.email, // Filled
                  keyboardType: TextInputType.emailAddress,
                ),

                const SizedBox(height: 16), // Height is okay for tighter pack

                // Password
                AuthTextField(
                  controller: _passwordController,
                  hintText: "密码",
                  prefixIcon: Icons.lock_rounded, // Filled rounded
                  isPassword: true,
                  hasError: _passwordHasError,
                ),

                const SizedBox(height: 16),

                // Confirm Password
                AuthTextField(
                  controller: _confirmPasswordController,
                  hintText: "确认密码",
                  prefixIcon: Icons.lock_rounded,
                  isPassword: true,
                  hasError: _passwordHasError,
                ),

                const SizedBox(height: 20),

                // Remember Me Checkbox
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _reflectRememberMe,
                        activeColor: AppTheme.primary,
                        side: const BorderSide(
                          color: AppTheme.primary, // Primary when unchecked
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _reflectRememberMe = val ?? false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "记住我",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Sign Up Button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: _hasInput
                        ? [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                              spreadRadius: 2,
                            )
                          ]
                        : [],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "注 册",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 24), // Reduced from 32

                // Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: dividerColor)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "其他登录方式",
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: dividerColor)),
                  ],
                ),

                const SizedBox(height: 24), // Reduced from 32

                // Social Login
                SocialLoginRow(
                  onGithubPressed: _handleGithubLogin,
                  onGooglePressed: null, // Gmail login temporarily disabled
                ),

                const SizedBox(height: 20), // Reduced from 24 (tighter spacing)

                // Sign in Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "已有账号？ ",
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.pushReplacement('/login'),
                      child: const Text(
                        "立即登录",
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24), // Reduced from 48
              ],
            ),
          ),
        ),
      ),
    );
  }
}
