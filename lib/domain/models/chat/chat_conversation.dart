/// 한 아기에 대한, 한 번의 연속된 상담 단위(세션)의 메타 정보. `babyId` 에 귀속되며
/// (spec FR-024), 콜드 스타트로 새로 시작된다. 사용자 메시지 1건 이상일 때만 내역에
/// 노출된다(서버 보장, spec FR-021 — 클라이언트는 받은 목록을 그대로 신뢰).
///
/// leaf 값 객체이므로 자체 직렬화를 보유한다. 모든 필드 `final`, 변경은 `copyWith`,
/// 시각은 UTC(analytics_chat_data.md D-AC-1).
class ChatConversation {
  final String id;
  final String babyId;

  /// 식별 표시용. 첫 사용자 메시지에서 파생. `null` 이면 Presentation 이 시각으로
  /// 대체한다(spec FR-022).
  final String? title;
  final DateTime createdAt;

  /// 마지막 활동 시각(정렬·표시용). 메시지가 아직 없으면 `null`.
  final DateTime? lastMessageAt;

  ChatConversation({
    required this.id,
    required this.babyId,
    required this.title,
    required this.createdAt,
    required this.lastMessageAt,
  }) : assert(createdAt.isUtc, 'createdAt must be UTC'),
       assert(
         lastMessageAt == null || lastMessageAt.isUtc,
         'lastMessageAt must be UTC',
       );

  ChatConversation copyWith({
    String? id,
    String? babyId,
    String? title,
    DateTime? createdAt,
    DateTime? lastMessageAt,
  }) => ChatConversation(
    id: id ?? this.id,
    babyId: babyId ?? this.babyId,
    title: title ?? this.title,
    createdAt: createdAt ?? this.createdAt,
    lastMessageAt: lastMessageAt ?? this.lastMessageAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'baby_id': babyId,
    'title': title,
    'created_at': createdAt.toIso8601String(),
    'last_message_at': lastMessageAt?.toIso8601String(),
  };

  /// `chat_conversations` 행을 매핑한다.
  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    final lastMessageAt = json['last_message_at'] as String?;
    return ChatConversation(
      id: json['id'] as String,
      babyId: json['baby_id'] as String,
      title: json['title'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
      lastMessageAt: lastMessageAt == null
          ? null
          : DateTime.parse(lastMessageAt).toUtc(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ChatConversation &&
      other.id == id &&
      other.babyId == babyId &&
      other.title == title &&
      other.createdAt == createdAt &&
      other.lastMessageAt == lastMessageAt;

  @override
  int get hashCode =>
      Object.hash(id, babyId, title, createdAt, lastMessageAt);
}
