import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/collections/data/repositories/collection_repository_impl.dart';
import '../../../../core/presentation/widgets/app_snack_bar.dart';
import '../../../../core/domain/entities/media.dart';
import '../../../../core/services/media_providers/bangumi_service.dart';
import '../../../../core/services/media_providers/maoyan_service.dart';
import '../../../../core/services/media_providers/tmdb_service.dart';
import '../../../../app/theme/app_colors.dart';
import 'swipeable_media_card.dart';
import 'home_side_bar.dart';

// Data State: Feed Content
// Uses family to fetch based on index, avoiding StateProvider dependency
final homeFeedProvider = FutureProvider.autoDispose.family<List<Media>, int>((ref, index) async {
  final tmdbService = TmdbService();
  final maoyanService = MaoyanService();
  final bangumiService = BangumiService();

  try {
    List<Media> items = [];
    switch (index) {
      case 0: // Movies & TV (TMDb)
        final topMovies = await tmdbService.getTopRatedMoviesThisYear();
        final topTv = await tmdbService.getTopRatedTVShowsThisYear();
        items = [...topMovies, ...topTv];
        if (items.isEmpty) {
          final allTime = await tmdbService.getTopRatedMovies();
          items = allTime;
        }
        break;
      case 1: // Maoyan (Movies)
        items = await maoyanService.getMoviesOnShowing();
        break;
      case 2: // Bangumi (Anime)
        final schedule = await bangumiService.getWeeklySchedule();
        final List<Media> todayItems = [];
        final now = DateTime.now();
        final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final todayKey = weekdays[now.weekday - 1];
        if (schedule.containsKey(todayKey)) {
          todayItems.addAll(schedule[todayKey]!);
        }
        final trends = await bangumiService.getTrends();
        items = [...todayItems, ...trends];
        break;
      case 3: // Collection
        items = [];
        break;
    }
    // Shuffle to randomize display order
    items.shuffle();
    return items;
  } catch (e) {
    debugPrint('Home Feed Error: $e');
    return [];
  }
});

class HomeContent extends ConsumerStatefulWidget {
  const HomeContent({super.key});

  @override
  ConsumerState<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends ConsumerState<HomeContent> {
  final CardSwiperController _swiperController = CardSwiperController();
  int _selectedIndex = 0; // Managed locally

  void _onSideBarSelected(int index) {
    if (index == 3) {
      // Navigate to LibraryPage and update bottom nav bar
      context.go('/library');
      return;
    }
    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the provider with the current index argument
    final feedState = ref.watch(homeFeedProvider(_selectedIndex));

    return Column(
      children: [
        // Search bar centered across full page width
        _buildCompactSearchBar(context),
        // Main content area with sidebar and card swiper
        Expanded(
          child: Stack(
            children: [
              // Card Swiper (main content)
              Padding(
                padding: const EdgeInsets.only(left: 70),
                child: feedState.when(
                  data: (mediaList) {
                    if (mediaList.isEmpty) {
                      if (_selectedIndex == 3) {
                        return const Center(child: Text('Viewing Collection... (Coming Soon)'));
                      }
                      return const Center(child: Text('No recommendations found.'));
                    }
                    return CardSwiper(
                      key: ValueKey(_selectedIndex),
                      controller: _swiperController,
                      cardsCount: mediaList.length,
                      onSwipe: (previousIndex, currentIndex, direction) {
                        if (direction == CardSwiperDirection.right) {
                          // "Left: Pass, Right: Add to Collection (Wish)"
                          final media = mediaList[previousIndex];
                          final repo = CollectionRepositoryImpl();
                          repo.addToCollection(media, status: 'wish').then((_) {
                            if (context.mounted) {
                              AppSnackBar.showSuccess(context, '已添加到收藏');
                            }
                          }).catchError((e) {
                            debugPrint('Failed to add to collection: $e');
                          });
                        }
                        return true;
                      },
                      cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
                        return SwipeableMediaCard(media: mediaList[index]);
                      },
                    );
                  },
                  error: (err, stack) => Center(child: Text('Error: $err')),
                  loading: () => const Center(child: CircularProgressIndicator()),
                ),
              ),
              // Sidebar positioned on left
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: HomeSideBar(
                    selectedIndex: _selectedIndex,
                    onItemSelected: _onSideBarSelected,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactSearchBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 8),
      child: GestureDetector(
        onTap: () => context.push('/search?type=all'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search,
                color: isDark ? AppColors.textTertiary : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '搜索电视剧、电影、动漫...',
                style: TextStyle(
                  color: isDark ? AppColors.textTertiary : AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
