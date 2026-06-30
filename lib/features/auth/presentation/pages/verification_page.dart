import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/presentation/widgets/app_snack_bar.dart';
import '../../../../core/services/auth_bridge.dart';
import '../../data/auth_repository.dart';
import '../widgets/verification_message_dialog.dart';
import '../../../../app/animations/dialog_animations.dart';

class VerificationPage extends StatefulWidget {
  final String email;

  const VerificationPage({super.key, required this.email});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  final _authRepository = AuthRepository();
  // Clerk defaults to 6 digits
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  // Timer state
  Timer? _timer;
  int _secondsRemaining = 60;
  bool _canResend = false;

  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 60;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _handleResend() async {
    if (!_canResend) return;

    try {
      await _authRepository.resendEmailOtp(email: widget.email);
      if (!mounted) return;
      AppSnackBar.showSuccess(context, '验证码已重新发送！');
      _startTimer();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, message: '重发失败: ${e.toString()}');
    }
  }

  Future<void> _handleVerify() async {
    final code = _controllers.map((c) => c.text).join();
    // Check for 6 digits
    if (code.length != 6) {
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      await _authRepository.verifyEmailOtp(
        email: widget.email,
        token: code,
      );
      if (mounted) {
        await AuthBridge.syncProfileFromContext(context);
      }

      if (mounted) {
        // Assuming success if no error was thrown
        // Assuming success if no error was thrown
        // Wait for dialog to be closed
        await showAnimatedDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => VerificationMessageDialog(
            status: VerificationStatus.success,
            message: '您的账号验证成功，请继续完善个人资料。',
          ),
        );

        if (mounted) {
          context.go('/setup-profile');
        }
      }
    } catch (e) {
      if (mounted) {
        // Handle generic errors (like HandshakeException) with a user-friendly message
        final errorMessage = e.toString().contains('HandshakeException') ||
                e.toString().contains('SocketException')
            ? '网络连接失败，请检查网络设置'
            : (e.toString().contains('AuthException')
                ? "验证失败: ${e.toString()}"
                : '验证码无效，请重试');

        await showAnimatedDialog(
          context: context,
          builder: (context) => VerificationMessageDialog(
            status: VerificationStatus.failure,
            message: errorMessage,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  void _onCodeChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black;
    final titleColor = isDark ? Colors.white : Colors.black;
    final inputFillColor = isDark ? Colors.grey.shade800 : Colors.white;
    final inputBorderColor =
        isDark ? Colors.grey.shade700 : Colors.grey.shade200;
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: iconColor),
          onPressed: () => context.pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "邮箱验证",
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24), // Adjusted height
              // Image
              SvgPicture.asset(
                'assets/images/auth_email_verify.svg',
                height: 200,
              ),
              const SizedBox(height: 40),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "验证码已发送至 ",
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor,
                    ),
                  ),
                  Text(
                    _maskEmail(widget.email),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 48),

              // Code Input
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 44, // Increased width slightly for 6 items
                    height: 56, // Adjusted height
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      decoration: InputDecoration(
                        counterText: "",
                        filled: true,
                        fillColor: inputFillColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: inputBorderColor,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: inputBorderColor,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppTheme.primary,
                            width: 2,
                          ),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (value) => _onCodeChanged(value, index),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                  );
                }),
              ),

              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "重新发送 ",
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor,
                    ),
                  ),
                  Text(
                    "$_secondsRemaining s",
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.primary, // Changed color
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              if (_canResend)
                TextButton(
                  onPressed: _handleResend,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary, // Added style
                  ),
                  child: const Text("重新发送验证码"),
                ),

              const SizedBox(height: 100),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _handleVerify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary, // Changed color
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "验 证",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _maskEmail(String email) {
    if (email.length <= 4) return email;
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];

    if (name.length <= 2) return "$name***@$domain";

    return "${name.substring(0, 2)}***${name.substring(name.length - 1)}@$domain";
  }
}
