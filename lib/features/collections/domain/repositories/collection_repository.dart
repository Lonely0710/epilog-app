import 'dart:async';

import 'package:flutter/foundation.dart'; // for debugPrint
import 'package:rxdart/rxdart.dart';
import '../../../../core/domain/entities/character.dart';
import '../../../../core/domain/entities/media.dart';
import '../../../../core/services/convex_service.dart';
import 'dart:convert';

abstract class CollectionRepository {
  factory CollectionRepository() {
    return ConvexCollectionRepositoryImpl.instance;
  }

  /// Ensures the media exists in the database (deduplicated) and adds it to the user's collection.
  /// [status]: 'wish', 'watching', 'watched', 'on_hold', 'dropped'
  /// Returns the collection ID.
  Future<String> addToCollection(Media media, {String status = 'wish'});

  /// Checks if the media is already collected by the current user.
  /// Returns the collection ID if exists, null otherwise.
  Future<String?> checkCollectionStatus(String sourceId, String sourceType);

  /// Checks if the media is already collected by the current user.
  /// Returns the collection ID and watch status if exists, null otherwise.
  Future<CollectionStatusSnapshot?> checkCollectionInfo(
      String sourceId, String sourceType);

  /// Removes the media from the user's collection.
  Future<void> removeFromCollection(String collectionId);

  /// Updates the watch status of an existing collection item.
  Future<void> updateWatchStatus(String collectionId, String status);

  /// Fetches all media collected by the current user.
  /// [mediaTypes]: Optional filter by media_type (e.g., ['movie', 'tv'] or ['anime'])
  Future<List<Media>> getCollectedMedia({List<String>? mediaTypes});

  /// Stream that emits whenever the collection changes (add/remove/update).
  Stream<void> get onCollectionChanged;

  /// Watch a specific media item for real-time updates
  Stream<Media?> watchMedia(String mediaId);

  /// Watch a specific media item for real-time updates by Source ID
  Stream<Media?> watchMediaBySource(String sourceId, String sourceType);

  /// Updates database fields for an existing media item.
  Future<void> updateMediaDetails(String mediaId, Media media);

  /// Ensures media/source exists without adding it to the user's collection.
  Future<String?> ensureMedia(Media media);

  /// Returns all stored sources for a media item.
  Future<List<MediaSourceSnapshot>> getMediaSources(String mediaId);

  /// Returns cached people/character info for a media item.
  Future<List<Character>> getCachedPeopleInfo(Media media);

  /// Upserts cached people/character info for a media item.
  Future<void> upsertPeopleInfo(Media media, List<Character> people);
}

class CollectionStatusSnapshot {
  final String collectionId;
  final String status;

  const CollectionStatusSnapshot({
    required this.collectionId,
    required this.status,
  });
}

class MediaSourceSnapshot {
  final String sourceType;
  final String sourceId;
  final String sourceUrl;

  const MediaSourceSnapshot({
    required this.sourceType,
    required this.sourceId,
    required this.sourceUrl,
  });

  factory MediaSourceSnapshot.fromJson(Map<String, dynamic> json) {
    return MediaSourceSnapshot(
      sourceType: json['sourceType']?.toString() ?? '',
      sourceId: json['sourceId']?.toString() ?? '',
      sourceUrl: json['sourceUrl']?.toString() ?? '',
    );
  }
}

// ===========================================
// CONVEX IMPLEMENTATION
// ===========================================

class ConvexCollectionRepositoryImpl implements CollectionRepository {
  // Singleton Pattern
  static final ConvexCollectionRepositoryImpl _instance =
      ConvexCollectionRepositoryImpl._internal();
  static ConvexCollectionRepositoryImpl get instance => _instance;

  ConvexCollectionRepositoryImpl._internal();

  final _changeController = BehaviorSubject<void>();

  @override
  Stream<void> get onCollectionChanged => _changeController.stream;

  Future<bool> _ensureAuthenticated() {
    return ConvexService.instance.waitForAuthToken();
  }

  @override
  Stream<Media?> watchMedia(String mediaId) {
    if (mediaId.isEmpty) return Stream.value(null);

    late StreamController<Media?> controller;
    // We'll store the unsubscribe function returned by subscribe
    dynamic unsubscribe;

    controller = StreamController<Media?>(
      onListen: () {
        final client = ConvexService.instance.client;
        unsubscribe = client.subscribe(
          name: 'media:get',
          args: {'id': mediaId},
          onUpdate: (dynamic jsonStr, [dynamic error]) {
            if (error != null) {
              controller.addError(error);
              return;
            }

            if (jsonStr != null && jsonStr != 'null') {
              try {
                dynamic data;
                if (jsonStr is String) {
                  data = jsonDecode(jsonStr);
                } else {
                  data = jsonStr;
                }

                if (data == null) {
                  controller.add(null);
                } else {
                  controller.add(Media.fromJson(data as Map<String, dynamic>));
                }
              } catch (e) {
                controller.addError(e);
              }
            } else {
              controller.add(null);
            }
          },
          onError: (String error, String? code) {
            controller.addError('$error ${code ?? ''}');
          },
        );
      },
      onCancel: () {
        if (unsubscribe is Function) {
          unsubscribe();
        }
      },
    );

    return controller.stream;
  }

  @override
  Stream<Media?> watchMediaBySource(String sourceId, String sourceType) {
    if (sourceId.isEmpty || sourceType.isEmpty) return Stream.value(null);

    late StreamController<Media?> controller;
    dynamic unsubscribe;

    controller = StreamController<Media?>(
      onListen: () {
        final client = ConvexService.instance.client;
        unsubscribe = client.subscribe(
          name: 'media:getBySource',
          args: {'sourceId': sourceId, 'sourceType': sourceType},
          onUpdate: (dynamic jsonStr, [dynamic error]) {
            if (error != null) {
              controller.addError(error);
              return;
            }

            if (jsonStr != null && jsonStr != 'null') {
              try {
                dynamic data;
                if (jsonStr is String) {
                  data = jsonDecode(jsonStr);
                } else {
                  data = jsonStr;
                }

                if (data == null) {
                  controller.add(null);
                } else {
                  controller.add(Media.fromJson(data as Map<String, dynamic>));
                }
              } catch (e) {
                controller.addError(e);
              }
            } else {
              controller.add(null);
            }
          },
          onError: (String error, String? code) {
            controller.addError('$error ${code ?? ''}');
          },
        );
      },
      onCancel: () {
        if (unsubscribe is Function) {
          unsubscribe();
        }
      },
    );

    return controller.stream;
  }

  @override
  Future<String> addToCollection(Media media, {String status = 'wish'}) async {
    try {
      if (!await _ensureAuthenticated()) {
        throw Exception('Authentication required');
      }

      final client = ConvexService.instance.client;
      final mediaToSave = _sanitizeMediaForCollection(media);

      // Workaround for convex_flutter FFI bug: serialize arrays as JSON strings
      // The FFI layer calls .toString() on arrays instead of proper JSON encoding
      final actorsList = mediaToSave.actors.map((e) => e.toString()).toList();
      final directorsList =
          mediaToSave.directors.map((e) => e.toString()).toList();

      // Build staff object then encode as JSON string
      final staffObj = {
        'info': mediaToSave.staff,
        'actors': actorsList,
        'directors': directorsList,
      };

      // Build args with JSON-encoded strings for arrays (workaround for FFI bug)
      final Map<String, dynamic> args = {
        'sourceType': mediaToSave.sourceType,
        'sourceId': mediaToSave.sourceId,
        'sourceUrl': mediaToSave.sourceUrl,
        'mediaType': mediaToSave.mediaType,
        'titleZh': mediaToSave.titleZh,
        'titleOriginal': mediaToSave.titleOriginal,
        'releaseDate': mediaToSave.releaseDate,
        'duration': mediaToSave.duration,
        'year': mediaToSave.year,
        'posterUrl': mediaToSave.posterUrl,
        'summary': mediaToSave.summary,
        // Encode all arrays as JSON strings to bypass FFI bug
        'staffJson': jsonEncode(staffObj),
        'actorsJson': jsonEncode(actorsList),
        'directorsJson': jsonEncode(directorsList),
        'networksJson': jsonEncode(mediaToSave.networks),

        'ratingDouban': mediaToSave.ratingDouban,
        'ratingImdb': mediaToSave.ratingImdb,
        'ratingBangumi': mediaToSave.ratingBangumi,
        'ratingMaoyan': mediaToSave.ratingMaoyan,
        'status': status,
      };

      final result =
          await client.mutation(name: 'collections:collectMedia', args: args);

      _changeController.add(null);
      return _extractCollectionId(result) ??
          (throw Exception('Collection ID missing from Convex response'));
    } catch (e) {
      debugPrint('❌ Convex Add Collection Failed: $e');
      throw Exception('Failed to add to collection: $e');
    }
  }

  Media _sanitizeMediaForCollection(Media media) {
    final titleZh = media.titleZh.trim().isNotEmpty
        ? media.titleZh.trim()
        : media.titleOriginal.trim();
    if (titleZh.isEmpty) {
      throw Exception('缺少标题，无法收藏');
    }

    var sourceType = media.sourceType.trim();
    var sourceId = media.sourceId.trim();
    final mediaType =
        media.mediaType.trim().isNotEmpty ? media.mediaType.trim() : 'movie';

    if (sourceType.isEmpty) {
      sourceType = mediaType == 'anime' ? 'bgm_search' : 'manual';
    }
    if (sourceId.isEmpty) {
      sourceId = Uri.encodeComponent('$mediaType:$titleZh');
    }

    var sourceUrl = media.sourceUrl.trim();
    if (sourceUrl.isEmpty) {
      sourceUrl = switch (sourceType) {
        'bgm' => 'https://bangumi.tv/subject/$sourceId',
        'tmdb' => 'https://www.themoviedb.org/$mediaType/$sourceId',
        _ => '',
      };
    }

    final year = media.year.trim().isNotEmpty
        ? media.year.trim()
        : _yearFromReleaseDate(media.releaseDate);

    return media.copyWith(
      sourceType: sourceType,
      sourceId: sourceId,
      sourceUrl: sourceUrl,
      mediaType: mediaType,
      titleZh: titleZh,
      titleOriginal: media.titleOriginal.trim(),
      releaseDate: media.releaseDate.trim(),
      duration: media.duration.trim(),
      year: year,
      posterUrl: media.posterUrl.trim(),
      summary: media.summary.trim(),
      staff: media.staff.trim(),
    );
  }

  String _yearFromReleaseDate(String releaseDate) {
    final match = RegExp(r'\d{4}').firstMatch(releaseDate);
    return match?.group(0) ?? '';
  }

  @override
  Future<String?> checkCollectionStatus(
      String sourceId, String sourceType) async {
    final info = await checkCollectionInfo(sourceId, sourceType);
    return info?.collectionId;
  }

  @override
  Future<CollectionStatusSnapshot?> checkCollectionInfo(
      String sourceId, String sourceType) async {
    try {
      if (!await _ensureAuthenticated()) return null;

      final client = ConvexService.instance.client;
      final result = await client.query('collections:checkCollectionStatus', {
        'sourceType': sourceType,
        'sourceId': sourceId,
      });

      final decoded = _decodeConvexResult(result);
      if (decoded == null) return null;

      // Convex returns Map<String, dynamic> here
      final map = Map<String, dynamic>.from(decoded as Map);
      final collectionId = map['collectionId']?.toString();
      if (collectionId == null || collectionId.isEmpty) return null;

      return CollectionStatusSnapshot(
        collectionId: collectionId,
        status: map['status']?.toString() ?? 'wish',
      );
    } catch (e) {
      // Silent fail for check status
      return null;
    }
  }

  @override
  Future<void> removeFromCollection(String collectionId) async {
    try {
      if (!await _ensureAuthenticated()) {
        throw Exception('Authentication required');
      }

      final client = ConvexService.instance.client;
      await client.mutation(name: 'collections:removeCollection', args: {
        'collectionId': collectionId,
      });
      _changeController.add(null);
    } catch (e) {
      debugPrint('❌ Convex Remove Collection Failed: $e');
      throw Exception('Failed to remove from collection');
    }
  }

  @override
  Future<void> updateWatchStatus(String collectionId, String status) async {
    try {
      if (!await _ensureAuthenticated()) {
        throw Exception('Authentication required');
      }

      final client = ConvexService.instance.client;
      await client.mutation(name: 'collections:updateWatchStatus', args: {
        'collectionId': collectionId,
        'status': status,
      });
      _changeController.add(null);
    } catch (e) {
      debugPrint('❌ Convex Update Watch Status Failed: $e');
      throw Exception('Failed to update watch status: $e');
    }
  }

  @override
  Future<void> updateMediaDetails(String mediaId, Media media) async {
    try {
      if (!await _ensureAuthenticated()) {
        throw Exception('Authentication required');
      }

      final actorsList = media.actors.map((e) => e.toString()).toList();
      final directorsList = media.directors.map((e) => e.toString()).toList();
      final staffObj = {
        'info': media.staff,
        'actors': actorsList,
        'directors': directorsList,
      };

      await ConvexService.instance.client.mutation(
        name: 'media:updateDetails',
        args: {
          'mediaId': mediaId,
          'titleZh': media.titleZh,
          'titleOriginal': media.titleOriginal,
          'releaseDate': media.releaseDate,
          'duration': media.duration,
          'year': media.year,
          'posterUrl': media.posterUrl,
          'summary': media.summary,
          'staffJson': jsonEncode(staffObj),
          'actorsJson': jsonEncode(actorsList),
          'directorsJson': jsonEncode(directorsList),
          'networksJson': jsonEncode(media.networks),
          'ratingDouban': media.ratingDouban,
          'ratingImdb': media.ratingImdb,
          'ratingBangumi': media.ratingBangumi,
          'ratingMaoyan': media.ratingMaoyan,
        },
      );
      _changeController.add(null);
    } catch (e) {
      debugPrint('❌ Convex Update Media Details Failed: $e');
      throw Exception('Failed to update media details: $e');
    }
  }

  @override
  Future<String?> ensureMedia(Media media) async {
    try {
      if (media.sourceType.isEmpty ||
          media.sourceId.isEmpty ||
          media.mediaType.isEmpty ||
          !await _ensureAuthenticated()) {
        return null;
      }

      final actorsList = media.actors.map((e) => e.toString()).toList();
      final directorsList = media.directors.map((e) => e.toString()).toList();
      final staffObj = {
        'info': media.staff,
        'actors': actorsList,
        'directors': directorsList,
      };

      final result = await ConvexService.instance.client.mutation(
        name: 'media:ensureMedia',
        args: {
          'sourceType': media.sourceType,
          'sourceId': media.sourceId,
          'sourceUrl': media.sourceUrl,
          'mediaType': media.mediaType,
          'titleZh': media.titleZh,
          'titleOriginal': media.titleOriginal,
          'releaseDate': media.releaseDate,
          'duration': media.duration,
          'year': media.year,
          'posterUrl': media.posterUrl,
          'summary': media.summary,
          'staffJson': jsonEncode(staffObj),
          'actorsJson': jsonEncode(actorsList),
          'directorsJson': jsonEncode(directorsList),
          'networksJson': jsonEncode(media.networks),
          'ratingDouban': media.ratingDouban,
          'ratingImdb': media.ratingImdb,
          'ratingBangumi': media.ratingBangumi,
          'ratingMaoyan': media.ratingMaoyan,
        },
      );

      final decoded = _decodeConvexResult(result);
      return decoded?.toString();
    } catch (e) {
      debugPrint('❌ Convex Ensure Media Failed: $e');
      return null;
    }
  }

  @override
  Future<List<MediaSourceSnapshot>> getMediaSources(String mediaId) async {
    try {
      if (mediaId.isEmpty || !await _ensureAuthenticated()) return [];

      final result = await ConvexService.instance.client.query(
        'media:getMediaSources',
        {'mediaId': mediaId},
      );
      final decoded = _decodeConvexResult(result);
      if (decoded is! List) return [];
      return decoded
          .map((item) => MediaSourceSnapshot.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList();
    } catch (e) {
      debugPrint('❌ Convex Get Media Sources Failed: $e');
      return [];
    }
  }

  @override
  Future<List<Character>> getCachedPeopleInfo(Media media) async {
    try {
      if (media.id.isEmpty || !await _ensureAuthenticated()) return [];

      final result = await ConvexService.instance.client.query(
        'media:getInfo',
        {
          'mediaId': media.id,
          'mediaType': media.mediaType,
        },
      );
      final decoded = _decodeConvexResult(result);
      if (decoded is! Map) return [];
      final people = decoded['people'];
      if (people is! List) return [];
      return people
          .map((item) =>
              Character.fromJson(Map<String, dynamic>.from(item as Map)))
          .where((person) => person.name.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('❌ Convex Get People Info Failed: $e');
      return [];
    }
  }

  @override
  Future<void> upsertPeopleInfo(Media media, List<Character> people) async {
    try {
      if (media.id.isEmpty || people.isEmpty || !await _ensureAuthenticated()) {
        return;
      }

      await ConvexService.instance.client.mutation(
        name: 'media:upsertInfo',
        args: {
          'mediaId': media.id,
          'mediaType': media.mediaType,
          'peopleJson': jsonEncode(
            people.map((person) => person.toJson()).toList(),
          ),
        },
      );
    } catch (e) {
      debugPrint('❌ Convex Upsert People Info Failed: $e');
    }
  }

  @override
  Future<List<Media>> getCollectedMedia({List<String>? mediaTypes}) async {
    try {
      if (!await _ensureAuthenticated()) {
        throw Exception('Authentication required');
      }

      final client = ConvexService.instance.client;
      final dynamic results =
          await client.query('collections:getUserCollections', {
        '_ts': DateTime.now().millisecondsSinceEpoch.toString(),
      });

      List<dynamic> list;
      if (results is String) {
        if (results.isEmpty || results == 'null') return [];
        final decoded = jsonDecode(results);
        if (decoded == null) return [];
        list = decoded as List;
      } else if (results is List) {
        list = results;
      } else if (results == null) {
        return [];
      } else {
        debugPrint(
            '❌ Unexpected result type from Convex: ${results.runtimeType}');
        return [];
      }

      final medias = list.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return Media.fromJson(map);
      }).toList();

      if (mediaTypes != null) {
        final filtered =
            medias.where((m) => mediaTypes.contains(m.mediaType)).toList();
        return filtered;
      }
      return medias;
    } catch (e) {
      debugPrint('❌ Convex Get Collections Failed: $e');
      return [];
    }
  }

  dynamic _decodeConvexResult(dynamic result) {
    if (result is String) {
      if (result.isEmpty || result == 'null') return null;
      return jsonDecode(result);
    }
    return result;
  }

  String? _extractCollectionId(dynamic result) {
    final decoded = _decodeConvexResult(result);
    if (decoded == null) return null;
    if (decoded is String) return decoded;
    if (decoded is Map) return decoded['collectionId']?.toString();
    return decoded.toString();
  }
}
