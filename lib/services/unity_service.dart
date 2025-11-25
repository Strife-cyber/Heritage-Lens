import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_embed_unity/flutter_embed_unity.dart';

/// Enum listant les passerelles Unity disponibles.
enum UnityBridgeTarget {
  /// Le model ou bien model bridge ici est utiliser pour la communication afin d'envoyer le model url a unity.
  model('ModelBridge'),
  /// Le generic ou bien flutter bridge ici est utiliser pour la communication afin d'envoyer des messages personnalisés a unity.
  generic('FlutterBridge');

  const UnityBridgeTarget(this.gameObjectName);
  final String gameObjectName;
}

/// Enum pour typer les méthodes Unity exposées.
enum UnityMessageType {
  /// Le modelUrl ou bien onModelUrl ici est utiliser pour la communication afin d'envoyer le model url a unity.
  modelUrl('OnModelUrl'),
  /// Le generic ou bien onFlutterMessage ici est utiliser pour la communication afin de recevoir des messages personnalisés de unity.
  generic('OnFlutterMessage');

  const UnityMessageType(this.methodName);
  final String methodName;
}

/// Classe de base pour les payloads envoyés/reçus.
abstract class UnityPayload {
  const UnityPayload();

  /// Valeur encodable (Map ou primitive).
  Object? toEncodable();
}

/// Payload pour de simples chaînes déjà encodées côté Unity.
class UnityStringPayload extends UnityPayload {
  const UnityStringPayload(this.value);
  final String value;

  @override
  Object toEncodable() => value;
}

/// Payload générique basé sur une map JSON.
class UnityMapPayload extends UnityPayload {
  const UnityMapPayload(this.value);
  final Map<String, dynamic> value;

  @override
  Map<String, dynamic> toEncodable() => value;
}

/// Payload de secours pour des structures arbitraires.
class UnityRawPayload extends UnityPayload {
  const UnityRawPayload(this.value);
  final Object? value;

  @override
  Object? toEncodable() => value;
}

/// Représente un message sortant vers Unity.
class UnityOutgoingMessage {
  const UnityOutgoingMessage({
    required this.bridge,
    required this.type,
    this.payload,
  });

  final UnityBridgeTarget bridge;
  final UnityMessageType type;
  final UnityPayload? payload;

  String get serializedPayload {
    if (payload == null) {
      return '';
    }
    final encodable = payload!.toEncodable();
    if (encodable is String) {
      return encodable;
    }
    return jsonEncode(encodable, toEncodable: _fallbackEncode);
  }

  static Object? _fallbackEncode(Object? value) =>
      value?.toString(); // Conversion simple pour éviter les crash JSON.
}

/// Représente un message entrant envoyé par Unity.
class UnityIncomingMessage {
  const UnityIncomingMessage({
    required this.raw,
    this.type,
    this.payload,
  });

  final dynamic raw;
  final String? type;
  final UnityPayload? payload;

  factory UnityIncomingMessage.fromUnity(dynamic message) {
    if (message is Map<String, dynamic>) {
      return UnityIncomingMessage(
        raw: message,
        type: message['type']?.toString(),
        payload: _castPayload(message['payload']),
      );
    }

    if (message is String) {
      try {
        final decoded = jsonDecode(message) as Map<String, dynamic>;
        return UnityIncomingMessage(
          raw: message,
          type: decoded['type']?.toString(),
          payload: _castPayload(decoded['payload']),
        );
      } catch (_) {
        return UnityIncomingMessage(raw: message, type: null, payload: null);
      }
    }

    return UnityIncomingMessage(raw: message, type: null, payload: null);
  }

  static UnityPayload? _castPayload(dynamic rawPayload) {
    if (rawPayload is UnityPayload) {
      return rawPayload;
    }
    if (rawPayload is String) {
      return UnityStringPayload(rawPayload);
    }
    if (rawPayload is Map<String, dynamic>) {
      return UnityMapPayload(rawPayload);
    }
    if (rawPayload is Map) {
      return UnityMapPayload(
        rawPayload.map(
          (key, value) => MapEntry(key.toString(), value),
        ),
      );
    }
    if (rawPayload == null) {
      return null;
    }
    return UnityRawPayload(rawPayload);
  }
}

/// Service centralisant la communication Flutter <-> Unity.
class UnityService {
  UnityService._();
  static final UnityService instance = UnityService._();

  final StreamController<UnityIncomingMessage> _incomingController =
      StreamController<UnityIncomingMessage>.broadcast();

  /// Flux des messages envoyés par Unity.
  Stream<UnityIncomingMessage> get incomingMessages =>
      _incomingController.stream;

  /// À connecter sur `EmbedUnity.onMessageFromUnity`.
  void handleUnityMessage(dynamic message) {
    final parsed = UnityIncomingMessage.fromUnity(message);
    if (!_incomingController.isClosed) {
      _incomingController.add(parsed);
    }
  }

  /// Envoie un message typé vers Unity.
  Future<void> sendTyped({
    required UnityBridgeTarget bridge,
    required UnityMessageType type,
    UnityPayload? payload,
  }) {
    return send(UnityOutgoingMessage(
      bridge: bridge,
      type: type,
      payload: payload,
    ));
  }

  /// Envoie un message personnalisé vers Unity.
  Future<void> send(UnityOutgoingMessage message) async {
    await _sendRaw(
      target: message.bridge.gameObjectName,
      method: message.type.methodName,
      arguments: message.serializedPayload,
    );
  }

  /// Ferme le flux des messages entrants.
  Future<void> dispose() async {
    await _incomingController.close();
  }

  Future<void> _sendRaw({
    required String target,
    required String method,
    String arguments = '',
  }) async {
    try {
      await Future<void>.sync(
        () => sendToUnity(target, method, arguments),
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Erreur lors de l\'envoi a Unity ($target::$method) : $error\n$stackTrace',
        );
      }
      rethrow;
    }
  }
}
