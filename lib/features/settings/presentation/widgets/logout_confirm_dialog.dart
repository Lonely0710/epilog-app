import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../../core/presentation/widgets/shared_dialog_button.dart';

/// Logout confirmation dialog styled similar to reference p2
class LogoutConfirmDialog extends StatelessWidget {
  const LogoutConfirmDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return AppDialog(
      title: '退出登录',
      content: Text(
        '你是否确定退出账号？',
        style: TextStyle(
          fontSize: 15,
          color: textColor.withValues(alpha: 0.72),
          height: 1.5,
          letterSpacing: 0,
        ),
        textAlign: TextAlign.start,
      ),
      secondaryAction: AppDialogAction(
        text: '取消',
        variant: SharedDialogButtonVariant.secondary,
        onPressed: () => Navigator.pop(context, false),
      ),
      primaryAction: AppDialogAction(
        text: '退出',
        onPressed: () => Navigator.pop(context, true),
      ),
    );
  }
}
