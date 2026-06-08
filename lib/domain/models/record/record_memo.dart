class RecordMemo {
  final String id;
  final String recordId;
  final String content;
  final String authorId;
  final String authorName;
  final DateTime createdAt;

  const RecordMemo({
    required this.id,
    required this.recordId,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
  });
}
