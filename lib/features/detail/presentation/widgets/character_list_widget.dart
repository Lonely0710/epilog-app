import 'dart:developer';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/domain/entities/character.dart';
import '../../../../core/domain/entities/media.dart';
import '../../../../core/services/media_providers/bangumi_service.dart';
import '../../../../core/services/media_providers/tmdb_service.dart';
import '../../../collections/domain/repositories/collection_repository.dart';

class CharacterListWidget extends StatefulWidget {
  final Media media;

  const CharacterListWidget({super.key, required this.media});

  @override
  State<CharacterListWidget> createState() => _CharacterListWidgetState();
}

class _CharacterListWidgetState extends State<CharacterListWidget> {
  final _repository = ConvexCollectionRepositoryImpl.instance;
  final _bangumiService = BangumiService();
  final _tmdbService = TmdbService();
  List<Character> _characters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCharacters();
  }

  @override
  void didUpdateWidget(CharacterListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.id != widget.media.id ||
        oldWidget.media.sourceId != widget.media.sourceId ||
        oldWidget.media.sourceType != widget.media.sourceType) {
      setState(() {
        _characters = [];
        _isLoading = true;
      });
      _loadCharacters();
    }
  }

  Future<void> _loadCharacters() async {
    final mediaForCache = widget.media;

    if (mediaForCache.id.isNotEmpty) {
      final cached = await _repository.getCachedPeopleInfo(mediaForCache);
      if (_hasUsableCachedPeople(mediaForCache, cached) && mounted) {
        setState(() {
          _characters = cached;
          _isLoading = false;
        });
        return;
      }
    }

    try {
      final chars = await _fetchPeople(mediaForCache);
      if (chars.isNotEmpty && mediaForCache.id.isNotEmpty) {
        await _repository.upsertPeopleInfo(mediaForCache, chars);
      }
      if (mounted) {
        setState(() {
          _characters = chars;
          _isLoading = false;
        });
      }
    } catch (e) {
      log('Error loading characters: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<List<Character>> _fetchPeople(Media media) async {
    if (media.mediaType == 'anime' ||
        (media.mediaType == 'movie' && media.ratingBangumi > 0)) {
      final bgm = await _findSource(media, 'bgm');
      if (bgm != null) {
        final bangumiCharacters =
            await _bangumiService.getCharacters(bgm.sourceId);
        if (bangumiCharacters.isNotEmpty) return bangumiCharacters;
      }
    }

    if (media.mediaType == 'movie' || media.mediaType == 'tv') {
      final tmdb = await _findSource(media, 'tmdb');
      if (tmdb != null) {
        final tmdbPeople =
            await _tmdbService.getPeople(tmdb.sourceId, media.mediaType);
        if (tmdbPeople.isNotEmpty) return tmdbPeople;
      }
    }

    return _buildFallbackPeople(media);
  }

  List<Character> _buildFallbackPeople(Media media) {
    if (media.actors.isEmpty) return [];
    return media.actors
        .where((name) => name.trim().isNotEmpty)
        .take(12)
        .map(
          (name) => Character(
            name: name.trim(),
            imageUrl: '',
            role: 'fallback_actor',
            source: 'fallback_actor',
          ),
        )
        .toList();
  }

  bool _hasUsableCachedPeople(Media media, List<Character> people) {
    if (people.isEmpty) return false;
    if (media.mediaType != 'movie' && media.mediaType != 'tv') return true;

    return people.any((person) {
      if (person.source == 'tmdb') return person.imageUrl.isNotEmpty;
      final isLegacyTmdb = person.role == 'tmdb';
      final isFallback = person.source == 'fallback_actor' ||
          person.role == 'fallback_actor' ||
          person.imageUrl.isEmpty;
      return !isLegacyTmdb && !isFallback;
    });
  }

  Future<MediaSourceSnapshot?> _findSource(
    Media media,
    String sourceType,
  ) async {
    final directSource = _directSource(media, sourceType);
    if (directSource != null) return directSource;

    if (media.id.isEmpty) return null;

    final dbSources = await _repository.getMediaSources(media.id);
    return _pickSource(dbSources, sourceType);
  }

  MediaSourceSnapshot? _directSource(Media media, String sourceType) {
    if (media.sourceType != sourceType || media.sourceId.isEmpty) return null;
    return MediaSourceSnapshot(
      sourceType: media.sourceType,
      sourceId: media.sourceId,
      sourceUrl: media.sourceUrl,
    );
  }

  MediaSourceSnapshot? _pickSource(
    List<MediaSourceSnapshot> sources,
    String sourceType,
  ) {
    for (final source in sources) {
      if (source.sourceType == sourceType && source.sourceId.isNotEmpty) {
        return source;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : AppColors.textPrimary;
    const title = '主要角色';

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
                Icons.nature_people,
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
        if (_isLoading)
          const SizedBox(
            height: 110,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_characters.isEmpty)
          const SizedBox.shrink()
        else
          SizedBox(
            height: 250,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              scrollDirection: Axis.horizontal,
              itemCount: _characters.length,
              separatorBuilder: (ctx, i) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final char = _characters[index];
                return _buildCharacterCard(context, char);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCharacterCard(BuildContext context, Character char) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.grey.withValues(alpha: 0.2);

    final isTmdbPerson = char.source == 'tmdb';
    final isFallbackActor =
        char.source == 'fallback_actor' || char.role == 'fallback_actor';
    final isAnime = widget.media.mediaType == 'anime';
    final title =
        char.nameCn.isNotEmpty && !isTmdbPerson ? char.nameCn : char.name;
    final subtitle = isTmdbPerson
        ? (char.role.isEmpty ? '' : '饰：${char.role}')
        : isFallbackActor
            ? (isAnime ? 'CV' : '演员')
            : (char.cv.isEmpty ? '' : 'CV ${char.cv}');
    final metaText = isTmdbPerson && char.episodeCount != null
        ? '共 ${char.episodeCount} 集'
        : '';
    const fallbackImage = 'assets/icons/ic_np_poster.png';

    return Container(
      width: 120,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: char.imageUrl.isEmpty
                ? Image.asset(
                    fallbackImage,
                    height: 160,
                    width: 120,
                    fit: BoxFit.cover,
                  )
                : CachedNetworkImage(
                    imageUrl: char.imageUrl,
                    height: 160, // Taller image (3:4 ratio with width 120)
                    width: 120,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    placeholder: (context, url) => Container(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      child: Image.asset(
                        fallbackImage,
                        height: 160,
                        width: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (char.role.isNotEmpty &&
                      !isTmdbPerson &&
                      !isFallbackActor) ...[
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        char.role,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                  ],
                  if (metaText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      metaText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
