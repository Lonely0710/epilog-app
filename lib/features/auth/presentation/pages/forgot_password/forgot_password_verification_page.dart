import 'dart:async';
import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../../app/theme/app_theme.dart';
import 'package:drama_tracker_flutter/core/presentation/widgets/app_snack_bar.dart';
import 'package:drama_tracker_flutter/core/services/secure_storage_service.dart';
import '../../widgets/auth_text_field.dart';
import '../../widgets/verification_message_dialog.dart';
import '../../../../../app/animations/dialog_animations.dart';
import '../../../data/auth_repository.dart';

class ForgotPasswordVerificationPage extends StatefulWidget {
  final String email;

  const ForgotPasswordVerificationPage({super.key, required this.email});

  @override
  State<ForgotPasswordVerificationPage> createState() =>
      _ForgotPasswordVerificationPageState();
}

class _ForgotPasswordVerificationPageState
    extends State<ForgotPasswordVerificationPage> {
  final _authRepository = AuthRepository();
  // Clerk defaults to 6 digits
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
  bool _rememberMe = false;
  bool _passwordHasError = false;
  String _lastPasswordInput = '';
  String _lastConfirmPasswordInput = '';
  int _secondsRemaining = 30;
  bool _canResend = false;
  Timer? _timer;

  static const _compromisedPasswordMessage = '该密码曾出现在网络泄露中。为了账号安全，请换一个不同的新密码。';
  static const _shortPasswordMessage = '密码至少需要 8 位，请重新输入。';
  static const _weakPasswordMessage = '密码强度不足，请使用更强的密码。';

  @override
  void initState() {
    super.initState();
    _loadRememberMePreference();
    _startTimer();
  }

  Future<void> _loadRememberMePreference() async {
    final rememberMe = await SecureStorageService.rememberMe;
    if (!mounted) return;
    setState(() => _rememberMe = rememberMe);
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 30;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
        if (mounted) setState(() => _canResend = true);
      }
    });
  }

  void _setPasswordError() {
    setState(() {
      _passwordHasError = true;
      _lastPasswordInput = _passwordController.text;
      _lastConfirmPasswordInput = _confirmPasswordController.text;
    });
  }

  void _clearPasswordErrorIfEdited() {
    if (!_passwordHasError) return;

    final passwordInput = _passwordController.text;
    final confirmPasswordInput = _confirmPasswordController.text;
    if (passwordInput == _lastPasswordInput &&
        confirmPasswordInput == _lastConfirmPasswordInput) {
      return;
    }

    setState(() {
      _passwordHasError = false;
      _lastPasswordInput = passwordInput;
      _lastConfirmPasswordInput = confirmPasswordInput;
    });
  }

  String _passwordErrorMessage(Object error) {
    final errorMessage = error.toString().toLowerCase();

    if (_isCompromisedPasswordError(errorMessage)) {
      return _compromisedPasswordMessage;
    }

    if (_isShortPasswordError(errorMessage)) {
      return _shortPasswordMessage;
    }

    if (_isWeakPasswordError(errorMessage)) {
      return _weakPasswordMessage;
    }

    return '验证失败: $error';
  }

  bool _isPasswordError(Object error) {
    final errorMessage = error.toString().toLowerCase();
    return _isCompromisedPasswordError(errorMessage) ||
        _isShortPasswordError(errorMessage) ||
        _isWeakPasswordError(errorMessage);
  }

  bool _isCompromisedPasswordError(String errorMessage) {
    return errorMessage.contains('data breach') ||
        errorMessage.contains('pwned') ||
        errorMessage.contains('online data breach') ||
        errorMessage.contains('form_password_pwned');
  }

  bool _isShortPasswordError(String errorMessage) {
    return errorMessage.contains('8 characters') ||
        errorMessage.contains('8 character') ||
        errorMessage.contains('passwords must be 8');
  }

  bool _isWeakPasswordError(String errorMessage) {
    return errorMessage.contains('password') && errorMessage.contains('weak');
  }

  Future<void> _handleResend() async {
    if (!_canResend || _isVerifying) return;

    try {
      await _authRepository.sendPasswordResetEmail(email: widget.email);
      if (!mounted) return;
      AppSnackBar.showSuccess(context, "验证码已重新发送");
      _startTimer();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, message: "重发失败: $e");
    }
  }

  Future<void> _handleVerify() async {
    final code = _controllers.map((c) => c.text).join();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (code.length != 6) return;
    if (password.isEmpty || password.length < 8) {
      _setPasswordError();
      AppSnackBar.showWarning(context, _shortPasswordMessage);
      return;
    }
    if (password != confirmPassword) {
      _setPasswordError();
      AppSnackBar.showWarning(context, "两次输入的密码不一致");
      return;
    }

    setState(() {
      _isVerifying = true;
      _passwordHasError = false;
      _lastPasswordInput = password;
      _lastConfirmPasswordInput = confirmPassword;
    });

    try {
      clerk.AuthError? clerkError;
      final errorSub = ClerkAuth.errorStreamOf(context).listen((error) {
        clerkError ??= error;
      });

      try {
        await _authRepository.verifyPasswordResetOtp(
          email: widget.email,
          token: code,
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

      if (_rememberMe) {
        await SecureStorageService.saveCredentials(
          email: widget.email,
          password: password,
        );
      } else {
        await SecureStorageService.clearCredentials();
      }

      try {
        await _authRepository.signOut();
      } catch (e) {
        debugPrint('Clerk sign out after password reset failed: $e');
      }

      if (mounted) {
        // Show success dialog
        await showAnimatedDialog(
          context: context,
          builder: (context) => VerificationMessageDialog(
            status: VerificationStatus.success,
            message: '您的密码已成功重置。您现在可以使用新密码登录。',
            onDismiss: () {
              context.go('/login');
            },
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        if (_isPasswordError(e)) {
          _setPasswordError();
        }
        AppSnackBar.showError(context, message: _passwordErrorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  void _onCodeChanged(String value, int index) {
    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus(); // Adjusted loop limit
      }
    } else {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  // ... (maskEmail unchanged)

  @override
  Widget build(BuildContext context) {
    // Colors
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final inputFillColor =
        isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade100;
    final inputBorderColor =
        isDark ? Colors.grey.shade700 : Colors.grey.shade300;

    return Scaffold(
      appBar: AppBar(
        title: const Text("验证邮箱"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            Text(
              "请输入发送至 ${widget.email} 的验证码",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            ),
            const SizedBox(height: 32),

            // OTP Input
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) {
                return SizedBox(
                  width: 44, // Slightly wider for 6 boxes
                  height: 56,
                  child: TextField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor),
                    decoration: InputDecoration(
                      counterText: "",
                      filled: true,
                      fillColor: inputFillColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: inputBorderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: inputBorderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppTheme.primary, width: 2),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (value) => _onCodeChanged(value, index),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                );
              }),
            ),

            const SizedBox(height: 32),

            // Password Inputs
            AuthTextField(
              controller: _passwordController,
              hintText: '输入新密码',
              prefixIcon: Icons.lock_outline,
              isPassword: true,
              hasError: _passwordHasError,
              onChanged: (_) => _clearPasswordErrorIfEdited(),
            ),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _confirmPasswordController,
              hintText: '确认新密码',
              prefixIcon: Icons.lock_outline,
              isPassword: true,
              hasError: _passwordHasError,
              onChanged: (_) => _clearPasswordErrorIfEdited(),
            ),

            const SizedBox(height: 24),

            // Remember Me Checkbox
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: _rememberMe,
                    activeColor: AppTheme.primary,
                    side: const BorderSide(
                      color: AppTheme.primary,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    onChanged: (val) =>
                        setState(() => _rememberMe = val ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "记住我",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 48),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("重新发送 ", style: TextStyle(fontSize: 14, color: textColor)),
                Text("$_secondsRemaining s",
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            if (_canResend)
              TextButton(
                onPressed: _handleResend,
                child: const Text("重新发送验证码",
                    style: TextStyle(color: AppTheme.primary)),
              ),

            const SizedBox(height: 48),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isVerifying ? null : _handleVerify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                child: _isVerifying
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text("验 证",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
