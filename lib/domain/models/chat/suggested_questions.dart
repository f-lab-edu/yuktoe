/// 세션 시작 시 그 아기 기준으로 생성된 추천 질문 후보. 정확히 5개(spec FR-010).
/// 표시 전용 풀이며 영속 저장 대상이 아니다(세션 한정). 버튼 순환은 Presentation 의
/// 인덱스 상태로 처리하므로(spec FR-011) 모델은 풀만 보유한다.
class SuggestedQuestions {
  static const requiredCount = 5;

  final List<String> questions;

  SuggestedQuestions(List<String> questions)
    : assert(
        questions.length == requiredCount,
        'must hold exactly $requiredCount questions',
      ),
      questions = List.unmodifiable(questions);

  /// Edge Function(`suggest`) 응답을 매핑한다. 정확히 5개가 아니면 `FormatException`
  /// 을 던져 Service 가 `parseFailed` 로 환원하고, 호출자는 추천만 비노출한다
  /// (analytics_chat_data.md D-AC-5 / spec FR-013).
  factory SuggestedQuestions.fromJson(Map<String, dynamic> json) {
    final raw = json['questions'];
    if (raw is! List) {
      throw const FormatException('suggestions response missing questions list');
    }
    final questions = raw.map((e) => e as String).toList(growable: false);
    if (questions.length != requiredCount) {
      throw FormatException(
        'expected $requiredCount questions, got ${questions.length}',
      );
    }
    return SuggestedQuestions(questions);
  }

  @override
  bool operator ==(Object other) =>
      other is SuggestedQuestions &&
      other.questions.length == questions.length &&
      _listEquals(other.questions, questions);

  @override
  int get hashCode => Object.hashAll(questions);

  static bool _listEquals(List<String> a, List<String> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
