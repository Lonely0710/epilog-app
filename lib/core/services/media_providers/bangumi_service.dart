import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import '../../domain/entities/media.dart';
import '../../domain/entities/character.dart';

class BangumiService {
  static const String _baseUrl = 'https://bangumi.tv';
  static const String _apiBaseUrl = 'https://api.bgm.tv';
  static const Duration _requestTimeout = Duration(seconds: 8);
  static const Duration _cacheTtl = Duration(minutes: 20);
  static const Map<String, String> _apiHeaders = {
    'User-Agent': 'EpilogApp/1.0 (https://github.com/Lonely0710/epilog-app)',
  };
  static final Map<String, _CacheEntry<List<Media>>> _listCache = {};
  static _CacheEntry<Map<String, List<Media>>>? _weeklyScheduleCache;

  Future<List<Media>> searchAnime(String query) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_apiBaseUrl/v0/search/subjects'),
            headers: {
              ..._apiHeaders,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'keyword': query,
              'sort': 'match',
              'filter': {
                'type': [2],
              },
            }),
          )
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        log('Bangumi search API Error: ${response.statusCode}');
        return [];
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final items = data is Map ? data['data'] : null;
      if (items is! List) return [];

      return items
          .take(20)
          .map(_mediaFromApiSubject)
          .whereType<Media>()
          .toList(growable: false);
    } catch (e) {
      log('Bangumi search error: $e');
      return [];
    }
  }

  Future<Media?> getAnimeDetail(String sourceId) async {
    try {
      final detailData = await _fetchSubjectDetail(sourceId);
      final title = detailData['title'] ?? '';
      return Media(
        id: '',
        sourceType: 'bgm',
        sourceId: sourceId,
        sourceUrl: '$_baseUrl/subject/$sourceId',
        mediaType: 'anime',
        titleZh: title,
        titleOriginal: detailData['titleOriginal'] ?? '',
        releaseDate: detailData['releaseDate'] ?? '',
        duration: detailData['duration'] ?? '',
        year: (detailData['releaseDate'] ?? '').length >= 4
            ? detailData['releaseDate']!.substring(0, 4)
            : '',
        posterUrl: detailData['posterUrl'] ?? '',
        summary: detailData['summary'] ?? '',
        staff: detailData['staff'] ?? '',
        directors: _splitInfoNames(detailData['director']),
        actors: _splitInfoNames(detailData['cast']),
        rating: double.tryParse(detailData['rating'] ?? '') ?? 0,
        ratingBangumi: double.tryParse(detailData['rating'] ?? '') ?? 0,
      );
    } catch (e) {
      log('Bangumi detail error for $sourceId: $e');
      return null;
    }
  }

  Future<List<Media>> hydrateMissingSummaries(
    List<Media> items, {
    int? limit,
  }) async {
    final hydrateCount = limit ?? items.length;
    final futures = items.take(hydrateCount).map((media) async {
      if (media.summary.trim().isNotEmpty && media.summary != '暂无简介') {
        return media;
      }

      final detail = await getAnimeDetail(media.sourceId);
      final summary = detail?.summary.trim() ?? '';
      if (summary.isEmpty || summary == '暂无简介') return media;

      return media.copyWith(
        summary: summary,
        staff: media.staff == '暂无制作信息' ? detail?.staff : media.staff,
        directors: media.directors.isEmpty
            ? (detail?.directors ?? media.directors)
            : media.directors,
      );
    }).toList();

    final hydrated = await Future.wait(futures);
    if (items.length <= hydrateCount) return hydrated;
    return [
      ...hydrated,
      ...items.skip(hydrateCount),
    ];
  }

  Future<Map<String, String>> _fetchSubjectDetail(String sourceId) async {
    final Map<String, String> result = {};

    final response = await http
        .get(
          Uri.parse('$_apiBaseUrl/v0/subjects/$sourceId'),
          headers: _apiHeaders,
        )
        .timeout(_requestTimeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is Map<String, dynamic>) {
        final media = _mediaFromApiSubject(data);
        if (media != null) {
          result['title'] = media.titleZh;
          result['titleOriginal'] = media.titleOriginal;
          result['releaseDate'] = media.releaseDate;
          result['duration'] = media.duration;
          result['posterUrl'] = media.posterUrl;
          result['summary'] = media.summary;
          result['staff'] = media.staff;
          result['director'] = media.directors.join(' / ');
          result['cast'] = media.actors.join(' / ');
          result['rating'] = media.ratingBangumi.toString();
        }
      }
    }
    return result;
  }

  List<String> _splitInfoNames(String? value) {
    if (value == null || value.trim().isEmpty) return [];
    return value
        .split(RegExp(r'、|/|,|，'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(8)
        .toList();
  }

  Media? _mediaFromApiSubject(dynamic raw) {
    if (raw is! Map) return null;
    final item = Map<String, dynamic>.from(raw);
    final sourceId = item['id']?.toString() ?? '';
    if (sourceId.isEmpty) return null;

    final info = _parseApiInfobox(item['infobox']);
    final releaseDate = _normalizeApiDate(
      item['date']?.toString() ?? info['放送开始'] ?? info['上映年度'] ?? '',
    );
    final year = releaseDate.length >= 4 ? releaseDate.substring(0, 4) : '----';
    final episodeCount = item['total_episodes'] ?? item['eps'] ?? info['话数'];
    final duration = episodeCount == null || episodeCount.toString().isEmpty
        ? '未知'
        : '共$episodeCount话';
    final images = item['images'];
    final posterUrl = _httpsUrl(
      images is Map
          ? (images['large'] ?? images['common'] ?? images['medium'] ?? '')
              .toString()
          : (item['image']?.toString() ?? ''),
    );
    final rating = _parseApiDouble(
      item['rating'] is Map ? item['rating']['score'] : null,
    );
    final directors = _splitInfoNames(info['导演']).take(3).toList();

    return Media(
      id: '',
      sourceType: 'bgm',
      sourceId: sourceId,
      sourceUrl: '$_baseUrl/subject/$sourceId',
      mediaType: 'anime',
      titleZh: (item['name_cn']?.toString().isNotEmpty ?? false)
          ? item['name_cn'].toString()
          : (item['name']?.toString() ?? '未知标题'),
      titleOriginal: item['name']?.toString() ?? '',
      releaseDate: releaseDate,
      duration: duration,
      year: year,
      posterUrl: posterUrl,
      summary: item['summary']?.toString() ?? '暂无简介',
      staff: _buildApiStaff(info),
      directors: directors,
      actors: const [],
      rating: rating,
      ratingBangumi: rating,
    );
  }

  Map<String, String> _parseApiInfobox(dynamic raw) {
    final info = <String, String>{};
    if (raw is! List) return info;

    for (final entry in raw) {
      if (entry is! Map) continue;
      final key = entry['key']?.toString().trim();
      if (key == null || key.isEmpty) continue;
      info[key] = _apiInfoValueToString(entry['value']);
    }

    return info;
  }

  String _apiInfoValueToString(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item is Map ? item['v'] : item)
          .where((item) => item != null)
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .join(' / ');
    }
    return value?.toString().trim() ?? '';
  }

  String _httpsUrl(String value) {
    if (value.startsWith('http://')) {
      return value.replaceFirst('http://', 'https://');
    }
    if (value.startsWith('//')) return 'https:$value';
    return value;
  }

  String _normalizeApiDate(String value) {
    if (value.isEmpty || value == '*') return '未知日期';
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return value;

    final fullDateMatch =
        RegExp(r'(\d{4})年(\d{1,2})月(\d{1,2})日').firstMatch(value);
    if (fullDateMatch != null) {
      final year = fullDateMatch.group(1)!;
      final month = fullDateMatch.group(2)!.padLeft(2, '0');
      final day = fullDateMatch.group(3)!.padLeft(2, '0');
      return '$year-$month-$day';
    }

    final monthMatch = RegExp(r'(\d{4})年(\d{1,2})月').firstMatch(value);
    if (monthMatch != null) {
      final year = monthMatch.group(1)!;
      final month = monthMatch.group(2)!.padLeft(2, '0');
      return '$year-$month-01';
    }

    final yearMatch = RegExp(r'(\d{4})').firstMatch(value);
    if (yearMatch != null) return '${yearMatch.group(1)!}-01-01';

    return value;
  }

  String _buildApiStaff(Map<String, String> info) {
    const roles = ['原作', '脚本', '人物设定', '音乐', '动画制作'];
    final parts = roles
        .where((role) => info[role]?.isNotEmpty ?? false)
        .map((role) => '$role: ${info[role]}')
        .toList();
    return parts.isEmpty ? '暂无制作信息' : parts.join(' / ');
  }

  double _parseApiDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String? _weekdayKey(dynamic weekdayId) {
    final id =
        weekdayId is num ? weekdayId.toInt() : int.tryParse('$weekdayId');
    return switch (id) {
      1 => 'Mon',
      2 => 'Tue',
      3 => 'Wed',
      4 => 'Thu',
      5 => 'Fri',
      6 => 'Sat',
      7 => 'Sun',
      _ => null,
    };
  }

  Future<Map<String, List<Media>>> getWeeklySchedule() async {
    final cached = _weeklyScheduleCache;
    if (cached != null &&
        !cached.isExpired(_cacheTtl) &&
        _hasScheduleItems(cached.value)) {
      return cached.value;
    }

    try {
      final response = await http
          .get(
            Uri.parse('$_apiBaseUrl/calendar'),
            headers: _apiHeaders,
          )
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        log('Bangumi Calendar API Error: ${response.statusCode}');
        return {};
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final Map<String, List<Media>> schedule = {};
      if (data is! List) return schedule;

      for (final day in data) {
        if (day is! Map) continue;
        final weekday = day['weekday'];
        final weekdayId = weekday is Map ? weekday['id'] : null;
        final dayKey = _weekdayKey(weekdayId);
        if (dayKey == null) continue;

        final items = day['items'];
        final animeList = items is List
            ? items
                .map(_mediaFromApiSubject)
                .whereType<Media>()
                .toList(growable: false)
            : <Media>[];
        schedule[dayKey] = animeList;
      }
      if (_hasScheduleItems(schedule)) {
        _weeklyScheduleCache = _CacheEntry(schedule);
      }
      return schedule;
    } catch (e) {
      log('Bangumi calendar fetch error: $e');
      return {};
    }
  }

  Future<List<Media>> getTrends() async {
    const cacheKey = 'trends_api_v2';
    final cached = _listCache[cacheKey];
    if (cached != null && !cached.isExpired(_cacheTtl)) {
      return cached.value;
    }

    try {
      final response = await http
          .get(
            Uri.parse('$_apiBaseUrl/v0/subjects?type=2&sort=rank'),
            headers: _apiHeaders,
          )
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        log('Bangumi Trends API Error: ${response.statusCode}');
        return [];
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final items = data is Map ? data['data'] : null;
      if (items is! List) return [];
      final results = items
          .take(20)
          .map(_mediaFromApiSubject)
          .whereType<Media>()
          .toList(growable: false);
      if (results.isNotEmpty) {
        _listCache[cacheKey] = _CacheEntry(results);
      }
      return results;
    } catch (e) {
      log('Bangumi trends error: $e');
      return [];
    }
  }

  bool _hasScheduleItems(Map<String, List<Media>> schedule) {
    return schedule.values.any((items) => items.isNotEmpty);
  }

  Future<List<Character>> getCharacters(String subjectId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_apiBaseUrl/v0/subjects/$subjectId/characters'),
            headers: _apiHeaders,
          )
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        log('Bangumi Characters API Error: ${response.statusCode}');
        return [];
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! List) return [];

      return data
          .map(_characterFromApi)
          .whereType<Character>()
          .take(12)
          .toList(growable: false);
    } catch (e) {
      log('Bangumi fetch characters error: $e');
      return [];
    }
  }

  Character? _characterFromApi(dynamic raw) {
    if (raw is! Map) return null;
    final item = Map<String, dynamic>.from(raw);
    final name = item['name']?.toString() ?? '';
    if (name.isEmpty) return null;

    final images = item['images'];
    final imageUrl = _httpsUrl(
      images is Map
          ? (images['large'] ?? images['medium'] ?? images['grid'] ?? '')
              .toString()
          : '',
    );
    final actors = item['actors'];
    final cv = actors is List
        ? actors
            .map((actor) => actor is Map ? actor['name'] : null)
            .where((name) => name != null)
            .map((name) => name.toString())
            .where((name) => name.isNotEmpty)
            .join(' / ')
        : '';

    return Character(
      name: name,
      imageUrl: imageUrl,
      role: item['relation']?.toString() ?? '',
      cv: cv,
      source: 'bgm',
    );
  }
}

class _CacheEntry<T> {
  final T value;
  final DateTime createdAt;

  _CacheEntry(this.value) : createdAt = DateTime.now();

  bool isExpired(Duration ttl) => DateTime.now().difference(createdAt) > ttl;
}
