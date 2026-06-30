import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/collections/domain/repositories/collection_repository.dart';
import '../../../../core/presentation/widgets/app_snack_bar.dart';
import '../../../../core/presentation/widgets/empty_state_widget.dart';
import '../../../../core/domain/entities/media.dart';
import '../../../../core/services/media_providers/bangumi_service.dart';
import '../../../../core/services/media_providers/maoyan_service.dart';
import '../../../../core/services/media_providers/tmdb_service.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../collections/presentation/widgets/collection_category_sheet.dart';
import 'swipeable_media_card.dart';
import 'home_side_bar.dart';

// Data State: Feed Content
// Uses family to fetch based on index, avoiding StateProvider dependency
final homeFeedProvider =
    FutureProvider.autoDispose.family<List<Media>, int>((ref, index) async {
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
        final bangumiResults = await Future.wait([
          bangumiService.getWeeklySchedule(),
          bangumiService.getTrends(),
        ]);
        final schedule = bangumiResults[0] as Map<String, List<Media>>;
        final List<Media> todayItems = [];
        final now = DateTime.now();
        final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final todayKey = weekdays[now.weekday - 1];
        if (schedule.containsKey(todayKey)) {
          todayItems.addAll(schedule[todayKey]!);
        }
        final trends = bangumiResults[1] as List<Media>;
        final hydratedTodayItems =
            await bangumiService.hydrateMissingSummaries(todayItems);
        items = [...hydratedTodayItems, ...trends];
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
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 70,
                    right: 18,
                    top: 8,
                    bottom: 100,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxCardWidth = constraints.maxWidth;
                      final maxCardHeight = constraints.maxHeight;
                      final cardWidth =
                          math.min(maxCardWidth, maxCardHeight * 0.66);
                      final cardHeight =
                          math.min(maxCardHeight, cardWidth / 0.66);

                      return Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: cardWidth,
                          height: cardHeight,
                          child: feedState.when(
                            data: (mediaList) {
                              if (mediaList.isEmpty) {
                                return EmptyStateWidget(
                                  onAction: () => ref.refresh(
                                    homeFeedProvider(_selectedIndex),
                                  ),
                                );
                              }
                              return CardSwiper(
                                key: ValueKey(_selectedIndex),
                                controller: _swiperController,
                                cardsCount: mediaList.length,
                                numberOfCardsDisplayed:
                                    mediaList.length > 1 ? 2 : 1,
                                padding: EdgeInsets.zero,
                                scale: 0.94,
                                onSwipe:
                                    (previousIndex, currentIndex, direction) {
                                  if (direction == CardSwiperDirection.right) {
                                    final media = mediaList[previousIndex];
                                    // Show category sheet after a short delay to allow visual swipe completion
                                    Future.delayed(
                                        const Duration(milliseconds: 200), () {
                                      if (context.mounted) {
                                        _showCategorySheet(context, media);
                                      }
                                    });
                                  }
                                  return true;
                                },
                                cardBuilder: (context, index, percentThresholdX,
                                    percentThresholdY) {
                                  return SwipeableMediaCard(
                                    media: mediaList[index],
                                    percentX: percentThresholdX,
                                    percentY: percentThresholdY,
                                  );
                                },
                              );
                            },
                            error: (err, stack) =>
                                Center(child: Text('Error: $err')),
                            loading: () => const Center(
                                child: CircularProgressIndicator()),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // Sidebar positioned on left
              Positioned(
                left: 0,
                top: 18,
                bottom: 84,
                child: Align(
                  alignment: Alignment.center,
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
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search,
                color:
                    isDark ? AppColors.textTertiary : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '搜索电视剧、电影、动漫...',
                style: TextStyle(
                  color:
                      isDark ? AppColors.textTertiary : AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCategorySheet(BuildContext parentContext, Media media) {
    showCollectionCategorySheet(
      context: parentContext,
      useRootNavigator: true,
      onSelected: (action) {
        _addToCollection(
          parentContext,
          media,
          action.mediaType,
          action.successLabel,
          action.iconPath,
        );
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
    final repo = CollectionRepository();
    try {
      var mediaToAdd = media;

      // For TMDb, fetch full details to ensure we have staff/directors/etc.
      if (media.sourceType == 'tmdb') {
        try {
          final fullMedia = await TmdbService()
              .getMediaDetail(media.sourceId, media.mediaType);
          if (fullMedia != null) {
            mediaToAdd = fullMedia;
          }
        } catch (e) {
          debugPrint('Failed to fetch full TMDb details: $e');
          // Proceed with partial media if fetch fails
        }
      }

      final modifiedMedia = mediaToAdd.copyWith(
        mediaType: mediaType,
      );

      await repo.addToCollection(modifiedMedia, status: 'wish');

      if (context.mounted) {
        AppSnackBar.show(
          context,
          type: SnackBarType.success,
          message: '已加入$categoryLabel想看',
          customIcon: SvgPicture.asset(
            iconPath,
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(AppTheme.primary, BlendMode.srcIn),
          ),
          customColor: AppTheme.primary,
        );
      }
    } catch (e, stack) {
      debugPrint('HomeContent: Failed to add to collection: $e\n$stack');
      if (context.mounted) {
        AppSnackBar.showError(context, message: '添加失败: $e');
      }
    }
  }
}
