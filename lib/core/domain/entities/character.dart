class Character {
  final String name;
  final String nameCn; // Chinese name/alias if available
  final String imageUrl;
  final String role; // e.g. 主角, 配角
  final String cv; // Cast name
  final String source; // tmdb, bgm, fallback_actor
  final int? episodeCount;

  const Character({
    required this.name,
    this.nameCn = '',
    required this.imageUrl,
    required this.role,
    this.cv = '',
    this.source = '',
    this.episodeCount,
  });

  factory Character.empty() {
    return const Character(
      name: '',
      imageUrl: '',
      role: '',
    );
  }

  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      name: json['name']?.toString() ?? '',
      nameCn: json['nameCn']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      cv: json['cv']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      episodeCount: _parseEpisodeCount(json['episodeCount']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'nameCn': nameCn,
      'imageUrl': imageUrl,
      'role': role,
      'cv': cv,
      'source': source,
      if (episodeCount != null) 'episodeCount': episodeCount,
    };
  }

  static int? _parseEpisodeCount(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
