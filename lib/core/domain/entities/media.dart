class Media {
  // media_source相关字段
  final String sourceType; // douban/imdb/bgm/maoyan
  final String sourceId;
  final String sourceUrl;

  // media相关字段
  final String mediaType; // movie/tv/anime
  final String titleZh;
  final String titleOriginal;
  final String releaseDate; // 详细首播年月日
  final String duration; // 时长（分钟/话数）
  final String year; // 年份(从releaseDate提取)
  final String posterUrl;
  final String summary; // 剧情简介
  final String staff; // 制作人员 (Anime usage)
  final List<String> directors;
  final List<String> actors;

  // 评分相关
  final double rating; // 综合评分(用于兼容旧版本)
  final double ratingDouban; // 豆瓣评分
  final double ratingImdb; // IMDb评分
  final double ratingBangumi; // Bangumi评分
  final double ratingMaoyan; // 猫眼评分

  // 状态
  final bool isCollected;
  final String collectionId; // 收藏记录ID
  final String? watchingStatus; // 'wish', 'watching', 'watched', 'dropped', 'on_hold'
  final List<String> genres; // 电影类型
  final bool isNew; // 是否新上映
  final String wish; // 想看人数

  const Media({
    required this.sourceType,
    required this.sourceId,
    required this.sourceUrl,
    required this.mediaType,
    required this.titleZh,
    required this.titleOriginal,
    required this.releaseDate,
    required this.duration,
    required this.year,
    required this.posterUrl,
    required this.summary,
    required this.staff,
    this.directors = const [],
    this.actors = const [],
    required this.rating,
    this.ratingDouban = 0.0,
    this.ratingImdb = 0.0,
    this.ratingBangumi = 0.0,
    this.ratingMaoyan = 0.0,
    this.isCollected = false,
    this.collectionId = '',
    this.watchingStatus,
    this.genres = const [],
    this.isNew = false,
    this.wish = '',
  });

  factory Media.empty() {
    return const Media(
      sourceType: '',
      sourceId: '',
      sourceUrl: '',
      mediaType: '',
      titleZh: '',
      titleOriginal: '',
      releaseDate: '',
      duration: '',
      year: '',
      posterUrl: '',
      summary: '',
      staff: '',
      rating: 0.0,
    );
  }

  factory Media.fromJson(Map<String, dynamic> json) {
    return Media(
      sourceType: json['sourceType'] ?? '',
      sourceId: json['sourceId'] ?? '',
      sourceUrl: json['sourceUrl'] ?? '',
      mediaType: json['mediaType'] ?? '',
      titleZh: json['titleZh'] ?? '',
      titleOriginal: json['titleOriginal'] ?? '',
      releaseDate: json['releaseDate'] ?? '',
      duration: json['duration'] ?? '',
      year: json['year'] ?? '',
      posterUrl: json['posterUrl'] ?? '',
      summary: json['summary'] ?? '',
      staff: json['staff'] ?? '',
      directors: (json['directors'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      actors: (json['actors'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      ratingDouban: (json['ratingDouban'] as num?)?.toDouble() ?? 0.0,
      ratingImdb: (json['ratingImdb'] as num?)?.toDouble() ?? 0.0,
      ratingBangumi: (json['ratingBangumi'] as num?)?.toDouble() ?? 0.0,
      ratingMaoyan: (json['ratingMaoyan'] as num?)?.toDouble() ?? 0.0,
      genres: (json['genres'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      wish: json['wish'] ?? '',
      isNew: json['isNew'] ?? false,
    );
  }

  Media copyWith({
    String? sourceType,
    String? sourceId,
    String? sourceUrl,
    String? mediaType,
    String? titleZh,
    String? titleOriginal,
    String? releaseDate,
    String? duration,
    String? year,
    String? posterUrl,
    String? summary,
    String? staff,
    List<String>? directors,
    List<String>? actors,
    double? rating,
    double? ratingDouban,
    double? ratingImdb,
    double? ratingBangumi,
    double? ratingMaoyan,
    bool? isCollected,
    String? collectionId,
    String? watchingStatus,
    List<String>? genres,
    bool? isNew,
    String? wish,
  }) {
    return Media(
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      mediaType: mediaType ?? this.mediaType,
      titleZh: titleZh ?? this.titleZh,
      titleOriginal: titleOriginal ?? this.titleOriginal,
      releaseDate: releaseDate ?? this.releaseDate,
      duration: duration ?? this.duration,
      year: year ?? this.year,
      posterUrl: posterUrl ?? this.posterUrl,
      summary: summary ?? this.summary,
      staff: staff ?? this.staff,
      directors: directors ?? this.directors,
      actors: actors ?? this.actors,
      rating: rating ?? this.rating,
      ratingDouban: ratingDouban ?? this.ratingDouban,
      ratingImdb: ratingImdb ?? this.ratingImdb,
      ratingBangumi: ratingBangumi ?? this.ratingBangumi,
      ratingMaoyan: ratingMaoyan ?? this.ratingMaoyan,
      isCollected: isCollected ?? this.isCollected,
      collectionId: collectionId ?? this.collectionId,
      watchingStatus: watchingStatus ?? this.watchingStatus,
      genres: genres ?? this.genres,
      isNew: isNew ?? this.isNew,
      wish: wish ?? this.wish,
    );
  }
}
