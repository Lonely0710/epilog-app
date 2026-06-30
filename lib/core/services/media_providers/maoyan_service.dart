import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import '../../domain/entities/media.dart';
import '../../data/models/maoyan_model.dart';

class MaoyanService {
  // Mobile public API endpoint
  static const String _baseUrl = 'https://m.maoyan.com/ajax/search';

  Future<List<Media>> searchMovie(String query) async {
    final url = '$_baseUrl?kw=$query&cityId=1&stype=-1';
    log('Searching Maoyan: $url');

    try {
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent':
            'Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1',
      });

      if (response.statusCode != 200) {
        log('Maoyan API Error: ${response.statusCode}');
        return [];
      }

      final data = json.decode(response.body);

      // Maoyan search result structure:
      // { movies: { list: [...] } }

      List<Media> results = [];

      if (data != null &&
          data['movies'] != null &&
          data['movies']['list'] != null) {
        final list = data['movies']['list'] as List;
        for (var item in list) {
          try {
            // Reusing logic via Model even for search results,
            // though search results might have slightly different fields.
            // But MaoyanModel logic is robust enough with defaults.
            final model = MaoyanModel.fromJson(item);
            results.add(model.toEntity());
          } catch (e) {
            log('Error parsing maoyan search item: $e');
          }
        }
      }

      return results;
    } catch (e) {
      log('Error searching Maoyan: $e');
      return [];
    }
  }

  Future<Media?> getMovieDetail(String movieId) async {
    final url = 'https://m.maoyan.com/ajax/detailmovie?movieId=$movieId';
    try {
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent':
            'Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1',
      });
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body);
      final detail = data['detailMovie'];
      if (detail == null) return null;

      return MaoyanModel.fromJson(detail).toEntity().copyWith(
            summary: detail['dra']?.toString() ?? '',
            titleOriginal: detail['enm']?.toString() ?? '',
            duration: detail['dur'] == null ? '' : '${detail['dur']}分钟',
            directors: detail['dir'] == null ? [] : [detail['dir'].toString()],
          );
    } catch (e) {
      log('Error fetching Maoyan detail: $e');
      return null;
    }
  }

  Future<List<Media>> getMoviesOnShowing() async {
    const url = 'https://m.maoyan.com/ajax/movieOnInfoList';
    log('Fetching Maoyan current movies: $url');

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load Maoyan movies: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final List<Media> results = [];

      if (data['movieList'] != null) {
        // Use Future.wait to fetch details in parallel (but maybe limit concurrency if needed)
        // For simple list of 10-20 items, Future.wait is usually fine.
        final List<dynamic> movieList = data['movieList'];

        final futures = movieList.map((item) async {
          try {
            final model = MaoyanModel.fromJson(item);
            var media = model.toEntity();

            // Fetch details for missing fields (summary, fuller genres, original title)
            try {
              final detailUrl =
                  'https://m.maoyan.com/ajax/detailmovie?movieId=${model.id}';
              final detailResponse =
                  await http.get(Uri.parse(detailUrl), headers: {
                'User-Agent':
                    'Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1',
              });

              if (detailResponse.statusCode == 200) {
                final detailData = json.decode(detailResponse.body);
                if (detailData['detailMovie'] != null) {
                  final detail = detailData['detailMovie'];

                  final summary = detail['dra']?.toString() ?? '';
                  final originalTitle = detail['enm']?.toString() ?? '';
                  final director = detail['dir']?.toString() ?? '';

                  final durationVal = detail['dur']?.toString() ?? '';

                  String newDuration = media.duration;
                  if (durationVal.isNotEmpty && durationVal != '0') {
                    newDuration = '$durationVal分钟';
                  }

                  List<String> directors = [];
                  if (director.isNotEmpty) {
                    directors = [director];
                  }

                  String validStaff = media.staff;
                  if (media.staff == '暂无制作信息' && director.isNotEmpty) {
                    validStaff =
                        '导演: $director / ${media.staff.replaceAll('暂无制作信息', '')}';
                    // Or more simply reconstruct it if we have actors
                    String newStaff = '';
                    if (director.isNotEmpty) newStaff += '导演: $director ';
                    if (media.actors.isNotEmpty) {
                      newStaff += '主演: ${media.actors.join(', ')}';
                    }
                    validStaff = newStaff;
                  } else if (director.isNotEmpty &&
                      !media.staff.contains('导演')) {
                    validStaff = '导演: $director / ${media.staff}';
                  }

                  media = media.copyWith(
                    summary: summary.isNotEmpty ? summary : media.summary,
                    titleOriginal: originalTitle.isNotEmpty
                        ? originalTitle
                        : media.titleOriginal,
                    duration:
                        newDuration != '0分钟' ? newDuration : media.duration,
                    directors:
                        directors.isNotEmpty ? directors : media.directors,
                    staff: validStaff,
                  );
                }
              }
            } catch (e) {
              log('Error fetching detail for movie ${model.id}: $e');
            }
            return media;
          } catch (e) {
            log('Error parsing maoyan item: $e');
            return null;
          }
        });

        final List<Media?> fetched = await Future.wait(futures);
        results.addAll(fetched.whereType<Media>());
      }
      return results;
    } catch (e) {
      log('Error getMoviesOnShowing: $e');
      rethrow;
    }
  }
}
