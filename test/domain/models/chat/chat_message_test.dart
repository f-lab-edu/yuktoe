import 'package:flutter_test/flutter_test.dart';
import 'package:yuktoe/domain/models/chat/chat_message.dart';

void main() {
  group('ChatMessage', () {
    test('D-AC-1: createdAt 은 UTC 여야 한다', () {
      expect(
        () => ChatMessage(
          id: 'm1',
          conversationId: 'c1',
          role: ChatRole.user,
          content: 'hi',
          createdAt: DateTime(2026, 7, 6, 10), // local
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('toJson/fromJson 라운드트립', () {
      final message = ChatMessage(
        id: 'm1',
        conversationId: 'c1',
        role: ChatRole.assistant,
        content: '안녕하세요',
        createdAt: DateTime.utc(2026, 7, 6, 10, 30),
      );

      final restored = ChatMessage.fromJson(message.toJson());

      expect(restored, message);
      expect(restored.createdAt.isUtc, isTrue);
    });

    test('fromJson 은 시각을 UTC 로 정규화한다', () {
      final restored = ChatMessage.fromJson({
        'id': 'm1',
        'conversation_id': 'c1',
        'role': 'user',
        'content': 'q',
        'created_at': '2026-07-06T19:30:00+09:00',
      });

      expect(restored.createdAt.isUtc, isTrue);
      expect(restored.createdAt, DateTime.utc(2026, 7, 6, 10, 30));
    });

    test('copyWith 는 지정 필드만 바꾼다', () {
      final message = ChatMessage(
        id: 'm1',
        conversationId: 'c1',
        role: ChatRole.user,
        content: 'a',
        createdAt: DateTime.utc(2026),
      );

      final copy = message.copyWith(content: 'b');

      expect(copy.content, 'b');
      expect(copy.id, 'm1');
      expect(copy.role, ChatRole.user);
    });
  });

  group('ChatRole', () {
    test('fromServerValue 는 알려진 값을 매핑한다', () {
      expect(ChatRole.fromServerValue('user'), ChatRole.user);
      expect(ChatRole.fromServerValue('assistant'), ChatRole.assistant);
    });

    test('fromServerValue 는 모르는 값에 FormatException', () {
      expect(
        () => ChatRole.fromServerValue('system'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
