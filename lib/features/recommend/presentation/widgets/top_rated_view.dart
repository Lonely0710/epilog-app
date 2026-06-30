import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../../app/animations/dialog_animations.dart';
import '../../../../core/domain/entities/media.dart';
import '../../../../core/presentation/widgets/app_snack_bar.dart';
import '../../../../core/presentation/widgets/pagination_grid_view.dart';
import '../../../../core/services/media_providers/maoyan_service.dart';
import '../../../../core/services/media_providers/tmdb_service.dart';
import '../../data/repositories/recommend_repository_impl.dart';
import '../../domain/repositories/recommend_repository.dart';
import 'filter_bar.dart';
import 'filter_sheet.dart';
import 'top_rated_item.dart';

class TopRatedView extends StatefulWidget {
  const TopRatedView({super.key});

  @override
  State<TopRatedView> createState() => _TopRatedViewState();
}

class _TopRatedViewState extends State<TopRatedView> {
  late final RecommendRepository _repository;

  List<Media> _items = [];
  bool _isLoading = false;

  int _currentPage = 1;
  bool _hasMore = true;

  // Filter State
  String _currentType = '电视剧'; // '电影' or '电视剧'
  int? _selectedYear = DateTime.now().year;
  String? _selectedGenre;

  @override
  void initState() {
    super.initState();
    // Manual DI
    _repository = RecommendRepositoryImpl(MaoyanService(), TmdbService());

    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_isLoading) return;

    if (mounted) {
      setState(() {
        if (_currentPage == 1) _isLoading = true;
      });
    }

    try {
      List<Media> newItems = [];

      // Note: If filters are present, we use 'discover' endpoint.
      // If no filters, we use standard 'top_rated' endpoint.

      if (_currentType == '电影') {
        if (_selectedYear != null || _selectedGenre != null) {
          newItems = await _repository.discoverMovies(_currentPage,
              year: _selectedYear, genre: _selectedGenre);
        } else {
          newItems = await _repository.getTopRatedMovies(_currentPage);
        }
      } else {
        if (_selectedYear != null || _selectedGenre != null) {
          newItems = await _repository.discoverTVShows(_currentPage,
              year: _selectedYear, genre: _selectedGenre);
        } else {
          newItems = await _repository.getTopRatedTVShows(_currentPage);
        }
      }

      // Check if we have more data
      if (newItems.isEmpty) {
        _hasMore = false;
      }

      if (mounted) {
        setState(() {
          // If page 1, replace list. Else append.
          if (_currentPage == 1) {
            _items = newItems;
          } else {
            _items.addAll(newItems);
          }
          _currentPage++;
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

  void _onTypeChanged(String newType) {
    if (_currentType == newType) return;
    setState(() {
      _currentType = newType;
      _items = [];
      _currentPage = 1;
      _hasMore = true;
    });
    _loadData(); // Will set isLoading = true
  }

  void _showFilterSheet() async {
    final result = await showAnimatedBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => FilterSheet(
        initialYear: _selectedYear,
        initialGenre: _selectedGenre,
      ),
    );

    if (result != null) {
      // Even if result is same, we might refresh or just set state
      setState(() {
        _selectedYear = result['year'];
        _selectedGenre = result['genre'];
        // Refresh list
        _items = [];
        _currentPage = 1;
        _hasMore = true;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter Bar
        FilterBar(
          currentType: _currentType,
          onTypeChanged: _onTypeChanged,
          onFilterTap: _showFilterSheet,
          selectedYear: _selectedYear,
          selectedGenre: _selectedGenre,
          onYearClear: () {
            setState(() {
              _selectedYear = null;
              _items = [];
              _currentPage = 1;
              _hasMore = true;
            });
            _loadData();
          },
          onGenreClear: () {
            setState(() {
              _selectedGenre = null;
              _items = [];
              _currentPage = 1;
              _hasMore = true;
            });
            _loadData();
          },
        ),

        // Grid Content
        Expanded(
          child: CorePaginationGridView<Media>(
            items: _items,
            isLoading: _isLoading && _currentPage > 1, // Loading more
            hasMore: _hasMore,
            onLoadMore: _loadData,
            onRefreshEmpty: _loadData,
            emptyWidget: _isLoading && _currentPage == 1
                ? Align(
                    alignment: const Alignment(0, -0.28),
                    child: Lottie.asset(
                      'assets/lottie/movie_loading.json',
                      width: 200,
                      height: 200,
                    ),
                  )
                : null,
            itemBuilder: (context, index, item) {
              return TopRatedItem(media: item, rank: index + 1);
            },
          ),
        ),
      ],
    );
  }
}
