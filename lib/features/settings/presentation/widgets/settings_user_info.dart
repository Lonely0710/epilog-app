import 'package:flutter/material.dart';
import 'package:flutter_lucide_animated/flutter_lucide_animated.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme/app_theme.dart';

class SettingsUserInfo extends StatelessWidget {
  final String displayName;
  final VoidCallback onEditName;

  const SettingsUserInfo({
    super.key,
    required this.displayName,
    required this.onEditName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Use yellow in dark mode for better visibility
    final highlightColor = isDark
        ? Colors.amber.withValues(alpha: 0.5)
        : Theme.of(context).primaryColor.withValues(alpha: 0.3);

    return Semantics(
      button: true,
      label: '编辑昵称',
      value: displayName,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onEditName,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        bottom: 3,
                        left: 0,
                        right: 0,
                        height: 12,
                        child: CustomPaint(
                          painter: HighlighterPainter(color: highlightColor),
                        ),
                      ),
                      RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          children: _buildNameSpans(
                            displayName,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.primary.withValues(alpha: 0.16)
                        : Theme.of(context)
                            .primaryColor
                            .withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: LucideAnimatedIcon(
                    icon: square_pen,
                    size: 14,
                    color: isDark
                        ? AppTheme.primary
                        : Theme.of(context).primaryColor,
                    trigger: AnimationTrigger.onHover,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<TextSpan> _buildNameSpans(String name, {Color? color}) {
    final englishStyle = GoogleFonts.ebGaramond(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: color,
    );
    final chineseStyle = TextStyle(
      fontFamily: 'HanSerifSC',
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: color,
    );

    return name.characters
        .map((char) => TextSpan(
              text: char,
              style: _usesChineseFont(char) ? chineseStyle : englishStyle,
            ))
        .toList(growable: false);
  }

  bool _usesChineseFont(String char) {
    final codeUnit = char.runes.first;
    return (codeUnit >= 0x3400 && codeUnit <= 0x9FFF) ||
        (codeUnit >= 0xF900 && codeUnit <= 0xFAFF) ||
        (codeUnit >= 0x3000 && codeUnit <= 0x303F) ||
        (codeUnit >= 0xFF00 && codeUnit <= 0xFFEF);
  }
}

class HighlighterPainter extends CustomPainter {
  final Color color;
  HighlighterPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    // A slightly wavy horizontal line
    path.moveTo(0, size.height / 2);
    path.quadraticBezierTo(
        size.width / 4, size.height / 2 - 2, size.width / 2, size.height / 2);
    path.quadraticBezierTo(
        size.width * 3 / 4, size.height / 2 + 2, size.width, size.height / 2);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
