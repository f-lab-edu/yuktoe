import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yuktoe/constants/enum/social_auth_provider.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/repositories/auth_repository/auth_repository.dart';
import 'package:yuktoe/domain/models/auth/app_session.dart';
import 'package:yuktoe/domain/models/auth/app_user.dart';
import 'package:yuktoe/presentation/auth/login/view_models/login_view_model.dart';

import 'login_view_model_test.mocks.dart';

@GenerateMocks([AuthRepository])
AppSession createSession({
  String id = 'user-1',
  String accessToken = 'token-abc',
  String? email = 'test@example.com',
  String? name = 'Test User',
}) {
  return AppSession(
    accessToken: accessToken,
    user: AppUser(id: id, email: email, name: name),
  );
}

void main() {
  late MockAuthRepository mockAuthRepository;
  late LoginViewModel viewModel;

  setUpAll(() {
    provideDummy<Result<void>>(Result.ok(null));
  });

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    viewModel = LoginViewModel(mockAuthRepository);
  });

  group('initial state', () {
    test('starts with default values', () {
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.session, isNull);
      expect(viewModel.isLoggedIn, isFalse);
    });
  });

  group('signIn', () {
    test('sets session when signIn succeeds', () async {
      // given
      final session = createSession();

      when(
        mockAuthRepository.signIn(SocialAuthProvider.kakao),
      ).thenAnswer((_) async => Result.ok(null));
      when(mockAuthRepository.session).thenReturn(session);

      // when
      await viewModel.signIn(SocialAuthProvider.kakao);

      // then
      expect(viewModel.session, same(session));
      expect(viewModel.isLoggedIn, isTrue);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.isLoading, isFalse);

      verify(mockAuthRepository.signIn(SocialAuthProvider.kakao)).called(1);
      verify(mockAuthRepository.session).called(1);
    });

    test('sets errorMessage when signIn returns Error', () async {
      // given
      when(
        mockAuthRepository.signIn(SocialAuthProvider.kakao),
      ).thenAnswer((_) async => Result.error(AppException(ErrorCode.unknown, 'sign in failed')));

      // when
      await viewModel.signIn(SocialAuthProvider.kakao);

      // then
      expect(viewModel.errorMessage, '오류가 발생했습니다.');
      expect(viewModel.session, isNull);
      expect(viewModel.isLoggedIn, isFalse);
      expect(viewModel.isLoading, isFalse);

      verify(mockAuthRepository.signIn(SocialAuthProvider.kakao)).called(1);
      verifyNever(mockAuthRepository.session);
    });

    test('ignores second signIn call while first is in progress', () async {
      // given
      final completer = Completer<Result<void>>();

      when(
        mockAuthRepository.signIn(SocialAuthProvider.kakao),
      ).thenAnswer((_) => completer.future);
      when(mockAuthRepository.session).thenReturn(createSession());

      // when
      final firstCall = viewModel.signIn(SocialAuthProvider.kakao);
      expect(viewModel.isLoading, isTrue);

      final secondCall = viewModel.signIn(SocialAuthProvider.kakao);

      // then - signIn은 한 번만 호출되어야 함
      verify(mockAuthRepository.signIn(SocialAuthProvider.kakao)).called(1);

      completer.complete(Result.ok(null));
      await firstCall;
      await secondCall;
    });

    test('clears previous error when next signIn succeeds', () async {
      // given - first call fails
      when(
        mockAuthRepository.signIn(SocialAuthProvider.kakao),
      ).thenAnswer((_) async => Result.error(AppException(ErrorCode.unknown, 'first error')));

      // when
      await viewModel.signIn(SocialAuthProvider.kakao);

      // then
      expect(viewModel.errorMessage, '오류가 발생했습니다.');

      // given - second call succeeds
      final session = createSession();
      when(
        mockAuthRepository.signIn(SocialAuthProvider.kakao),
      ).thenAnswer((_) async => Result.ok(null));
      when(mockAuthRepository.session).thenReturn(session);

      // when
      await viewModel.signIn(SocialAuthProvider.kakao);

      // then
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.session, same(session));
      expect(viewModel.isLoggedIn, isTrue);
    });

    test('notifies listeners when loading changes', () async {
      // given
      when(
        mockAuthRepository.signIn(SocialAuthProvider.kakao),
      ).thenAnswer((_) async => Result.ok(null));
      when(mockAuthRepository.session).thenReturn(createSession());

      final notifications = <bool>[];
      viewModel.addListener(() {
        notifications.add(viewModel.isLoading);
      });

      // when
      await viewModel.signIn(SocialAuthProvider.kakao);

      // then - loading true -> loading false
      expect(notifications, [true, false]);
    });

    test('handles unexpected exception', () async {
      when(
        mockAuthRepository.signIn(SocialAuthProvider.kakao),
      ).thenThrow(Exception('unexpected'));

      await viewModel.signIn(SocialAuthProvider.kakao);

      expect(viewModel.session, isNull);
      expect(viewModel.isLoggedIn, isFalse);
      expect(viewModel.errorMessage, '오류가 발생했습니다.');
      expect(viewModel.isLoading, isFalse);
    });

    test(
      'keeps session null when signIn succeeds but repository session is null',
      () async {
        // given
        when(
          mockAuthRepository.signIn(SocialAuthProvider.kakao),
        ).thenAnswer((_) async => Result.ok(null));
        when(mockAuthRepository.session).thenReturn(null);

        // when
        await viewModel.signIn(SocialAuthProvider.kakao);

        // then
        expect(viewModel.session, isNull);
        expect(viewModel.isLoggedIn, isFalse);
        expect(viewModel.errorMessage, isNull);
        expect(viewModel.isLoading, isFalse);
      },
    );
  });
}
