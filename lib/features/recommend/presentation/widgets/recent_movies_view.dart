import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/domain/entities/media.dart';
import '../../../../core/presentation/widgets/app_snack_bar.dart';
import '../../../../core/presentation/widgets/empty_state_widget.dart';
import '../../../../core/services/media_providers/maoyan_service.dart';
import '../../../../core/services/media_providers/tmdb_service.dart';
import '../../data/repositories/recommend_repository_impl.dart';
import '../../domain/repositories/recommend_repository.dart';
import 'recent_movie_item.dart';
// Note: In real app, use dependency injection

class RecentMoviesView extends StatefulWidget {
  const RecentMoviesView({super.key});

  @override
  State<RecentMoviesView> createState() => _RecentMoviesViewState();
}

class _RecentMoviesViewState extends State<RecentMoviesView> {
  late final RecommendRepository _repository;
  List<Media> _movies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Simple manual DI for now
    _repository = RecommendRepositoryImpl(MaoyanService(), TmdbService());
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      final movies = await _repository.getRecentMovies();

      if (mounted) {
        setState(() {
          _movies = movies;
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

    if (_movies.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.movie_outlined,
        onAction: _loadData,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 4, bottom: 110),
          itemCount: _movies.length,
          itemBuilder: (context, index) {
            final movie = _movies[index];
            return RecentMovieItem(
              movie: movie,
            );
          },
        ),
      ),
    );
  }
}
