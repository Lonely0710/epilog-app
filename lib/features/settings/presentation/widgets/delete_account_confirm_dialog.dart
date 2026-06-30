import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../../core/presentation/widgets/shared_dialog_button.dart';

class DeleteAccountConfirmDialog extends StatefulWidget {
  const DeleteAccountConfirmDialog({super.key});

  @override
  State<DeleteAccountConfirmDialog> createState() =>
      _DeleteAccountConfirmDialogState();
}

class _DeleteAccountConfirmDialogState
    extends State<DeleteAccountConfirmDialog> {
  static const int _initialSeconds = 3;

  Timer? _timer;
  int _secondsRemaining = _initialSeconds;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() => _secondsRemaining = 0);
        }
        return;
      }

      if (mounted) {
        setState(() => _secondsRemaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final canConfirm = _secondsRemaining == 0;

    return AppDialog(
      title: '注销账号',
      content: Text(
        '注销后将删除当前账号的资料和收藏数据，此操作无法撤销。',
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
        text: canConfirm ? '确认注销' : '确认注销 $_secondsRemaining',
        variant: SharedDialogButtonVariant.destructive,
        isDisabled: !canConfirm,
        onPressed: canConfirm ? () => Navigator.pop(context, true) : null,
      ),
    );
  }
}
