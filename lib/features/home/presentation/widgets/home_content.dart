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
import '../../../../app/theme/app_theme.dart';
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
                          final media = mediaList[previousIndex];
                          // Show category sheet after a short delay to allow visual swipe completion
                          Future.delayed(const Duration(milliseconds: 200), () {
                            if (context.mounted) {
                              _showCategorySheet(context, media);
                            }
                          });
                        }
                        return true;
                      },
                      cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
                        return SwipeableMediaCard(
                          media: mediaList[index],
                          percentX: percentThresholdX,
                          percentY: percentThresholdY,
                        );
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

  void _showCategorySheet(BuildContext context, Media media) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                '加入资料库',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildOption(
              context,
              iconWidget: Icon(Icons.movie_creation_outlined, color: AppTheme.primary, size: 20),
              label: 'Movie Library',
              onTap: () => _addToCollection(context, media, 'movie', 'Movie Library', 'assets/icons/ic_popcorn.png'),
            ),
            _buildOption(
              context,
              iconWidget: Icon(Icons.tv, color: AppTheme.primary, size: 20),
              label: 'TV Show',
              onTap: () => _addToCollection(context, media, 'tv', 'TV Show', 'assets/icons/ic_popcorn.png'),
            ),
            _buildOption(
              context,
              iconWidget: Image.asset('assets/icons/ic_bilibili.png', width: 20, height: 20),
              label: 'Anime Wall',
              onTap: () => _addToCollection(context, media, 'anime', 'Anime Wall', 'assets/icons/ic_bilibili.png'),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required Widget iconWidget,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: iconWidget,
      ),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Future<void> _addToCollection(
    BuildContext context,
    Media media,
    String mediaType,
    String categoryLabel,
    String iconPath,
  ) async {
    final repo = CollectionRepositoryImpl();
    try {
      final modifiedMedia = media.copyWith(
        mediaType: mediaType,
      );

      await repo.addToCollection(modifiedMedia, status: 'wish');

      if (context.mounted) {
        AppSnackBar.show(
          context,
          type: SnackBarType.success,
          message: '已加入$categoryLabel想看',
          customIcon: Image.asset(
            iconPath,
            width: 24,
            height: 24,
            fit: BoxFit.contain,
          ),
          customColor: AppColors.starActive,
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.showError(context, message: '添加失败: $e');
      }
    }
  }
}
