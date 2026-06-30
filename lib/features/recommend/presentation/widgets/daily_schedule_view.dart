import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/domain/entities/media.dart';
import '../../../../core/presentation/widgets/app_snack_bar.dart';
import '../../../../core/presentation/widgets/empty_state_widget.dart';
import '../../../../core/services/media_providers/bangumi_service.dart';
import 'daily_row_widget.dart';

class DailyScheduleView extends StatefulWidget {
  const DailyScheduleView({super.key});

  @override
  State<DailyScheduleView> createState() => _DailyScheduleViewState();
}

class _DailyScheduleViewState extends State<DailyScheduleView> {
  Map<String, List<Media>> _schedule = {};
  bool _isLoading = true;
  final BangumiService _bangumiService = BangumiService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }
      final schedule = await _bangumiService.getWeeklySchedule();
      if (mounted) {
        setState(() {
          _schedule = schedule;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        AppSnackBar.showNetworkError(context, onRetry: _loadData);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Align(
        alignment: const Alignment(0, -0.28),
        child: Lottie.asset(
          'assets/lottie/movie_loading.json',
          width: 200,
          height: 200,
        ),
      );
    }

    if (_schedule.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.calendar_today,
        onAction: _loadData,
      );
    }

    // Order keys: Sun, Mon, Tue, Wed, Thu, Fri, Sat
    final orderedKeys = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      itemCount: orderedKeys.length,
      itemBuilder: (context, index) {
        final key = orderedKeys[index];
        final animeList = _schedule[key] ?? [];
        if (animeList.isEmpty) return const SizedBox.shrink();

        return DailyRowWidget(dayKey: key, animeList: animeList);
      },
    );
  }
}
