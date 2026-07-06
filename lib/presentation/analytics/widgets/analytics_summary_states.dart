import 'package:flutter/material.dart';
import 'package:yuktoe/core/error/app_exception.dart';

/// 요약 영역 로딩 인디케이터(영역 단위).
class AnalyticsSummaryLoading extends StatelessWidget {
  const AnalyticsSummaryLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

/// 요약 영역 에러 상태. `errorCode` 로 문구를 정하고, networkError 일 때만
/// "다시 시도" 버튼을 노출한다.
class AnalyticsErrorState extends StatelessWidget {
  final ErrorCode errorCode;
  final VoidCallback onRetry;

  const AnalyticsErrorState({
    super.key,
    required this.errorCode,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_message(errorCode), style: textTheme.bodyMedium),
          if (errorCode == ErrorCode.networkError) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ],
      ),
    );
  }

  String _message(ErrorCode code) => switch (code) {
        ErrorCode.networkError => '네트워크 연결을 확인해주세요.',
        ErrorCode.unauthorized => '다시 로그인이 필요합니다.',
        ErrorCode.notFound => '분석 정보를 찾을 수 없습니다.',
        ErrorCode.parseFailed ||
        ErrorCode.invalidResponse ||
        ErrorCode.unknown =>
          '분석 정보를 불러오지 못했습니다.',
      };
}
