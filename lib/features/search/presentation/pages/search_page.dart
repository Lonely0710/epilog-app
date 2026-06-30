import 'dart:developer';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide_animated/flutter_lucide_animated.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/domain/entities/media.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../../core/presentation/widgets/empty_state_widget.dart';
import '../../../../core/presentation/widgets/shared_dialog_button.dart';
import '../../domain/repositories/search_repository.dart';
import '../widgets/search_result_item.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:drama_tracker_flutter/features/search/data/datasources/search_history_service.dart';
import '../../domain/entities/search_history_item.dart';
import '../../../../app/theme/app_colors.dart';

class SearchPage extends StatefulWidget {
  final String initialQuery;
  final bool autoSearch;
  final String searchType; // 'anime' or 'movie'

  const SearchPage({
    super.key,
    this.initialQuery = '',
    this.autoSearch = false,
    this.searchType = 'all',
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const double _historyPreviewWidth = 9;
  static const List<String> _filterTabs = ['全部', '动漫', '电视剧', '电影'];

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final SearchRepository _searchRepository = SearchRepository();
  final SearchHistoryService _historyService = SearchHistoryService();

  List<Media> _results = [];
  bool _isLoading = false;
  String _errorMessage = '';
  String _lastSearchedQuery = '';
  List<SearchHistoryItem> _history = [];
  Timer? _debounce;
  int _selectedFilterIndex = 0;
  bool _isGalleryView = true;
  final LucideAnimatedIconController _deleteIconController =
      LucideAnimatedIconController();

  @override
  void initState() {
    super.initState();
    _selectedFilterIndex = _initialFilterIndex();
    _loadHistory();
    _searchController.text = widget.initialQuery;
    if (widget.autoSearch && widget.initialQuery.isNotEmpty) {
      _performSearch(widget.initialQuery);
    }
  }

  Future<void> _loadHistory() async {
    final history = await _historyService.getHistory();
    if (mounted) {
      setState(() {
        _history = history;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _deleteIconController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }
    _debounce = Timer(const Duration(milliseconds: 1000), () {
      if (query.isNotEmpty && query != _lastSearchedQuery) {
        _performSearch(query);
      }
    });
  }

  void _onSearchSubmitted(String query) {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel(); // Cancel pending debounce
    }
    _searchFocusNode.unfocus(); // Dismiss keyboard
    if (query.isNotEmpty) {
      _performSearch(query, force: true);
    }
  }

  int _initialFilterIndex() {
    return switch (widget.searchType) {
      'anime' => 1,
      'tv' => 2,
      'movie' => 3,
      _ => 0,
    };
  }

  void _handleFilterSelected(int index) {
    if (index == _selectedFilterIndex) return;

    setState(() => _selectedFilterIndex = index);

    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      _performSearch(query, force: true);
    }
  }

  void _clearSearchInput() {
    _searchController.clear();
    _debounce?.cancel();
    setState(() {
      _results = [];
      _errorMessage = '';
      _lastSearchedQuery = '';
    });
  }

  Future<void> _performSearch(String query, {bool force = false}) async {
    if (query.isEmpty) return;
    if (!force && query == _lastSearchedQuery) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _results = [];
      _lastSearchedQuery = query;
    });

    try {
      final selectedFilterIndex = _selectedFilterIndex;
      final results = await _searchByFilter(query, selectedFilterIndex);

      if (!mounted) return;
      if (selectedFilterIndex != _selectedFilterIndex ||
          query != _lastSearchedQuery) {
        return;
      }

      // Save to history (Non-blocking)
      try {
        await _historyService.addHistory(
            query, 'mixed'); // Use 'mixed' or keep existing types
        if (mounted) {
          await _loadHistory();
        }
      } catch (e) {
        log('Failed to save search history: $e');
      }

      if (!mounted) return;

      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '搜索失败: $e';
        _isLoading = false;
      });
    }
  }

  Future<List<Media>> _searchByFilter(String query, int filterIndex) async {
    switch (filterIndex) {
      case 1:
        return _searchRepository.searchAnime(query);
      case 2:
        final results = await _searchRepository.searchMovie(query);
        return results.where((item) => item.mediaType == 'tv').toList();
      case 3:
        final results = await _searchRepository.searchMovie(query);
        return results.where((item) => item.mediaType == 'movie').toList();
      default:
        return _searchRepository.searchAll(query);
    }
  }

  Future<void> _confirmClearHistory() async {
    if (_history.isEmpty) return;

    _deleteIconController.animate();
    HapticFeedback.selectionClick();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dialogContext) {
        final textColor =
            Theme.of(dialogContext).textTheme.bodyLarge?.color ?? Colors.black;

        return AppDialog(
          title: '删除历史记录',
          content: Text(
            '确认删除全部搜索历史吗？',
            textAlign: TextAlign.start,
            style: TextStyle(
              fontSize: 15,
              color: textColor.withValues(alpha: 0.72),
              height: 1.5,
              letterSpacing: 0,
            ),
          ),
          secondaryAction: AppDialogAction(
            text: '取消',
            variant: SharedDialogButtonVariant.secondary,
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          primaryAction: AppDialogAction(
            text: '删除',
            variant: SharedDialogButtonVariant.destructive,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        );
      },
    );

    if (confirmed != true) return;

    await _historyService.clearHistory();
    await _loadHistory();
  }

  Future<void> _deleteHistoryItem(SearchHistoryItem item) async {
    HapticFeedback.selectionClick();
    await _historyService.deleteHistoryItem(item.query);
    await _loadHistory();
  }

  String _truncateHistoryQuery(String query) {
    const ellipsis = '...';
    final trimmed = query.trim();
    if (trimmed.isEmpty) return trimmed;

    var width = 0.0;
    final buffer = StringBuffer();

    for (final rune in trimmed.runes) {
      final char = String.fromCharCode(rune);
      final charWidth = rune <= 0x007F ? 0.5 : 1.0;
      if (width + charWidth > _historyPreviewWidth) {
        return '${buffer.toString()}$ellipsis';
      }
      buffer.write(char);
      width += charWidth;
    }

    return trimmed;
  }

  String _filterTabIconPath(int index) {
    return switch (index) {
      0 => 'assets/icons/funnel-simple-bold.svg',
      1 => 'assets/icons/cactus-bold.svg',
      2 => 'assets/icons/monitor-play-bold.svg',
      3 => 'assets/icons/popcorn-bold.svg',
      _ => 'assets/icons/funnel-simple-bold.svg',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scaffoldBg =
        isDark ? AppColors.backgroundDark : const Color(0xFFFFFFFF);
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final showResultToolbar = _searchController.text.isNotEmpty ||
        _results.isNotEmpty ||
        _isLoading ||
        _errorMessage.isNotEmpty;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchHeader(context, textColor),
            if (showResultToolbar) _buildResultToolbar(context, textColor),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : _errorMessage.isNotEmpty
                      ? Center(
                          child: Text(
                            _errorMessage,
                            style: TextStyle(color: textColor),
                          ),
                        )
                      : (_results.isEmpty && _searchController.text.isEmpty)
                          ? _buildHistorySection(context)
                          : _results.isEmpty
                              ? _buildEmptyState(context)
                              : _buildResultsView(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsView(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 32;

    if (_isGalleryView) {
      return GridView.builder(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 16,
          childAspectRatio: 0.42,
        ),
        itemCount: _results.length,
        itemBuilder: (context, index) {
          return SearchGalleryResultItem(
            result: _results[index],
            searchType: widget.searchType,
          );
        },
      );
    }

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(top: 10, bottom: bottomPadding),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        return SearchResultItem(
          result: _results[index],
          searchType: widget.searchType,
        );
      },
    );
  }

  Widget _buildSearchHeader(BuildContext context, Color textColor) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final fieldColor =
        isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white;
    final hintColor = isDark
        ? Colors.white.withValues(alpha: 0.42)
        : AppColors.textSecondary.withValues(alpha: 0.64);
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.black.withValues(alpha: 0.08);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 8),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 50,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: textColor,
                size: 26,
              ),
              onPressed: () => context.pop(),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: fieldColor,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: borderColor),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      cursorColor: theme.colorScheme.primary,
                      textAlignVertical: TextAlignVertical.center,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        letterSpacing: 0,
                      ),
                      decoration: InputDecoration(
                        hintText: '输入电视剧、电影、动漫名称',
                        hintStyle: TextStyle(
                          color: hintColor,
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          letterSpacing: 0,
                        ),
                        filled: false,
                        fillColor: Colors.transparent,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: const EdgeInsets.fromLTRB(24, 0, 12, 0),
                      ),
                      onSubmitted: _onSearchSubmitted,
                      onChanged: (text) {
                        setState(() {});
                        _onSearchChanged(text);
                      },
                    ),
                  ),
                  if (_searchController.text.isNotEmpty) ...[
                    IconButton(
                      tooltip: '清空',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 34,
                        height: 50,
                      ),
                      icon: Icon(
                        Icons.cancel_rounded,
                        size: 20,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.42)
                            : AppColors.textSecondary.withValues(alpha: 0.48),
                      ),
                      onPressed: _clearSearchInput,
                    ),
                    Container(
                      width: 1,
                      height: 18,
                      color: dividerColor,
                    ),
                  ],
                  TextButton(
                    onPressed: () => _onSearchSubmitted(_searchController.text),
                    style: TextButton.styleFrom(
                      foregroundColor: textColor,
                      minimumSize: const Size(70, 50),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text(
                      '搜索',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultToolbar(BuildContext context, Color textColor) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.50)
        : AppColors.textSecondary.withValues(alpha: 0.72);
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.black.withValues(alpha: 0.08);
    final primaryColor = theme.colorScheme.primary;

    return SizedBox(
      height: 42,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(left: 38, right: 12),
              scrollDirection: Axis.horizontal,
              itemCount: _filterTabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 24),
              itemBuilder: (context, index) {
                final selected = index == _selectedFilterIndex;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _handleFilterSelected(index),
                  child: SizedBox(
                    height: 42,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _filterTabs[index],
                              style: TextStyle(
                                color: selected ? textColor : inactiveColor,
                                fontSize: 15,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                letterSpacing: 0,
                              ),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 160),
                              child: selected
                                  ? Padding(
                                      key: ValueKey(_filterTabs[index]),
                                      padding: const EdgeInsets.only(left: 4),
                                      child: SvgPicture.asset(
                                        _filterTabIconPath(index),
                                        width: 15,
                                        height: 15,
                                        colorFilter: ColorFilter.mode(
                                          primaryColor,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: selected ? 28 : 0,
                          height: 3,
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            width: 1,
            height: 20,
            color: dividerColor,
          ),
          IconButton(
            tooltip: _isGalleryView ? '列表视图' : '画廊视图',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 52, height: 42),
            icon: Icon(
              _isGalleryView
                  ? Icons.view_list_rounded
                  : Icons.grid_view_rounded,
              color: inactiveColor,
              size: 22,
            ),
            onPressed: () {
              setState(() => _isGalleryView = !_isGalleryView);
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildHistorySection(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ??
        (isDark ? Colors.white : Colors.black);
    final chipColor =
        isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
    final chipBorder = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final mutedIconColor = isDark
        ? Colors.white.withValues(alpha: 0.42)
        : AppColors.textSecondary.withValues(alpha: 0.74);

    if (_history.isEmpty) {
      return const SizedBox.shrink();
    }
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(38, 10, 38, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '历史记录',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  letterSpacing: 0,
                ),
              ),
              IconButton(
                tooltip: '删除历史记录',
                icon: LucideAnimatedIcon(
                  icon: delete,
                  size: 22,
                  color: mutedIconColor,
                  trigger: AnimationTrigger.manual,
                  controller: _deleteIconController,
                ),
                onPressed: _confirmClearHistory,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _history.map((item) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () {
                        _searchController.text = item.query;
                        _performSearch(item.query);
                      },
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: 38,
                          maxWidth: 190,
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 8, 24, 8),
                        decoration: BoxDecoration(
                          color: chipColor,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: chipBorder),
                          boxShadow: isDark
                              ? null
                              : [
                                  BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.035),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: Text(
                          _truncateHistoryQuery(item.query),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.normal,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -7,
                    right: -7,
                    child: Tooltip(
                      message: '删除此记录',
                      child: Material(
                        color: chipColor,
                        shape: const CircleBorder(),
                        elevation: isDark ? 0 : 2,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _deleteHistoryItem(item),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: Icon(
                              Icons.close_rounded,
                              size: 12,
                              color: mutedIconColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Builds the empty state widget with a random SVG illustration
  Widget _buildEmptyState(BuildContext context) {
    return EmptyStateWidget(
      onAction: _searchController.text.trim().isEmpty
          ? null
          : () => _performSearch(_searchController.text.trim(), force: true),
    );
  }
}
