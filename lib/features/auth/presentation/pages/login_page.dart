import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../data/auth_repository.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../core/services/auth_bridge.dart';
import '../../../../core/presentation/widgets/app_snack_bar.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/social_login_row.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _credentialsHasError = false;
  String _lastEmailInput = '';
  String _lastPasswordInput = '';
  final _authRepository = AuthRepository();

  static const _invalidCredentialsMessage = '邮箱或密码错误，请重试';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      AppSnackBar.showWarning(context, '请输入邮箱和密码');
      return;
    }

    setState(() {
      _isLoading = true;
      _credentialsHasError = false;
      _lastEmailInput = email;
      _lastPasswordInput = password;
    });

    try {
      await _authRepository.signInWithEmail(
        email: email,
        password: password,
      );

      if (!mounted) return;

      final isConvexReady = await AuthBridge.syncProfileFromContext(context);
      if (!mounted) return;

      if (!isConvexReady) {
        AppSnackBar.showError(context, message: '登录成功，但同步账户失败，请重试');
        return;
      }

      if (mounted) {
        if (_reflectRememberMe) {
          await SecureStorageService.saveCredentials(
            email: email,
            password: password,
          );
        } else {
          await SecureStorageService.clearCredentials();
        }
        if (mounted) {
          context.go('/home');
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().toLowerCase();

        // Handle "session already exists" - user is already logged in
        if (errorMessage.contains('session_exists') ||
            errorMessage.contains('already signed in')) {
          // Just navigate to home since they're already logged in
          context.go('/home');
          return;
        }

        // Handle wrong password / invalid credentials
        if (errorMessage.contains('incorrect') ||
            errorMessage.contains('try again') ||
            errorMessage.contains('invalid') ||
            errorMessage.contains('invalidpassword') ||
            errorMessage.contains('credentials')) {
          setState(() {
            _credentialsHasError = true;
          });
          AppSnackBar.showError(context, message: _invalidCredentialsMessage);
        } else if (errorMessage.contains('second factor')) {
          AppSnackBar.showError(context, message: '此账号需要二次验证，当前版本暂不支持');
        } else if (errorMessage.contains('network') ||
            errorMessage.contains('connection')) {
          AppSnackBar.showNetworkError(context);
        } else {
          AppSnackBar.showError(context, message: '登录失败: ${e.toString()}');
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
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    final email = await SecureStorageService.email;
    final password = await SecureStorageService.password;
    final rememberMe = await SecureStorageService.rememberMe;

    if (mounted && rememberMe && email != null && password != null) {
      setState(() {
        _emailController.text = email;
        _passwordController.text = password;
        _reflectRememberMe = true;
      });
    }
  }

  void _checkInput() {
    final emailInput = _emailController.text;
    final passwordInput = _passwordController.text;
    final hasInput = emailInput.isNotEmpty && passwordInput.isNotEmpty;
    final shouldClearCredentialsError = _credentialsHasError &&
        (emailInput != _lastEmailInput || passwordInput != _lastPasswordInput);
    if (hasInput != _hasInput || shouldClearCredentialsError) {
      if (mounted) {
        setState(() {
          _hasInput = hasInput;
          if (shouldClearCredentialsError) {
            _credentialsHasError = false;
          }
          _lastEmailInput = emailInput;
          _lastPasswordInput = passwordInput;
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
      // Use Scale to ensure it fits on smaller screens without scrolling if possible,
      // or just tighter layout. User asked to "shrink overall".
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // Center vertically
              children: [
                // Header Lottie (Reduced Size)
                SizedBox(
                  height: 150, // Reduced from 180
                  child: Lottie.asset('assets/lottie/watchtv_splash.json'),
                ),
                const SizedBox(height: 12),

                Text(
                  "登录您的账号",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),

                const SizedBox(height: 24), // Reduced from 32

                // Email (Use filled icon)
                AuthTextField(
                  controller: _emailController,
                  hintText: "邮箱",
                  prefixIcon: Icons.email, // Filled
                  keyboardType: TextInputType.emailAddress,
                  hasError: _credentialsHasError,
                ),

                const SizedBox(height: 16), // Reduced from 20

                // Password
                AuthTextField(
                  controller: _passwordController,
                  hintText: "密码",
                  prefixIcon: Icons.lock_rounded, // Filled rounded
                  isPassword: true,
                  hasError: _credentialsHasError,
                ),

                const SizedBox(height: 16), // Reduced from 20

                // Remember Me checkbox
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
                          color:
                              AppTheme.primary, // Primary color when unchecked
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

                // Login Button
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
                    onPressed: _isLoading ? null : _handleLogin,
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
                            "登 录",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 12), // Reduced from 16

                Center(
                  child: TextButton(
                    onPressed: () => context.push('/forgot-password'),
                    child: const Text(
                      "忘记密码？",
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
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

                const SizedBox(
                    height:
                        24), // Reduced from 24 (keep same but bottom padding will help)

                // Sign up link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "还没有账号？ ",
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/register'),
                      child: const Text(
                        "立即注册",
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20), // Reduced bottom spacing
              ],
            ),
          ),
        ),
      ),
    );
  }
}
