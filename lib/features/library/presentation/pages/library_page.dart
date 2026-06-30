import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/media.dart';
import '../../../../core/presentation/widgets/app_snack_bar.dart';
import '../../../../core/router/scaffold_with_nav_bar.dart';
import '../../../collections/domain/repositories/collection_repository.dart';
import '../widgets/grid_layout_switcher.dart';
import '../widgets/jelly_page_switcher.dart';
import '../widgets/library_grid_view.dart';
import '../widgets/pull_light_switch.dart';

/// Library page with two switchable views:
/// - Media Library (movies + TV shows)
/// - Anime Wall (anime only)
///
/// Features immersive mode: ScaffoldWithNavBar automatically hides app bar
/// and bottom navigation when on this page, tap anywhere to toggle visibility.
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> with WidgetsBindingObserver {
  late final CollectionRepository _repository;
  StreamSubscription? _subscription;

  bool _isAnimeWall = false;
  bool _isLoading = true;
  bool _isCompactMode = false; // false = 2 columns, true = 3 columns
  List<Media> _mediaLibraryItems = [];
  List<Media> _animeWallItems = [];

  // Night Mode State
  bool _isNightMode = false;
  bool _immersiveLayout = false;

  // Track if data needs refresh when becoming visible
  bool _needsRefresh = false;
  // Track last data load time to avoid excessive reloads
  DateTime? _lastLoadTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repository = CollectionRepository();

    _subscription = _repository.onCollectionChanged.listen((_) {
      // Mark as needing refresh - will reload when page becomes active
      _needsRefresh = true;
      // Also try to load immediately if currently visible
      if (mounted) {
        _loadData();
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh when app resumes from background
    if (state == AppLifecycleState.resumed && _needsRefresh) {
      _loadData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if Library tab is now active and needs refresh
    final navController = NavVisibilityController.of(context);
    if (navController != null && navController.currentIndex == 2) {
      // Library is the active tab, check if refresh needed
      _checkAndRefreshIfNeeded();
    }
  }

  void _checkAndRefreshIfNeeded() {
    // Debounce: don't reload if loaded recently (within 2 seconds)
    final now = DateTime.now();
    if (_lastLoadTime != null && now.difference(_lastLoadTime!).inSeconds < 2) {
      return;
    }

    // If marked for refresh, reload
    if (_needsRefresh) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    // Record load time to prevent duplicate calls
    _lastLoadTime = DateTime.now();

    setState(() => _isLoading = true);

    try {
      final allItems = await _repository.getCollectedMedia();
      final mediaLibraryItems = allItems
          .where((item) => item.mediaType == 'movie' || item.mediaType == 'tv')
          .toList();
      final animeWallItems =
          allItems.where((item) => item.mediaType == 'anime').toList();

      if (mounted) {
        setState(() {
          _mediaLibraryItems = mediaLibraryItems;
          _animeWallItems = animeWallItems;
          _isLoading = false;
        });
        // Only reset refresh flag after successful load
        _needsRefresh = false;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppSnackBar.showNetworkError(context, onRetry: _loadData);
        // Keep _needsRefresh = true so we retry when visible again
      }
    }
  }

  void _togglePage() {
    setState(() {
      _isAnimeWall = !_isAnimeWall;
    });
  }

  void _setImmersiveLayout(bool value) {
    if (_immersiveLayout == value) return;
    setState(() {
      _immersiveLayout = value;
    });
  }

  int get _currentCount =>
      _isAnimeWall ? _animeWallItems.length : _mediaLibraryItems.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.backgroundDark
          : AppColors.surfaceVariant,
      body: Stack(
        children: [
          // 1. Main Content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 520),
                  curve: Curves.easeInOutCubicEmphasized,
                  alignment: Alignment.topCenter,
                  child: ClipRect(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      reverseDuration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      layoutBuilder: (currentChild, previousChildren) {
                        return Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            ...previousChildren,
                            if (currentChild != null) currentChild,
                          ],
                        );
                      },
                      child: _immersiveLayout
                          ? const SizedBox.shrink()
                          : _buildTitleRow(),
                    ),
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 520),
                    reverseDuration: const Duration(milliseconds: 360),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final curvedAnimation = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                        reverseCurve: Curves.easeInOutCubic,
                      );
                      final slide = Tween<Offset>(
                        begin: const Offset(0.0, 0.045),
                        end: Offset.zero,
                      ).animate(curvedAnimation);
                      final scale = Tween<double>(
                        begin: 0.992,
                        end: 1.0,
                      ).animate(curvedAnimation);

                      return FadeTransition(
                        opacity: curvedAnimation,
                        child: SlideTransition(
                          position: slide,
                          child: ScaleTransition(
                            scale: scale,
                            alignment: Alignment.topCenter,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: LibraryGridView(
                      key: ValueKey(
                        'library-${_isAnimeWall ? 'anime' : 'media'}-${_immersiveLayout ? 'imm' : 'std'}',
                      ),
                      items:
                          _isAnimeWall ? _animeWallItems : _mediaLibraryItems,
                      isLoading: _isLoading,
                      onRefresh: _loadData,
                      emptyMessage: _isAnimeWall ? '暂无动漫收藏' : '暂无影视收藏',
                      emptyIcon: _isAnimeWall
                          ? Icons.auto_awesome
                          : Icons.movie_outlined,
                      crossAxisCount: _isCompactMode ? 3 : 2,
                      topPadding: _immersiveLayout ? 6 : 12,
                      bottomPadding: _immersiveLayout ? 8 : 112,
                      showWatchStatus: !_immersiveLayout,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Darkness Overlay
          // When in "Night Mode", we show a spotlight effect where the center (posters) is lit,
          // and the surroundings are dark.
          if (_isNightMode)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(
                          0.0, 0.0), // Center of the screen (Posters)
                      radius: 1.0, // Focus light on content
                      colors: [
                        Colors.transparent, // Lit area
                        AppColors.shadowDark.withValues(
                            alpha: 0.5), // Subtler dark surroundings
                      ],
                      stops: const [0.2, 1.0],
                    ),
                  ),
                ),
              ),
            ),

          // 3. Pull Switch
          // We place it in SafeArea context so coordinates match
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Calculate anchor position:
                // Banner is 80h, Padding top 16.
                // Right padding 20.
                // Moved further right as requested (-32 instead of -60)
                final anchorX = constraints.maxWidth - 32;
                final anchorY = _immersiveLayout ? 24.0 : 94.0;

                return PullLightSwitch(
                  anchorOffset: Offset(anchorX, anchorY),
                  isDark: _isNightMode,
                  onToggle: (val) {
                    setState(() {
                      _isNightMode = val;
                    });
                    _setImmersiveLayout(val);
                    NavVisibilityController.of(context)?.setNavVisibility(!val);
                  },
                );
              },
            ),
          ),

          // Night Mode Bottom Mask - Very subtle gradient for poster fade
          // Only show a minimal fade effect, not a heavy dark mask
          if (_isNightMode)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 60, // Much smaller - just a subtle fade
              child: IgnorePointer(
                ignoring: true,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AppColors.shadowDark.withValues(alpha: 0.3),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTitleRow() {
    // 1. Determine Banner Asset & Text Color
    // Logic: Always use Red for Anime, Yellow for Movie
    final isDark = Theme.of(context).brightness ==
        Brightness.dark; // Keep for key if needed, or remove
    String bannerAsset;
    Color titleColor;

    if (_isAnimeWall) {
      bannerAsset = 'assets/images/banner_red.png';
      titleColor = Colors.white;
    } else {
      bannerAsset = 'assets/images/banner_yellow.png';
      titleColor = AppColors.textPrimary; // Yellow background needs dark text
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.15),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: Container(
          key: ValueKey(
              '$_isAnimeWall-$isDark'), // Rebuild on state/theme change
          height: 80, // Approximate height for banner
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(bannerAsset),
              fit: BoxFit
                  .cover, // Or BoxFit.fill depending on asset aspect ratio
            ),
            borderRadius:
                BorderRadius.circular(16), // Rounded corners for banner
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowDark.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
          alignment: Alignment.centerLeft,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title - No Gradient, Solid Color
              Text(
                _isAnimeWall ? 'Anime Wall' : 'Media Library',
                style: TextStyle(
                  fontFamily: 'Pacifico',
                  fontSize: 28,
                  color: titleColor,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Count indicator: "共 X 部"
                  if (!_isLoading) _buildCountIndicator(textColor: titleColor),
                  const SizedBox(width: 16),
                  _buildBannerActions(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBannerActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GridLayoutSwitcher(
          isCompactMode: _isCompactMode,
          size: 28,
          onToggle: () {
            setState(() {
              _isCompactMode = !_isCompactMode;
            });
          },
        ),
        const SizedBox(width: 8),
        JellyPageSwitcher(
          isAnimeWall: _isAnimeWall,
          size: 28,
          onToggle: _togglePage,
        ),
      ],
    );
  }

  Widget _buildCountIndicator({Color? textColor}) {
    final color = textColor ?? AppColors.textPrimary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '共 ',
          style: TextStyle(
            fontFamily: AppTheme.primaryFont,
            fontSize: 13,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '$_currentCount',
          style: TextStyle(
            fontFamily: 'LibreBaskerville',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          ' 部',
          style: TextStyle(
            fontFamily: AppTheme.primaryFont,
            fontSize: 13,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
