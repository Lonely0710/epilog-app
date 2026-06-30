import 'package:flutter/material.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';

class AboutAppDialog extends StatelessWidget {
  const AboutAppDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondary =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

    return AppDialog(
      title: '关于 Epilog',
      contentAlignment: CrossAxisAlignment.start,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '你好，我是这款应用的开发者。',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textColor.withValues(alpha: 0.86),
              height: 1.5,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '在这里，我希望能为你提供一个纯粹的角落，整理光影记忆，珍藏感动瞬间。\n\n作为一名海报控和影迷，Epilog 的诞生源于对电影艺术的热爱。愿它能陪你记录每一段精彩的旅程。',
            style: TextStyle(
              fontSize: 15,
              color: textSecondary.withValues(alpha: 0.78),
              height: 1.5,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
      primaryAction: AppDialogAction(
        text: '知道了',
        onPressed: () => Navigator.pop(context),
      ),
    );
  }
}
