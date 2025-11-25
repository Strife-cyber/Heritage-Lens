import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:hlens/core/services/unity_service.dart';

void main() {
  group('UnityOutgoingMessage', () {
    test('sérialise correctement une chaîne', () {
      const message = UnityOutgoingMessage(
        bridge: UnityBridgeTarget.generic,
        type: UnityMessageType.generic,
        payload: UnityStringPayload('hello'),
      );

      expect(message.serializedPayload, 'hello');
    });

    test('sérialise correctement un JSON', () {
      const payload = UnityMapPayload({'foo': 'bar', 'age': 4});
      const message = UnityOutgoingMessage(
        bridge: UnityBridgeTarget.generic,
        type: UnityMessageType.generic,
        payload: payload,
      );

      final decoded = jsonDecode(message.serializedPayload) as Map<String, dynamic>;
      expect(decoded, equals({'foo': 'bar', 'age': 4}));
    });
  });

  group('UnityIncomingMessage', () {
    test('parse un message Map', () {
      final message = UnityIncomingMessage.fromUnity({
        'type': 'hello',
        'payload': {'foo': 'bar'},
      });

      expect(message.type, 'hello');
      expect(message.payload, isA<UnityMapPayload>());
    });

    test('parse un message JSON string', () {
      final message = UnityIncomingMessage.fromUnity(
        '{"type":"pong","payload":{"value":42}}',
      );

      expect(message.type, 'pong');
      expect(message.payload, isA<UnityMapPayload>());
    });

    test('retourne payload null pour un string invalide', () {
      final message = UnityIncomingMessage.fromUnity('not-json');

      expect(message.type, isNull);
      expect(message.payload, isNull);
    });
  });

  group('UnityService', () {
    test('publie les messages entrants sur le flux', () async {
      final service = UnityService.instance;

      final expectation = expectLater(
        service.incomingMessages,
        emits(
          isA<UnityIncomingMessage>()
              .having((msg) => msg.type, 'type', 'event')
              .having(
                (msg) => msg.payload,
                'payload',
                isA<UnityMapPayload>(),
              ),
        ),
      );

      service.handleUnityMessage({
        'type': 'event',
        'payload': {'foo': 'bar'},
      });

      await expectation;
    });
  });
}

