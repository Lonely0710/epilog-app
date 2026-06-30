import 'dart:developer';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/presentation/widgets/app_snack_bar.dart';
import '../../../../core/domain/entities/media.dart';
import '../../../../core/services/media_providers/bangumi_service.dart';
import '../../../../core/services/media_providers/maoyan_service.dart';
import '../../../../core/services/media_providers/tmdb_service.dart';
import '../../../collections/domain/repositories/collection_repository.dart';
import '../widgets/rating_display_widget.dart';
import '../widgets/watch_status_bottom_sheet.dart';
import '../widgets/watch_status_icon.dart';
import '../widgets/character_list_widget.dart';

/// Media detail page displaying full information about a movie/TV show/anime.
class MediaDetailPage extends StatefulWidget {
  final Media media;

  const MediaDetailPage({super.key, required this.media});

  @override
  State<MediaDetailPage> createState() => _MediaDetailPageState();
}

class _MediaDetailPageState extends State<MediaDetailPage> {
  final _repository = ConvexCollectionRepositoryImpl.instance;
  final _bangumiService = BangumiService();
  final _tmdbService = TmdbService();
  final _maoyanService = MaoyanService();
  Stream<Media?>? _mediaStream;
  bool _isRefreshingDetails = false;
  bool _isSynopsisExpanded = false;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    if (widget.media.id.isNotEmpty) {
      _mediaStream = _repository.watchMedia(widget.media.id);
    } else if (widget.media.sourceId.isNotEmpty &&
        widget.media.sourceType.isNotEmpty) {
      _mediaStream = _repository.watchMediaBySource(
          widget.media.sourceId, widget.media.sourceType);
    } else {
      // Fallback if no ID and no Source info (unlikely)
      _mediaStream = Stream.value(widget.media);
    }
  }

  Future<void> _updateWatchStatus(Media currentMedia, String status) async {
    // Show feedback immediately
    if (mounted) {
      final statusText = watchStatusLabel(status);
      final statusColor = watchStatusColor(status);

      AppSnackBar.show(
        context,
        type: SnackBarType.success,
        message: '已标记为“$statusText”',
        emphasizedText: '“$statusText”',
        customIcon: Icon(
          watchStatusIconData(status),
          color: statusColor,
          size: 24,
        ),
        customColor: statusColor,
      );
    }

    try {
      if (currentMedia.collectionId.isNotEmpty) {
        await _repository.updateWatchStatus(currentMedia.collectionId, status);
      } else {
        // If not collected yet, add it
        // Note: For search results, simple widget.media might lack source IDs if not parsed correctly,
        // but we assume updated parsing logic handles it.
        await _repository.addToCollection(widget.media, status: status);
      }
    } catch (e) {
      log('Error updating status: $e');
      if (mounted) {
        AppSnackBar.showError(context, message: '更新失败: $e');
      }
    }
  }

  Future<void> _removeCurrentMediaFromCollection(Media currentMedia) async {
    if (currentMedia.collectionId.isEmpty) return;

    try {
      await _repository.removeFromCollection(currentMedia.collectionId);
      if (mounted) {
        AppSnackBar.showSuccess(context, '已取消收藏');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, message: '取消收藏失败: $e');
      }
    }
  }

  void _showWatchStatusSheet(Media currentMedia) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (context) => WatchStatusBottomSheet(
        media: currentMedia,
        currentStatus: currentMedia.watchingStatus ?? 'wish',
        onStatusSelected: (status) {
          _updateWatchStatus(currentMedia, status);
          Navigator.pop(context);
        },
        onRemoveCollection: currentMedia.collectionId.isEmpty
            ? null
            : () {
                Navigator.pop(context);
                _removeCurrentMediaFromCollection(currentMedia);
              },
      ),
    );
  }

  Future<void> _addCurrentMediaToCollection(Media currentMedia) {
    final mediaType = switch (currentMedia.mediaType) {
      'anime' => 'anime',
      'tv' => 'tv',
      _ => 'movie',
    };
    final (categoryLabel, iconPath) = switch (mediaType) {
      'anime' => ('动漫墙', 'assets/icons/cactus-bold.svg'),
      'tv' => ('电视剧', 'assets/icons/monitor-play-bold.svg'),
      _ => ('电影库', 'assets/icons/popcorn-bold.svg'),
    };

    return _addToCollectionWithCategory(
      currentMedia,
      mediaType,
      categoryLabel,
      iconPath,
    );
  }

  bool _isPureEnglishTitle(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) return false;
    return RegExp(r'^[A-Za-z0-9\s\p{Punctuation}]+$', unicode: true)
        .hasMatch(normalized);
  }

  Future<void> _addToCollectionWithCategory(Media currentMedia,
      String mediaType, String categoryLabel, String iconPath) async {
    // Show success feedback immediately
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

    try {
      // Determine preferred source type based on collection category:
      // - movie/tv: prefer TMDB as source
      // - anime: prefer Bangumi (bgm) as source
      String preferredSourceType;
      String preferredSourceId;
      String preferredSourceUrl;

      if (mediaType == 'anime') {
        if (currentMedia.sourceType == 'bgm') {
          preferredSourceType = 'bgm';
          preferredSourceId = currentMedia.sourceId;
          preferredSourceUrl = currentMedia.sourceUrl;
        } else {
          preferredSourceType = currentMedia.sourceType;
          preferredSourceId = currentMedia.sourceId;
          preferredSourceUrl = currentMedia.sourceUrl;
        }
      } else {
        if (currentMedia.sourceType == 'tmdb') {
          preferredSourceType = 'tmdb';
          preferredSourceId = currentMedia.sourceId;
          preferredSourceUrl = currentMedia.sourceUrl;
        } else {
          preferredSourceType = currentMedia.sourceType;
          preferredSourceId = currentMedia.sourceId;
          preferredSourceUrl = currentMedia.sourceUrl;
        }
      }

      // Modify media with preferred source type
      final modifiedMedia = currentMedia.copyWith(
        mediaType: mediaType,
        sourceType: preferredSourceType,
        sourceId: preferredSourceId,
        sourceUrl: preferredSourceUrl,
      );

      await _repository.addToCollection(modifiedMedia, status: 'wish');
      // No setState needed, stream will update
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, message: '添加失败: $e');
      }
    }
  }

  Future<void> _refreshMediaDetails(Media media) async {
    if (_isRefreshingDetails) return;

    setState(() => _isRefreshingDetails = true);

    try {
      var mediaForUpdate = media;
      if (mediaForUpdate.id.isEmpty) {
        final ensuredId = await _repository.ensureMedia(mediaForUpdate);
        if (ensuredId != null && ensuredId.isNotEmpty) {
          mediaForUpdate = mediaForUpdate.copyWith(id: ensuredId);
        }
      }
      if (mediaForUpdate.id.isEmpty) {
        throw Exception('无法创建条目缓存');
      }

      final sources = await _repository.getMediaSources(mediaForUpdate.id);
      final refreshed = await _fetchPreferredDetails(mediaForUpdate, sources);
      if (refreshed == null) {
        throw Exception('没有找到可用的数据源');
      }

      final merged = _mergeMediaDetails(mediaForUpdate, refreshed);
      await _repository.updateMediaDetails(mediaForUpdate.id, merged);

      if (mounted) {
        AppSnackBar.showSuccess(context, '条目信息已更新');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, message: '重新拉取失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshingDetails = false);
      }
    }
  }

  Future<Media?> _fetchPreferredDetails(
    Media media,
    List<MediaSourceSnapshot> sources,
  ) async {
    MediaSourceSnapshot? pick(String type) {
      for (final source in sources) {
        if (source.sourceType == type && source.sourceId.isNotEmpty) {
          return source;
        }
      }
      return null;
    }

    if (media.mediaType == 'anime') {
      final bgm = pick('bgm');
      if (bgm != null) return _bangumiService.getAnimeDetail(bgm.sourceId);
    }

    if (media.mediaType == 'movie' || media.mediaType == 'tv') {
      final tmdb = pick('tmdb');
      if (tmdb != null) {
        try {
          final tmdbDetail =
              await _tmdbService.getMediaDetail(tmdb.sourceId, media.mediaType);
          if (tmdbDetail != null) return tmdbDetail;
        } catch (e) {
          log('TMDb refresh failed, trying fallback sources: $e');
        }
      }

      final maoyan = pick('maoyan');
      if (maoyan != null) {
        return _maoyanService.getMovieDetail(maoyan.sourceId);
      }
    }

    if (media.sourceId.isNotEmpty) {
      if (media.sourceType == 'bgm') {
        return _bangumiService.getAnimeDetail(media.sourceId);
      }
      if (media.sourceType == 'tmdb') {
        try {
          return await _tmdbService.getMediaDetail(
              media.sourceId, media.mediaType);
        } catch (e) {
          log('TMDb direct refresh failed: $e');
        }
      }
      if (media.sourceType == 'maoyan') {
        return _maoyanService.getMovieDetail(media.sourceId);
      }
    }

    return null;
  }

  Media _mergeMediaDetails(Media current, Media refreshed) {
    String keepOrFill(String currentValue, String refreshedValue) {
      return _isMissingText(currentValue) && _hasUsableText(refreshedValue)
          ? refreshedValue
          : currentValue;
    }

    return current.copyWith(
      titleZh: keepOrFill(current.titleZh, refreshed.titleZh),
      titleOriginal: keepOrFill(current.titleOriginal, refreshed.titleOriginal),
      releaseDate: keepOrFill(current.releaseDate, refreshed.releaseDate),
      duration: keepOrFill(current.duration, refreshed.duration),
      year: keepOrFill(current.year, refreshed.year),
      posterUrl: keepOrFill(current.posterUrl, refreshed.posterUrl),
      summary: keepOrFill(current.summary, refreshed.summary),
      staff: keepOrFill(current.staff, refreshed.staff),
      directors: current.directors.isEmpty && refreshed.directors.isNotEmpty
          ? refreshed.directors
          : current.directors,
      actors: current.actors.isEmpty && refreshed.actors.isNotEmpty
          ? refreshed.actors
          : current.actors,
      networks: current.networks.isEmpty && refreshed.networks.isNotEmpty
          ? refreshed.networks
          : current.networks,
      rating: current.rating <= 0 && refreshed.rating > 0
          ? refreshed.rating
          : current.rating,
      ratingDouban: current.ratingDouban <= 0 && refreshed.ratingDouban > 0
          ? refreshed.ratingDouban
          : current.ratingDouban,
      ratingImdb: current.ratingImdb <= 0 && refreshed.ratingImdb > 0
          ? refreshed.ratingImdb
          : current.ratingImdb,
      ratingBangumi: current.ratingBangumi <= 0 && refreshed.ratingBangumi > 0
          ? refreshed.ratingBangumi
          : current.ratingBangumi,
      ratingMaoyan: current.ratingMaoyan <= 0 && refreshed.ratingMaoyan > 0
          ? refreshed.ratingMaoyan
          : current.ratingMaoyan,
    );
  }

  bool _isMissingText(String value) {
    final text = value.trim();
    if (text.isEmpty) return true;
    const placeholders = {
      '未知',
      '未知标题',
      '未知日期',
      '暂无简介',
      '暂无制作信息',
      '----',
      '0分钟',
    };
    return placeholders.contains(text);
  }

  bool _hasUsableText(String value) {
    final text = value.trim();
    return text.isNotEmpty && !_isMissingText(text);
  }

  @override
  Widget build(BuildContext context) {
    if (_mediaStream == null) {
      return const Center(
        child: CircularProgressIndicator(),
      ); // Should not happen
    }

    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<Media?>(
      stream: _mediaStream,
      builder: (context, snapshot) {
        // Use latest media from stream, or fallback to widget.media
        final media = snapshot.data ?? widget.media;

        // If stream returned null (e.g. not found in DB), media is widget.media (uncollected)
        // If stream returned object (found), media is that object (collected)

        final currentIsCollected = media.isCollected;
        final currentWatchStatus = media.watchingStatus ?? 'wish';

        return Scaffold(
          backgroundColor: bgColor,
          body: CustomScrollView(
            slivers: [
              _buildSliverAppBar(context, media),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitleRow(
                          media, currentIsCollected, currentWatchStatus),
                      const SizedBox(height: 24),
                      RatingDisplayWidget(media: media),
                      const SizedBox(height: 32),

                      // Synopsis
                      Row(
                        children: [
                          Text(
                            '简介',
                            style: TextStyle(
                              fontFamily: AppTheme.primaryFont,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color:
                                  isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: '重新拉取数据',
                            onPressed: _isRefreshingDetails
                                ? null
                                : () => _refreshMediaDetails(media),
                            icon: _isRefreshingDetails
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded),
                            color: isDark
                                ? Colors.white70
                                : AppColors.textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildExpandableSynopsis(media.summary),
                      const SizedBox(height: 32),

                      // Staff / Cast
                      if (media.mediaType == 'anime') ...[
                        _buildAnimeStaffSection(media),
                        CharacterListWidget(media: media),
                      ] else ...[
                        if (media.directors.isNotEmpty) ...[
                          _buildDirectorsSection(media),
                          const SizedBox(height: 24),
                        ],
                        if (media.actors.isNotEmpty) ...[
                          _buildActorsSection(media),
                          const SizedBox(height: 24),
                        ],
                        CharacterListWidget(media: media),
                      ],
                      SizedBox(
                        height: MediaQuery.of(context).padding.bottom + 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper methods...

  Widget _buildSliverAppBar(BuildContext context, Media media) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final buttonBg = isDark
        ? Colors.black.withValues(alpha: 0.5)
        : AppColors.surfaceElevated.withValues(alpha: 0.9);

    return SliverAppBar(
      expandedHeight: MediaQuery.of(context).size.width * 1.5,
      pinned: true,
      backgroundColor: bgColor,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: buttonBg,
          child: IconButton(
            icon: Icon(Icons.arrow_back,
                color: isDark ? Colors.white : AppColors.textPrimary),
            onPressed: () => context.pop(),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: media.posterUrl,
              child: CachedNetworkImage(
                imageUrl: media.posterUrl,
                fit: BoxFit.cover,
                // Ensure image covers the space completely
                alignment: Alignment.topCenter,
                placeholder: (context, url) => Container(
                  color: AppColors.surfaceDeep,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
                errorWidget: (context, url, error) => Image.asset(
                  'assets/icons/ic_np_poster.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // Gradient Overlay - Extended slightly to prevent "leakage"
            Positioned(
              bottom: -1, // Overlap slightly
              left: 0,
              right: 0,
              height: 250, // Increased height for better gradient smooth
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      bgColor.withValues(alpha: 0.6),
                      bgColor.withValues(alpha: 0.9),
                      bgColor,
                    ],
                    stops: const [0.0, 0.5, 0.8, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Text(
                media.titleOriginal.isNotEmpty
                    ? media.titleOriginal
                    : media.titleZh,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? Colors.white
                      : textColor, // Brighter in dark mode
                  shadows: [
                    Shadow(
                      color: isDark ? Colors.black : AppColors.surfaceElevated,
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleRow(Media media, bool isCollected, String watchStatus) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String? episodeText;
    if (media.mediaType == 'anime' || media.mediaType == 'tv') {
      episodeText = media.duration.isNotEmpty ? media.duration : '??';
      if (RegExp(r'^\d+$').hasMatch(episodeText)) {
        episodeText = '$episodeText集';
      } else {
        episodeText = episodeText.replaceAll('共', '');
      }
    }

    final hasOriginalTitle =
        media.titleOriginal.isNotEmpty && media.titleOriginal != media.titleZh;
    final metaText = media.mediaType == 'movie' && media.duration.isNotEmpty
        ? media.duration
        : episodeText;
    final metaIcon =
        media.mediaType == 'movie' ? Icons.access_time : Icons.layers_outlined;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                media.titleZh,
                style: TextStyle(
                  fontFamily: 'JingHuaSC',
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  height: 1.08,
                ),
              ),
              if (hasOriginalTitle) ...[
                const SizedBox(height: 6),
                Text(
                  media.titleOriginal,
                  style: (_isPureEnglishTitle(media.titleOriginal)
                          ? GoogleFonts.ebGaramond(
                              fontWeight: FontWeight.w800,
                            )
                          : const TextStyle(
                              fontFamily: 'AOTFStdHeavy',
                              fontWeight: FontWeight.w700,
                            ))
                      .copyWith(
                    fontSize: 19,
                    color: isDark ? Colors.white70 : AppColors.textSecondary,
                    height: 1.1,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, maxWidth: 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (metaText != null) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      metaIcon,
                      color: isDark ? Colors.white70 : AppColors.textPrimary,
                      size: media.mediaType == 'movie' ? 16 : 20,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        metaText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.primaryFont,
                          fontSize: media.mediaType == 'movie' ? 14 : 18,
                          color:
                              isDark ? Colors.white70 : AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              InkWell(
                onTap: () {
                  if (isCollected) {
                    _showWatchStatusSheet(media);
                  } else {
                    _addCurrentMediaToCollection(media);
                  }
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _getStatusColor(isCollected, watchStatus)
                        .withValues(alpha: isDark ? 0.16 : 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getStatusIcon(isCollected, watchStatus),
                    color: _getStatusColor(isCollected, watchStatus),
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnimeStaffSection(Media media) {
    // Parse staff string: "Director Name / Original Name / Script Name"
    // Also handle if staff is empty or doesn't have enough parts
    log('Building Anime Staff Section. Staff string: "${media.staff}"');

    final staffParts = media.staff.split('/');
    final directorName = staffParts.isNotEmpty ? staffParts[0].trim() : '';
    final originalName = staffParts.length > 1 ? staffParts[1].trim() : '';
    final scriptName = staffParts.length > 2 ? staffParts[2].trim() : '';
    final charDesignName = staffParts.length > 3 ? staffParts[3].trim() : '';

    // If parsing failed to get any meaningful names (e.g. empty string),
    // try to fall back to the standard directors/actors lists if available.
    if (directorName.isEmpty &&
        originalName.isEmpty &&
        scriptName.isEmpty &&
        charDesignName.isEmpty) {
      if (media.directors.isNotEmpty || media.actors.isNotEmpty) {
        log('Staff string parsing yielded nothing, falling back to standard directors/actors.');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (media.directors.isNotEmpty) ...[
              _buildDirectorsSection(media),
              const SizedBox(height: 24),
            ],
            if (media.actors.isNotEmpty) ...[
              _buildActorsSection(media),
              const SizedBox(height: 24),
            ],
          ],
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (directorName.isNotEmpty) ...[
          _buildStaffSectionTitle('导演', Icons.person_rounded, directorName),
          const SizedBox(height: 16),
        ],
        if (originalName.isNotEmpty) ...[
          _buildStaffSectionTitle('原作', Icons.menu_book, originalName),
          const SizedBox(height: 16),
        ],
        if (scriptName.isNotEmpty) ...[
          _buildStaffSectionTitle('脚本', Icons.edit_note, scriptName),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildStaffSectionTitle(String title, IconData icon, String content) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : AppColors.textPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 22,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildGlassChip(content),
          ],
        ),
      ],
    );
  }

  Widget _buildDirectorsSection(Media media) {
    return _buildSectionWithChips(
      '导演',
      Icons.person_rounded,
      media.directors,
    );
  }

  Widget _buildActorsSection(Media media) {
    final isAnime = media.mediaType == 'anime';
    return _buildSectionWithChips(
      isAnime ? 'CV' : '主演',
      isAnime ? Icons.mic_none_outlined : Icons.face_outlined,
      media.actors,
    );
  }

  Widget _buildSectionWithChips(
      String title, IconData icon, List<String> items) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : AppColors.textPrimary;

    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 22,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map(_buildGlassChip).toList(),
        ),
      ],
    );
  }

  Widget _buildGlassChip(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final glassBase = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final backgroundColor = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: isDark ? 0.08 : 0.025),
      glassBase.withValues(alpha: isDark ? 0.58 : 0.34),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
            blurRadius: 18,
            spreadRadius: -12,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.34),
                      width: 1,
                    ),
                  ),
                ),
              ),
              LiquidGlassLayer(
                settings: LiquidGlassSettings(
                  refractiveIndex: 1.19,
                  thickness: isDark ? 18 : 22,
                  blur: isDark ? 8 : 10,
                  saturation: isDark ? 1.16 : 1.26,
                  chromaticAberration: 0.012,
                  lightAngle: -0.7853981633974483,
                  lightIntensity: isDark ? 0.62 : 0.78,
                  ambientStrength: isDark ? 0.10 : 0.16,
                  glassColor: Colors.white.withValues(
                    alpha: isDark ? 0.04 : 0.02,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableSynopsis(String summary) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (summary.isEmpty) return const SizedBox.shrink();
    final textStyle = TextStyle(
      fontFamily: AppTheme.primaryFont,
      fontSize: 15,
      height: 1.6,
      color: isDark ? Colors.white70 : AppColors.textSecondary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 240),
          firstCurve: Curves.easeOutCubic,
          secondCurve: Curves.easeOutCubic,
          sizeCurve: Curves.easeOutCubic,
          crossFadeState: _isSynopsisExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: Text(
            summary,
            style: textStyle,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
          secondChild: Text(
            summary,
            style: textStyle,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.center,
          child: TextButton.icon(
            onPressed: () {
              setState(() => _isSynopsisExpanded = !_isSynopsisExpanded);
            },
            icon: Icon(
              _isSynopsisExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 24,
            ),
            label: Text(_isSynopsisExpanded ? '收起简介' : '展开完整简介'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getStatusIcon(bool isCollected, String watchStatus) {
    if (!isCollected) return watchStatusIconData('wish', filled: false);
    return watchStatusIconData(watchStatus);
  }

  Color _getStatusColor(bool isCollected, String watchStatus) {
    if (!isCollected) return watchStatusColor('wish');
    return watchStatusColor(watchStatus);
  }
}
