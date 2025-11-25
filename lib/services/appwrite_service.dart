import 'dart:async';

import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fournit une instance unique du service Appwrite via Riverpod.
final appwriteServiceProvider = Provider<AppwriteService>((ref) {
  final service = AppwriteService();
  ref.onDispose(service.dispose);
  return service;
});

/// Client Appwrite initialisé et prêt à l'emploi.
final appwriteClientProvider = FutureProvider<Client>((ref) async {
  final service = ref.watch(appwriteServiceProvider);
  return service.ensureClient();
});

/// Providers utilitaires pour les modules courants.
final appwriteAccountProvider = FutureProvider<Account>((ref) async {
  final service = ref.watch(appwriteServiceProvider);
  return service.account();
});

final appwriteDatabasesProvider = FutureProvider<Databases>((ref) async {
  final service = ref.watch(appwriteServiceProvider);
  return service.databases();
});

final appwriteStorageProvider = FutureProvider<Storage>((ref) async {
  final service = ref.watch(appwriteServiceProvider);
  return service.storage();
});

/// Service responsable de la configuration et du routage Appwrite.
class AppwriteService {
  AppwriteService({DotEnv? env}) : _env = env ?? dotenv;

  final DotEnv _env;

  Client? _client;
  Account? _account;
  Storage? _storage;
  Realtime? _realtime;
  Databases? _databases;
  final Map<String, RealtimeSubscription> _realtimeSubscriptions = {};

  //static const _jwtKey = 'APPWRITE_JWT';
  //static const _sessionKey = 'APPWRITE_SESSION';
  static const _endpointKey = 'APPWRITE_ENDPOINT';
  static const _projectKey = 'APPWRITE_PROJECT_ID';
  static const _defaultEndpoint = 'https://cloud.appwrite.io/v1';

  /// Initialise le client Appwrite sur demande.
  Future<Client> ensureClient() async {
    if (_client != null) {
      return _client!;
    }
    await _loadEnvIfNeeded();
    final endpoint = _env.env[_endpointKey]?.trim().isNotEmpty == true
        ? _env.env[_endpointKey]!.trim()
        : _defaultEndpoint;
    final projectId = _readRequired(_projectKey);

    final client = Client()
      ..setEndpoint(endpoint)
      ..setProject(projectId);

    /*final session = _env.env[_sessionKey];
    if (session != null && session.isNotEmpty) {
      client.addHeader('X-Appwrite-Session', session);
    }

    final jwt = _env.env[_jwtKey];
    if (jwt != null && jwt.isNotEmpty) {
      client.setJWT(jwt);
    }*/

    _client = client;
    return client;
  }

  /// Accès rapide au module Account.
  Future<Account> account() async {
    final client = await ensureClient();
    return _account ??= Account(client);
  }

  /// Accès rapide au module Databases.
  Future<Databases> databases() async {
    final client = await ensureClient();
    return _databases ??= Databases(client);
  }

  /// Accès rapide au module Storage.
  Future<Storage> storage() async {
    final client = await ensureClient();
    return _storage ??= Storage(client);
  }

  /// Accès rapide au module Realtime.
  Future<Realtime> realtime() async {
    final client = await ensureClient();
    return _realtime ??= Realtime(client);
  }

  /// Abonne une callback à un canal realtime Appwrite.
  Future<RealtimeSubscription> subscribe({
    required List<String> channels,
    void Function(RealtimeMessage message)? onMessage,
  }) async {
    final key = channels.join(',');
    if (_realtimeSubscriptions.containsKey(key)) {
      return _realtimeSubscriptions[key]!;
    }
    final rt = await realtime();
    final subscription = rt.subscribe(channels);
    if (onMessage != null) {
      subscription.stream.listen(onMessage);
    }
    _realtimeSubscriptions[key] = subscription;
    return subscription;
  }

  /// Se désabonne proprement d'un canal realtime.
  void unsubscribe(List<String> channels) {
    final key = channels.join(',');
    final subscription = _realtimeSubscriptions.remove(key);
    subscription?.close();
  }

  /// Permet de forcer la fermeture des subscriptions et clients.
  Future<void> dispose() async {
    for (final sub in _realtimeSubscriptions.values) {
      sub.close();
    }
    _realtimeSubscriptions.clear();
    _account = null;
    _databases = null;
    _storage = null;
    _realtime = null;
    _client = null;
  }

  Future<void> _loadEnvIfNeeded() async {
    if (_env.isInitialized) {
      return;
    }
    try {
      await _env.load(fileName: '.env');
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Impossible de charger .env : $error\n$stackTrace');
      }
      rethrow;
    }
  }

  String _readRequired(String key) {
    final value = _env.env[key];
    if (value == null || value.trim().isEmpty) {
      throw StateError(
        'La variable d\'environnement $key est absente ou vide.',
      );
    }
    return value.trim();
  }
}

