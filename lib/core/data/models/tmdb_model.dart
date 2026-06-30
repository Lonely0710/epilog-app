import 'dart:developer';
import '../../domain/entities/media.dart';

class TmdbModel {
  final Map<String, dynamic> json;
  final String mediaType;

  TmdbModel(this.json, this.mediaType);

  factory TmdbModel.fromJson(Map<String, dynamic> json, String mediaType) {
    return TmdbModel(json, mediaType);
  }

  Media toEntity() {
    final isMovie = mediaType == 'movie';
    // item keys are directly from json map
    final item = json;

    final id = _toInt(item['id']).toString();
    final titleZh = isMovie ? item['title'] : item['name'];
    final titleOriginal =
        isMovie ? item['original_title'] : item['original_name'];

    // Determine release date
    final releaseDate = isMovie
        ? (item['release_date'] ?? '未知日期')
        : (item['first_air_date'] ?? '未知日期');

    String year = '----';
    if (releaseDate != '未知日期' && releaseDate.length >= 4) {
      year = releaseDate.substring(0, 4);
    }

    // Poster
    final posterPath = item['poster_path'];
    final posterUrl =
        posterPath != null ? 'https://image.tmdb.org/t/p/w500$posterPath' : '';

    final rating = (item['vote_average'] as num?)?.toDouble() ?? 0.0;

    // Duration
    String duration = '未知';
    if (isMovie && item.containsKey('runtime')) {
      final runtime = _toInt(item['runtime']);
      if (runtime > 0) duration = '$runtime分钟';
    } else if (!isMovie) {
      // Debug: Log available fields for duration parsing
      final hasNumEpisodes = item.containsKey('number_of_episodes');
      final hasEpisodeRt = item.containsKey('episode_run_time');
      log('TMDb Duration Parse: hasNumberOfEpisodes=$hasNumEpisodes, hasEpisodeRunTime=$hasEpisodeRt');
      if (hasNumEpisodes) {
        log('TMDb Duration Parse: number_of_episodes=${item['number_of_episodes']}');
      }

      if (item.containsKey('number_of_episodes')) {
        final episodes = _toInt(item['number_of_episodes']);
        if (episodes > 0) {
          final genres = item['genres'] as List?;
          bool isAnime = false;
          // Check for Animation (16)
          if (genres != null) {
            isAnime = genres.any((g) => g['id'] == 16);
          } else if (item.containsKey('genre_ids')) {
            final genreIds = item['genre_ids'] as List?;
            if (genreIds != null) {
              isAnime = genreIds.contains(16);
            }
          }

          duration = isAnime ? '共$episodes话' : '共$episodes集';
          log('TMDb Duration Parse: Formatted as $duration');
        }
      } else if (item.containsKey('episode_run_time')) {
        final runtimes = item['episode_run_time'] as List?;
        if (runtimes != null && runtimes.isNotEmpty) {
          final runtime = _toInt(runtimes.first);
          duration = '$runtime分钟/集';
          log('TMDb Duration Parse: Fallback to runtime=$duration');
        }
      }
    }

    // Staff
    List<String> directors = [];
    List<String> actors = [];

    Map<String, dynamic>? credits;
    if (item.containsKey('aggregate_credits')) {
      credits = item['aggregate_credits'];
    } else if (item.containsKey('credits')) {
      credits = item['credits'];
    }

    if (credits != null) {
      if (credits['crew'] != null) {
        final crew = credits['crew'] as List;
        directors = crew
            .where((member) {
              if (item.containsKey('aggregate_credits') &&
                  member['jobs'] != null) {
                final jobs = member['jobs'] as List;
                return jobs.any((j) => j['job'] == 'Director');
              }
              return member['job'] == 'Director';
            })
            .map((member) => member['name'] as String)
            .take(3)
            .toList();
      }
      if (credits['cast'] != null) {
        final cast = credits['cast'] as List;
        actors = cast
            .map((member) => member['name']?.toString() ?? '')
            .where((name) => name.isNotEmpty)
            .toList();
      }
    }

    // Fallback for TV creators if no directors found
    if (!isMovie && directors.isEmpty && item.containsKey('created_by')) {
      final creators = item['created_by'] as List;
      directors.addAll(creators.map((c) => c['name'] as String));
    }

    final summary = (item['overview'] ?? '暂无简介').trim();

    String staff = '';
    if (directors.isNotEmpty) {
      staff += '导演: ${directors.join(', ')}';
    }
    if (actors.isNotEmpty) {
      if (staff.isNotEmpty) staff += ' / ';
      staff += '主演: ${actors.join(', ')}';
    }

    // Networks (TV shows only)
    List<Map<String, String>> networks = [];
    if (!isMovie && item.containsKey('networks')) {
      final networkList = item['networks'] as List?;
      if (networkList != null) {
        networks = networkList
            .map<Map<String, String>>((net) {
              final logoPath = net['logo_path'];
              return {
                'name': net['name']?.toString() ?? '',
                // Use w185 size for better loading compatibility (original can be SVG or very large)
                'logoUrl': logoPath != null
                    ? 'https://image.tmdb.org/t/p/w185$logoPath'
                    : '',
              };
            })
            .where((n) => n['name']!.isNotEmpty)
            .toList();
      }
    }

    return Media(
      id: '',
      sourceType: 'tmdb',
      sourceId: id,
      sourceUrl: 'https://www.themoviedb.org/$mediaType/$id',
      mediaType: mediaType,
      titleZh: titleZh ?? '未知标题',
      titleOriginal: titleOriginal ?? '',
      releaseDate: releaseDate,
      duration: duration,
      year: year,
      posterUrl: posterUrl,
      summary: summary,
      staff: staff,
      directors: directors,
      actors: actors,
      networks: networks,
      rating: rating,
      ratingImdb: rating,
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      if (value.isEmpty) return 0;
      return double.tryParse(value)?.toInt() ?? 0;
    }
    return 0;
  }
}
