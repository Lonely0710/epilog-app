import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';

class AuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final bool isPassword;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final bool hasError;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.hasError = false,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _obscureText = true;
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
    // Listen to text changes to update icon color
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(() {});
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Determine background color: Grey when inactive, Light Primary when focused.
    final fillColor = widget.hasError
        ? AppTheme.error.withAlpha(isDark ? 32 : 18)
        : (_isFocused
            ? AppTheme.primary
                .withAlpha(30) // ~12% opacity, lighter theme color
            : (isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.shade100));

    final iconColor = widget.hasError
        ? AppTheme.error
        : _isFocused
            ? AppTheme.primary
            : (widget.controller.text.isNotEmpty
                ? (isDark ? Colors.white70 : Colors.black87)
                : Colors.grey);

    final textColor = isDark ? Colors.white : AppTheme.textPrimary;
    final hintColor = isDark ? Colors.grey.shade500 : Colors.grey;

    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      obscureText: widget.isPassword && _obscureText,
      keyboardType: widget.keyboardType,
      onChanged: widget.onChanged,
      cursorColor: AppTheme.primary,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 15,
        color: textColor,
      ),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: TextStyle(
          color: hintColor,
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
        filled: true,
        fillColor: fillColor,
        // No border when not focused, theme color border when focused.
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: widget.hasError
              ? const BorderSide(
                  color: AppTheme.error,
                  width: 1.5,
                )
              : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: widget.hasError ? AppTheme.error : AppTheme.primary,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
        prefixIcon: Icon(
          widget.prefixIcon,
          color: iconColor,
          size: 22,
        ),
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(
                  _obscureText ? Icons.visibility_off : Icons.visibility,
                  color: iconColor,
                  size: 22,
                ),
                onPressed: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
              )
            : null,
      ),
    );
  }
}
