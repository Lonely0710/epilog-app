import 'dart:developer';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/domain/entities/media.dart';

abstract class SearchRepository {
  Future<List<Media>> searchAnime(String query);
  Future<List<Media>> searchMovie(String query);
  Future<List<Media>> searchAll(String query);
}

class SearchRepositoryImpl implements SearchRepository {
  final SupabaseClient _supabase;

  SearchRepositoryImpl({SupabaseClient? supabaseClient}) : _supabase = supabaseClient ?? Supabase.instance.client;

  @override
  Future<List<Media>> searchAnime(String query) async {
    return _searchMedia(query, 'anime');
  }

  @override
  Future<List<Media>> searchMovie(String query) async {
    return _searchMedia(query, 'movie');
  }

  @override
  Future<List<Media>> searchAll(String query) async {
    return _searchMedia(query, 'all');
  }

  /// Core method to call the search-media Edge Function
  Future<List<Media>> _searchMedia(String query, String type) async {
    if (query.isEmpty) return [];

    try {
      log('Searching via Edge Function: query="$query", type="$type"');

      final response = await _supabase.functions.invoke(
        'search-media',
        body: {
          'query': query,
          'type': type,
        },
      );

      final data = response.data;

      if (data == null) {
        log('Search returned null data');
        return [];
      }

      if (data['error'] != null) {
        log('Search error: ${data['error']}');
        return [];
      }

      final results = data['results'] as List?;
      if (results == null || results.isEmpty) {
        log('No results found');
        return [];
      }

      log('Received ${results.length} results from Edge Function');

      return results
          .map((item) {
            try {
              return Media.fromJson(item as Map<String, dynamic>);
            } catch (e) {
              log('Error parsing media item: $e');
              return null;
            }
          })
          .whereType<Media>()
          .toList();
    } catch (e) {
      log('Search failed: $e');
      return [];
    }
  }
}
