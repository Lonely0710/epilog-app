import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../../core/services/convex_service.dart';

class ConvexUserRepository {
  static final instance = ConvexUserRepository._();

  ConvexUserRepository._();

  /// Watch current user data from Convex (users:currentUser query)
  Stream<Map<String, dynamic>?> watchCurrentUser() {
    final controller = StreamController<Map<String, dynamic>?>();

    // We store the unsubscribe result which might be a function or handle,
    // or pending future.
    dynamic unsubscribe;
    bool isCancelled = false;

    controller.onListen = () async {
      if (isCancelled) return;
      try {
        final isAuthenticated = await ConvexService.instance.waitForAuthToken();
        if (!isAuthenticated) {
          if (!controller.isClosed) controller.add(null);
          return;
        }

        final client = ConvexService.instance.client;

        // Await the subscription future
        final handle = await client.subscribe(
          name: 'users:currentUser',
          args: {},
          onUpdate: (dynamic jsonStr, [dynamic error]) {
            if (controller.isClosed) return;

            if (error != null) {
              // If query fails (e.g. not authenticated), we might emit null
              debugPrint('Convex User Query Error: $error');
              controller.add(null);
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

                if (data is Map<String, dynamic>) {
                  controller.add(data);
                } else {
                  controller.add(null);
                }
              } catch (e) {
                debugPrint('Convex User Parse Error: $e');
                controller.add(null);
              }
            } else {
              controller.add(null);
            }
          },
          onError: (String error, String? code) {
            if (!controller.isClosed) {
              debugPrint('Convex User Subscription Error: $error');
              controller.add(null);
            }
          },
        );

        unsubscribe = handle;

        // If cancelled while awaiting
        if (isCancelled) {
          _performUnsubscribe(unsubscribe);
        }
      } catch (e) {
        debugPrint('Convex User Subscription Exception: $e');
        if (!controller.isClosed) controller.add(null);
      }
    };

    controller.onCancel = () {
      isCancelled = true;
      if (unsubscribe != null) {
        _performUnsubscribe(unsubscribe);
      }
    };

    return controller.stream;
  }

  void _performUnsubscribe(dynamic handle) {
    if (handle == null) return;
    try {
      if (handle is Function) {
        (handle as Function)();
      } else {
        // Try dispose if it has it (via dynamic)
        try {
          (handle as dynamic).dispose();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error unsubscribing from user query: $e');
    }
  }
}
