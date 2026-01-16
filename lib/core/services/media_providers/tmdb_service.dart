import 'dart:developer';
import 'package:supabase_flutter/supabase_flutter.dart';
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
      filter: (item) => item['media_type'] == 'movie' || item['media_type'] == 'tv',
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

  /// Core method to call Supabase Edge Function
  Future<List<Media>> _invokeProxyList({
    required String path,
    Map<String, String>? query,
    bool Function(dynamic)? filter,
    String? typeForAll,
    int? limit,
    bool fetchDetails = false,
  }) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'tmdb-proxy',
        body: {
          'path': path,
          'query': query,
        },
      );

      // Edge Function returns { data: ... } or direct array depending on implementation
      // Our function returns standard TMDb JSON structure directly
      final data = response.data;

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
        // Detailed fetch also goes through proxy individually
        // Note: For performance, ideally specific detail endpoint should be used
        // But for consistency with V3 implementation, we iterate.
        // Optimization: We could add a 'batch' endpoint to proxy later.
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

  Future<Media?> _fetchDetailViaProxy(Map<String, dynamic> item) async {
    try {
      final mediaType = item['media_type'];
      final id = item['id'].toString();

      final response = await Supabase.instance.client.functions.invoke(
        'tmdb-proxy',
        body: {
          'path': '/$mediaType/$id',
          'query': {
            'language': 'zh-CN',
            'append_to_response': 'credits',
          }
        },
      );

      final detailData = response.data;
      final model = TmdbModel.fromJson(detailData, mediaType);
      return model.toEntity();
    } catch (e) {
      log('Error fetching details via proxy for ${item['id']}: $e');
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
    // ... genre mapping logic remains unchanged ...
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
