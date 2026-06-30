import 'dart:io';
import 'dart:ui' as import_ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../../core/presentation/widgets/app_snack_bar.dart';
import '../../../../core/presentation/widgets/shared_dialog_button.dart';
import '../../domain/services/export_service.dart';

class ExportDialog extends StatefulWidget {
  const ExportDialog({super.key});

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  bool _isExportAll = true;
  String _selectedType = 'tv';
  bool _isExporting = false;

  final ExportService _exportService = ExportService();

  final Map<String, String> _typeLabels = {
    'tv': '电视剧',
    'movie': '电影',
    'anime': '动漫',
  };

  void _handleExport() async {
    setState(() => _isExporting = true);

    try {
      List<String>? mediaTypes;
      if (!_isExportAll) {
        mediaTypes = [_selectedType];
      }

      final File csvFile =
          await _exportService.exportCollections(mediaTypes: mediaTypes);

      if (mounted) {
        // Share the file
        // ignore: deprecated_member_use
        await Share.shareXFiles([XFile(csvFile.path)]);
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, message: '导出失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _showTypePicker(BuildContext context) {
    final types = _typeLabels.keys.toList();
    final initialIndex = types.indexOf(_selectedType);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pickerBg = isDark ? const Color(0xFF1A2A3A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 300,
        decoration: BoxDecoration(
          color: pickerBg.withValues(alpha: isDark ? 0.95 : 0.8),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BackdropFilter(
            filter: import_ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  // Toolbar
                  Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerRight,
                    decoration: BoxDecoration(
                      color: pickerBg.withValues(alpha: isDark ? 0.8 : 0.5),
                      border: Border(
                          bottom: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.grey.withValues(alpha: 0.2))),
                    ),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Text(
                        '完成',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: AppTheme.primaryFont,
                        ),
                      ),
                    ),
                  ),
                  // Picker
                  Expanded(
                    child: CupertinoPicker(
                      itemExtent: 40,
                      scrollController: FixedExtentScrollController(
                        initialItem: initialIndex >= 0 ? initialIndex : 0,
                      ),
                      onSelectedItemChanged: (index) {
                        setState(() {
                          _selectedType = types[index];
                        });
                      },
                      children: types.map((type) {
                        return Center(
                          child: Text(
                            _typeLabels[type]!,
                            style: TextStyle(
                              fontSize: 18,
                              fontFamily: AppTheme.primaryFont,
                              color: textColor,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppDialog(
      title: '数据导出',
      contentAlignment: CrossAxisAlignment.start,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '选择要导出的收藏范围。',
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.72),
              fontSize: 15,
              height: 1.4,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 16),
          _buildExportOption(
            title: '导出全部',
            subtitle: '包含全部收藏数据',
            value: true,
          ),
          const SizedBox(height: 8),
          _buildExportOption(
            title: '按类型导出',
            subtitle: _typeLabels[_selectedType] ?? '选择类型',
            value: false,
            onTrailingTap: () => _showTypePicker(context),
          ),
        ],
      ),
      secondaryAction: AppDialogAction(
        text: '取消',
        variant: SharedDialogButtonVariant.secondary,
        onPressed: _isExporting ? null : () => Navigator.pop(context),
        isDisabled: _isExporting,
      ),
      primaryAction: AppDialogAction(
        text: '导出',
        onPressed: _isExporting ? null : _handleExport,
        isLoading: _isExporting,
      ),
    );
  }

  Widget _buildExportOption({
    required String title,
    required String subtitle,
    required bool value,
    VoidCallback? onTrailingTap,
  }) {
    final isSelected = _isExportAll == value;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final mutedColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    const selectedColor = AppTheme.primary;

    return Semantics(
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: () => setState(() => _isExportAll = value),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? selectedColor.withValues(alpha: isDark ? 0.16 : 0.10)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.white.withValues(alpha: 0.54)),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? selectedColor.withValues(alpha: isDark ? 0.42 : 0.28)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05)),
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? selectedColor : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? selectedColor
                        : mutedColor.withValues(alpha: 0.32),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 15,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: mutedColor.withValues(alpha: 0.72),
                        fontSize: 13,
                        height: 1.35,
                        letterSpacing: 0,
                        fontFamily: AppTheme.primaryFont,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTrailingTap != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() => _isExportAll = value);
                    onTrailingTap();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: isSelected
                          ? selectedColor
                          : mutedColor.withValues(alpha: 0.56),
                      size: 24,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
