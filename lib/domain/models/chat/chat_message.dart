/// 한 세션 안의 한 발화. 역할(`user`|`assistant`), 본문, 생성 시각(UTC)을 가진다.
///
/// leaf 값 객체이므로 자체 직렬화(`toJson`/`fromJson`)를 보유한다. 집합/매핑은
/// Service 가 담당한다. 모든 필드는 `final`, 변경은 `copyWith`, `createdAt` 은 UTC다
/// (analytics_chat_data.md D-AC-1).
///
/// 환영 메시지는 이 모델로 **표시만** 하고 저장하지 않는다(spec FR-002). 영속
/// 메시지와 임시(환영/optimistic) 메시지의 구분은 Presentation 책임이다.
class ChatMessage {
  final String id;
  final String conversationId;
  final ChatRole role;
  final String content;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
  }) : assert(createdAt.isUtc, 'createdAt must be UTC');

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    ChatRole? role,
    String? content,
    DateTime? createdAt,
  }) => ChatMessage(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    role: role ?? this.role,
    content: content ?? this.content,
    createdAt: createdAt ?? this.createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversation_id': conversationId,
    'role': role.serverValue,
    'content': content,
    'created_at': createdAt.toIso8601String(),
  };

  /// `chat_messages` 행을 매핑한다. 모르는 역할·형식 오류는 예외를 던져 Service 가
  /// `parseFailed` 로 환원한다(analytics_chat_data.md D-AC-7).
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    conversationId: json['conversation_id'] as String,
    role: ChatRole.fromServerValue(json['role'] as String),
    content: json['content'] as String,
    createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
  );

  @override
  bool operator ==(Object other) =>
      other is ChatMessage &&
      other.id == id &&
      other.conversationId == conversationId &&
      other.role == role &&
      other.content == content &&
      other.createdAt == createdAt;

  @override
  int get hashCode =>
      Object.hash(id, conversationId, role, content, createdAt);
}

/// 발화 주체. 서버 문자열(`user`/`assistant`)과 1:1 대응한다.
enum ChatRole {
  user('user'),
  assistant('assistant');

  const ChatRole(this.serverValue);

  final String serverValue;

  /// 서버 문자열을 enum 으로 변환한다. 모르는 값은 `FormatException` 을 던진다
  /// (Service 가 `parseFailed` 로 환원, spec FR-042).
  static ChatRole fromServerValue(String value) => values.firstWhere(
    (role) => role.serverValue == value,
    orElse: () => throw FormatException('Unknown chat role: $value'),
  );
}
