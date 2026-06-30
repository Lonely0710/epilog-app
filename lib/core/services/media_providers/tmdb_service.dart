import 'dart:developer';
import 'dart:convert';
import '../../domain/entities/character.dart';
import '../../services/convex_service.dart';
import '../../domain/entities/media.dart';
import '../../data/models/tmdb_model.dart';

class TmdbService {
  Future<List<Media>> searchMovie(String query) async {
    return _invokeProxyList(
      path: '/search/multi',
      query: {
        'query': query,
        'language': 'zh-CN',
        'include_adult': 'false',
      },
      filter: (item) =>
          item['media_type'] == 'movie' || item['media_type'] == 'tv',
      limit: 8,
      fetchDetails: true,
    );
  }

  Future<List<Media>> getTopRatedMovies({int page = 1}) async {
    return _invokeProxyList(
      path: '/movie/top_rated',
      query: {'language': 'zh-CN', 'page': page.toString()},
      typeForAll: 'movie',
    );
  }

  Future<List<Media>> getTopRatedTVShows({int page = 1}) async {
    return _invokeProxyList(
      path: '/tv/top_rated',
      query: {'language': 'zh-CN', 'page': page.toString()},
      typeForAll: 'tv',
    );
  }

  Future<List<Media>> discoverMovies({
    int page = 1,
    int? year,
    String? genre,
  }) async {
    return _discoverMedia('movie', page, year, genre);
  }

  Future<List<Media>> discoverTVShows({
    int page = 1,
    int? year,
    String? genre,
  }) async {
    return _discoverMedia('tv', page, year, genre);
  }

  Future<List<Media>> getTopRatedMoviesThisYear({int limit = 10}) async {
    final year = DateTime.now().year;
    final results = await _discoverMedia('movie', 1, year, null);
    return results.take(limit).toList();
  }

  Future<List<Media>> getTopRatedTVShowsThisYear({int limit = 10}) async {
    final year = DateTime.now().year;
    final results = await _discoverMedia('tv', 1, year, null);
    return results.take(limit).toList();
  }

  Future<List<Media>> _discoverMedia(
    String type,
    int page,
    int? year,
    String? genre,
  ) async {
    final queryParams = {
      'language': 'zh-CN',
      'sort_by': 'vote_average.desc',
      'vote_count.gte': '300',
      'page': page.toString(),
    };

    if (year != null) {
      if (type == 'movie') {
        queryParams['primary_release_year'] = year.toString();
      } else {
        queryParams['first_air_date_year'] = year.toString();
      }
    }

    if (genre != null) {
      final genreId = _getGenreId(type, genre);
      if (genreId != null) {
        queryParams['with_genres'] = genreId.toString();
      }
    }

    return _invokeProxyList(
      path: '/discover/$type',
      query: queryParams,
      typeForAll: type,
    );
  }

  /// Helper to construct path with query parameters
  String _buildPathWithQuery(String path, Map<String, String>? query) {
    if (query == null || query.isEmpty) return path;
    final queryString = Uri(queryParameters: query).query;
    return '$path?$queryString';
  }

  Map<String, dynamic> _decodeActionMap(dynamic response) {
    if (response is String) {
      return jsonDecode(response) as Map<String, dynamic>;
    }
    return Map<String, dynamic>.from(response as Map);
  }

  /// Core method to call the Convex TMDB proxy action.
  Future<List<Media>> _invokeProxyList({
    required String path,
    Map<String, String>? query,
    bool Function(dynamic)? filter,
    String? typeForAll,
    int? limit,
    bool fetchDetails = false,
  }) async {
    try {
      final fullPath = _buildPathWithQuery(path, query);
      log('TMDb Proxy Call: $fullPath');

      final response = await ConvexService.instance.client.action(
        name: 'tmdbProxy:proxy',
        args: {
          'path': fullPath,
          // 'query': query, // Pass null or empty map as we encoded it in path
        },
      );

      final data = _decodeActionMap(response);

      if (data['results'] == null) {
        log('TMDb Proxy Error: No results found in response');
        return [];
      }

      final results = data['results'] as List;

      // 1. Filter
      var filtered = results;
      if (filter != null) {
        filtered = results.where(filter).toList();
      }

      // 2. Limit
      if (limit != null) {
        filtered = filtered.take(limit).toList();
      }

      // 3. Map to Entity (with optional details fetch)
      if (fetchDetails) {
        final detailedResults = await Future.wait(
          filtered.map((item) => _fetchDetailViaProxy(item)),
        );
        return detailedResults.whereType<Media>().toList();
      } else {
        return filtered.map((item) {
          final type = typeForAll ?? item['media_type'];
          // Ensure we have a type, fallback to movie if unknown
          return TmdbModel.fromJson(item, type ?? 'movie').toEntity();
        }).toList();
      }
    } catch (e) {
      log('Error invoking tmdb-proxy for $path: $e');
      return [];
    }
  }

  Future<Media?> getMediaDetail(String id, String type) async {
    return _fetchDetailViaProxy({'id': id, 'media_type': type});
  }

  Future<List<Character>> getPeople(String id, String type) async {
    try {
      final path =
          type == 'tv' ? '/tv/$id/aggregate_credits' : '/movie/$id/credits';
      final response = await ConvexService.instance.client.action(
        name: 'tmdbProxy:proxy',
        args: {
          'path': path,
          'query': {'language': 'zh-CN'},
        },
      );

      final credits = _decodeActionMap(response);
      if (credits['cast'] is! List) return [];

      return (credits['cast'] as List)
          .take(12)
          .map((item) {
            final map = Map<String, dynamic>.from(item as Map);
            final profilePath = map['profile_path']?.toString();
            final role = type == 'tv'
                ? _parseTvRoleNames(map['roles'])
                : map['character']?.toString() ?? '';
            final actorName = map['name']?.toString() ?? '';
            return Character(
              name: actorName,
              imageUrl: profilePath == null || profilePath.isEmpty
                  ? ''
                  : 'https://image.tmdb.org/t/p/w185$profilePath',
              role: role,
              source: 'tmdb',
              episodeCount:
                  type == 'tv' ? _parseTvEpisodeCount(map['roles']) : null,
            );
          })
          .where((person) => person.name.isNotEmpty)
          .toList();
    } catch (e) {
      log('TMDb people fetch error: $e');
      return [];
    }
  }

  String _parseTvRoleNames(dynamic roles) {
    if (roles is! List || roles.isEmpty) return '';
    final names = roles
        .map((role) => role is Map ? role['character']?.toString() ?? '' : '')
        .where((name) => name.isNotEmpty)
        .take(2)
        .toList();
    return names.join(' / ');
  }

  int? _parseTvEpisodeCount(dynamic roles) {
    if (roles is! List || roles.isEmpty) return null;
    var total = 0;
    for (final role in roles) {
      if (role is! Map) continue;
      final count = role['episode_count'];
      if (count is int) {
        total += count;
      } else if (count is num) {
        total += count.toInt();
      }
    }
    return total > 0 ? total : null;
  }

  Future<Media?> _fetchDetailViaProxy(Map<String, dynamic> item) async {
    try {
      final mediaType = item['media_type'];
      // Clean ID: ensure no '.0' suffix
      final rawId = item['id'];
      String id;
      if (rawId is double) {
        id = rawId.toInt().toString();
      } else if (rawId is int) {
        id = rawId.toString();
      } else {
        id = rawId.toString().replaceAll('.0', '');
      }

      log('TMDb Detail Fetch: type=$mediaType, id=$id');

      final queryParams = {
        'language': 'zh-CN',
        'append_to_response': 'credits,aggregate_credits,keywords,images',
      };

      final fullPath = _buildPathWithQuery('/$mediaType/$id', queryParams);
      log('TMDb Detail Fetch Path: $fullPath');

      final response = await ConvexService.instance.client.action(
        name: 'tmdbProxy:proxy',
        args: {
          'path': fullPath,
        },
      );

      final detailData = _decodeActionMap(response);

      // log('TMDb Detail Fetch: Response keys: ${detailData.keys.toList()}');

      // Debug: Check if credits exist in response
      if (detailData.containsKey('credits')) {
        log('TMDb Detail Fetch: Credits found for $id');
        final credits = detailData['credits'];
        if (credits is Map) {
          if (credits['crew'] != null) {
            log('TMDb Detail Fetch: Crew count = ${(credits['crew'] as List).length}');
          }
          if (credits['cast'] != null) {
            log('TMDb Detail Fetch: Cast count = ${(credits['cast'] as List).length}');
          }
        } else {
          log('TMDb Detail Fetch: Credits is not a Map: $credits');
        }
      } else if (detailData.containsKey('aggregate_credits')) {
        log('TMDb Detail Fetch: Aggregate Credits found for $id');
      } else {
        log('TMDb Detail Fetch: NO credits in response for $id. Available keys: ${detailData.keys.toList()}');
      }

      final model = TmdbModel.fromJson(detailData, mediaType);
      final entity = model.toEntity();

      // Debug: Check parsed entity
      log('TMDb Parsed: directors=${entity.directors}, actors=${entity.actors}, staff=${entity.staff}');

      return entity;
    } catch (e, stack) {
      log('Error fetching details via proxy for ${item['id']}: $e\n$stack');
      // Fallback to basic info if detail fetch fails
      try {
        final model = TmdbModel.fromJson(item, item['media_type']);
        return model.toEntity();
      } catch (e) {
        return null;
      }
    }
  }

  int? _getGenreId(String type, String genreName) {
    final common = {
      '剧情': 18,
      '喜剧': 35,
      '动作': 28,
      '爱情': 10749,
      '科幻': 878,
      '动画': 16,
      '悬疑': 9648,
      '惊悚': 53,
      '犯罪': 80,
      '纪录': 99,
      '冒险': 12,
      '奇幻': 14,
      '家庭': 10751,
      '恐怖': 27,
      '历史': 36,
      '战争': 10752,
      '音乐': 10402,
      '西部': 37,
    };

    if (type == 'tv') {
      if (genreName == '动作' || genreName == '冒险') return 10759;
      if (genreName == '科幻' || genreName == '奇幻') return 10765;
      if (genreName == '战争') return 10768; // War & Politics
    }

    return common[genreName];
  }
}
