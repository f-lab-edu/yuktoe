import 'package:flutter_test/flutter_test.dart';
import 'package:yuktoe/domain/models/chat/chat_stream_event.dart';

void main() {
  group('ChatStreamEvent.fromServerEvent', () {
    test('meta 이벤트를 ChatStreamMeta 로 매핑한다', () {
      final event = ChatStreamEvent.fromServerEvent('meta', {
        'conversation_id': 'c1',
      });
      expect(event, const ChatStreamMeta('c1'));
    });

    test('delta 이벤트를 ChatStreamDelta 로 매핑한다', () {
      final event = ChatStreamEvent.fromServerEvent('delta', {'text': '토큰'});
      expect(event, const ChatStreamDelta('토큰'));
    });

    test('done 이벤트를 ChatStreamDone 으로 매핑한다', () {
      expect(
        ChatStreamEvent.fromServerEvent('done', null),
        const ChatStreamDone(),
      );
    });

    test('모르는 이벤트는 FormatException', () {
      expect(
        () => ChatStreamEvent.fromServerEvent('boom', null),
        throwsA(isA<FormatException>()),
      );
    });

    test('meta 에 conversation_id 없으면 FormatException', () {
      expect(
        () => ChatStreamEvent.fromServerEvent('meta', {}),
        throwsA(isA<FormatException>()),
      );
    });

    test('delta 에 text 없으면 FormatException', () {
      expect(
        () => ChatStreamEvent.fromServerEvent('delta', {}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('동등성', () {
    test('같은 페이로드의 이벤트는 동등하다', () {
      expect(const ChatStreamMeta('c1'), const ChatStreamMeta('c1'));
      expect(const ChatStreamDelta('a'), const ChatStreamDelta('a'));
      expect(const ChatStreamDone(), const ChatStreamDone());
    });

    test('다른 페이로드는 동등하지 않다', () {
      expect(const ChatStreamMeta('c1'), isNot(const ChatStreamMeta('c2')));
      expect(const ChatStreamDelta('a'), isNot(const ChatStreamDelta('b')));
    });
  });
}
