import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/presentation/widgets/app_snack_bar.dart';
import '../../../../core/services/auth_bridge.dart';
import '../../../../core/services/convex_service.dart';

class EditNamePage extends StatefulWidget {
  final String initialName;

  const EditNamePage({
    super.key,
    required this.initialName,
  });

  @override
  State<EditNamePage> createState() => _EditNamePageState();
}

class _EditNamePageState extends State<EditNamePage> {
  static final RegExp _invalidNamePattern = RegExp(r'[@<>/]');
  static const int _minNameLength = 2;
  static const int _maxNameLength = 24;
  static const double _pageHorizontalPadding = 16;
  static const double _fieldHeight = 58;

  late final TextEditingController _nameController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _nameController.addListener(_handleNameChanged);
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_handleNameChanged)
      ..dispose();
    super.dispose();
  }

  void _handleNameChanged() {
    setState(() {});
  }

  String get _trimmedName => _nameController.text.trim();

  bool get _hasInvalidCharacters => _invalidNamePattern.hasMatch(_trimmedName);

  bool get _isLengthValid =>
      _trimmedName.length >= _minNameLength &&
      _trimmedName.length <= _maxNameLength;

  bool get _hasChanged => _trimmedName != widget.initialName.trim();

  bool get _canSave =>
      !_isSaving && _hasChanged && _isLengthValid && !_hasInvalidCharacters;

  Future<void> _saveName() async {
    if (!_canSave) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      await ClerkAuth.of(context).updateUser(firstName: _trimmedName);

      final isSynced = await _syncConvexProfile(_trimmedName);
      if (!isSynced) {
        debugPrint('Convex profile sync skipped: auth token unavailable');
      }

      if (!mounted) return;
      context.pop(_trimmedName);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppSnackBar.showError(context, message: '修改失败，请稍后重试');
      }
    }
  }

  Future<bool> _syncConvexProfile(String name) async {
    try {
      final isAuthenticated = await AuthBridge.ensureFromContext(context);
      if (!isAuthenticated) return false;

      final result = await ConvexService.instance.client.mutation(
        name: 'users:storeUser',
        args: {'name': name},
      );
      if (!AuthBridge.isMutationOk(result)) {
        debugPrint('Convex profile sync skipped: missing identity');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Convex profile sync failed: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final secondaryColor = isDark
        ? Colors.white.withValues(alpha: 0.56)
        : AppColors.textSecondary.withValues(alpha: 0.78);
    final pageBackground =
        isDark ? AppColors.backgroundDark : const Color(0xFFF6F6F7);
    final inputBackground =
        isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white;
    final saveColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: pageBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leadingWidth: 64,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textColor,
            size: 26,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '编辑名字',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: TextButton(
              onPressed: _canSave ? _saveName : null,
              style: TextButton.styleFrom(
                foregroundColor: saveColor,
                disabledForegroundColor: saveColor.withValues(alpha: 0.42),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(48, 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: _isSaving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : const Text(
                      '保存',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            _pageHorizontalPadding,
            24,
            _pageHorizontalPadding,
            24,
          ),
          children: [
            Container(
              constraints: const BoxConstraints.tightFor(height: _fieldHeight),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: inputBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      autofocus: true,
                      maxLength: _maxNameLength,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _saveName(),
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        letterSpacing: 0,
                      ),
                      cursorColor: theme.colorScheme.primary,
                      textAlignVertical: TextAlignVertical.center,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        filled: false,
                        isCollapsed: true,
                        counterText: '',
                        hintText: '请输入名字',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          letterSpacing: 0,
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_trimmedName.length}/$_maxNameLength',
                    style: TextStyle(
                      color: secondaryColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              '请设置 2-24 个字符，不包括 @<>/ 等无效字符。30 天内可修改 4 次昵称，07.22 前还可修改 4 次。',
              style: TextStyle(
                color: secondaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.55,
                letterSpacing: 0,
              ),
            ),
            if (_hasInvalidCharacters ||
                (!_isLengthValid && _trimmedName.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _hasInvalidCharacters ? '名字不能包含 @<>/。' : '名字长度需为 2-24 个字符。',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
