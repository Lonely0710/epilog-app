import 'dart:ui' as import_ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/presentation/widgets/shared_dialog_button.dart';

class FilterSheet extends StatefulWidget {
  final int? initialYear;
  final String? initialGenre;

  const FilterSheet({
    super.key,
    this.initialYear,
    this.initialGenre,
  });

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  int? selectedYear;
  String? selectedGenre;

  // Mock data as per requirement
  late final List<int> years;
  final genres = [
    '冒险',
    '剧情',
    '动作',
    '动画',
    '历史',
    '喜剧',
    '奇幻',
    '家庭',
    '恐怖',
    '悬疑',
    '惊悚',
    '战争',
    '爱情',
    '犯罪',
    '科幻',
    '纪录',
    '西部',
    '音乐'
  ];

  @override
  void initState() {
    super.initState();
    final currentYear = DateTime.now().year;
    years = List.generate(11, (index) => currentYear - index);
    selectedYear = widget.initialYear;
    selectedGenre = widget.initialGenre;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            '筛选',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('年份',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 12),
                  // Year Selector (iOS Style)
                  GestureDetector(
                    onTap: () => _showYearPicker(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedYear?.toString() ?? '选择年份',
                            style: TextStyle(
                              fontSize: 15,
                              color: selectedYear == null
                                  ? AppColors.textTertiary
                                  : Theme.of(context).textTheme.bodyLarge?.color,
                              fontFamily: AppTheme.primaryFont,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textTertiary, size: 20),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Text('类型',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: genres.map((g) {
                      return ChoiceChip(
                        label: Text(g),
                        selected: selectedGenre == g,
                        onSelected: (selected) => setState(() => selectedGenre = selected ? g : null),
                        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                        selectedColor: AppColors.primary.withValues(alpha: 0.1),
                        labelStyle: TextStyle(
                          color: selectedGenre == g ? AppColors.primary : Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: selectedGenre == g ? AppColors.primary : Colors.transparent,
                          ),
                        ),
                        showCheckmark: false,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Buttons
          Row(
            children: [
              SharedDialogButton(
                text: '重置',
                icon: Icons.refresh,
                isPrimary: false,
                onTap: () {
                  setState(() {
                    selectedYear = null;
                    selectedGenre = null;
                  });
                },
              ),
              const SizedBox(width: 16),
              SharedDialogButton(
                text: '确定',
                icon: Icons.check,
                isPrimary: true,
                onTap: () {
                  Navigator.pop(context, {
                    'year': selectedYear,
                    'genre': selectedGenre,
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  void _showYearPicker(BuildContext context) {
    // If no year selected, default to the first one (usually current/latest year)
    if (selectedYear == null) {
      setState(() {
        selectedYear = years[0];
      });
    }

    // Determine initial index
    final initialItemIndex = selectedYear != null ? years.indexOf(selectedYear!) : 0;

    // We use a local variable to track selection inside the picker if we wanted "Cancel/Done" logic,
    // but for "Live Update" + "Done just closes", we keep current logic BUT
    // we must ensure the picker visuals match the design (Glassmorphism).

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 300,
        // Glassmorphism effect
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withValues(alpha: 0.8), // Translucent
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowDark.withValues(alpha: 0.1),
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
                      color: Theme.of(context).cardColor.withValues(alpha: 0.5), // Slightly more opaque for toolbar
                      border: Border(bottom: BorderSide(color: AppColors.divider.withValues(alpha: 0.2))),
                    ),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Text(
                        '完成',
                        style: TextStyle(
                          color: AppColors.primary,
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
                        initialItem: initialItemIndex,
                      ),
                      onSelectedItemChanged: (index) {
                        setState(() {
                          selectedYear = years[index];
                        });
                      },
                      children: years.map((year) {
                        return Center(
                          child: Text(
                            year.toString(),
                            style: TextStyle(
                              fontSize: 18,
                              fontFamily: AppTheme.primaryFont,
                              color: Theme.of(context).textTheme.bodyLarge?.color, // Ensure visibility
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20), // Bottom safe area spacing
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
