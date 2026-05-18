import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:yuktoe/constants/enum/social_auth_provider.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/repositories/auth_repository/auth_repository_impl.dart';
import 'package:yuktoe/data/services/auth_service/auth_service.dart';
import 'package:yuktoe/domain/models/auth/app_session.dart';
import 'package:yuktoe/domain/models/auth/app_user.dart';

class MockAuthService extends Mock implements AuthService {
  @override
  Future<Result<AppSession?>> getCurrentSession() =>
      super.noSuchMethod(
        Invocation.method(#getCurrentSession, []),
        returnValue: Future.value(Result.ok(null)),
      ) as Future<Result<AppSession?>>;

  @override
  Future<Result<void>> signIn(SocialAuthProvider provider) =>
      super.noSuchMethod(
        Invocation.method(#signIn, [provider]),
        returnValue: Future.value(Result.ok(null)),
      ) as Future<Result<void>>;

  @override
  Future<Result<void>> signOut() =>
      super.noSuchMethod(
        Invocation.method(#signOut, []),
        returnValue: Future.value(Result.ok(null)),
      ) as Future<Result<void>>;
}

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
  late MockAuthService mockAuthService;
  late AuthRepositoryImpl repository;

  setUp(() {
    mockAuthService = MockAuthService();
    repository = AuthRepositoryImpl(mockAuthService);
  });

  group('getSession', () {
    test('given getCurrentSession returns Ok(AppSession), '
        'when getSession is called, '
        'then session is updated and isLoggedIn is true', () async {
      // arrange
      final session = createSession();
      when(mockAuthService.getCurrentSession())
          .thenAnswer((_) async => Result.ok(session));

      // act
      final result = await repository.getSession();

      // assert
      expect(result, isA<Ok<AppSession?>>());
      expect((result as Ok<AppSession?>).value, same(session));
      expect(repository.session, same(session));
      expect(repository.isLoggedIn, isTrue);
    });

    test('given getCurrentSession returns Ok(null), '
        'when getSession is called, '
        'then session is null and isLoggedIn is false', () async {
      // arrange
      when(mockAuthService.getCurrentSession())
          .thenAnswer((_) async => Result.ok(null));

      // act
      final result = await repository.getSession();

      // assert
      expect(result, isA<Ok<AppSession?>>());
      expect((result as Ok<AppSession?>).value, isNull);
      expect(repository.session, isNull);
      expect(repository.isLoggedIn, isFalse);
    });

    test('given getCurrentSession returns Error, '
        'when getSession is called, '
        'then session is cleared and error is returned', () async {
      // arrange
      final exception = AppException(ErrorCode.unknown, 'session error');
      when(mockAuthService.getCurrentSession())
          .thenAnswer((_) async => Result.error(exception));

      // act
      final result = await repository.getSession();

      // assert
      expect(result, isA<Error<AppSession?>>());
      expect((result as Error<AppSession?>).error, same(exception));
      expect(repository.session, isNull);
      expect(repository.isLoggedIn, isFalse);
    });
  });

  group('signIn', () {
    test('given signIn succeeds and getCurrentSession returns Ok(AppSession), '
        'when signIn is called, '
        'then session is updated and isLoggedIn is true', () async {
      // arrange
      final session = createSession();
      when(mockAuthService.signIn(SocialAuthProvider.google))
          .thenAnswer((_) async => Result.ok(null));
      when(mockAuthService.getCurrentSession())
          .thenAnswer((_) async => Result.ok(session));

      // act
      final result = await repository.signIn(SocialAuthProvider.google);

      // assert
      expect(result, isA<Ok<void>>());
      expect(repository.session, same(session));
      expect(repository.isLoggedIn, isTrue);
    });

    test('given signIn succeeds and getCurrentSession returns Ok(null), '
        'when signIn is called, '
        'then session is null and isLoggedIn is false', () async {
      // arrange
      when(mockAuthService.signIn(SocialAuthProvider.google))
          .thenAnswer((_) async => Result.ok(null));
      when(mockAuthService.getCurrentSession())
          .thenAnswer((_) async => Result.ok(null));

      // act
      final result = await repository.signIn(SocialAuthProvider.google);

      // assert
      expect(result, isA<Ok<void>>());
      expect(repository.session, isNull);
      expect(repository.isLoggedIn, isFalse);
    });

    test('given signIn returns Error, '
        'when signIn is called, '
        'then error is returned and getCurrentSession is not called', () async {
      // arrange
      final exception = AppException(ErrorCode.unknown, 'sign in error');
      when(mockAuthService.signIn(SocialAuthProvider.google))
          .thenAnswer((_) async => Result.error(exception));

      // act
      final result = await repository.signIn(SocialAuthProvider.google);

      // assert
      expect(result, isA<Error<void>>());
      expect((result as Error<void>).error, same(exception));
      verifyNever(mockAuthService.getCurrentSession());
    });

    test('given signIn succeeds but getCurrentSession returns Error, '
        'when signIn is called, '
        'then error is propagated and session is null', () async {
      // arrange
      final exception = AppException(ErrorCode.unknown, 'session fetch error');
      when(mockAuthService.signIn(SocialAuthProvider.google))
          .thenAnswer((_) async => Result.ok(null));
      when(mockAuthService.getCurrentSession())
          .thenAnswer((_) async => Result.error(exception));

      // act
      final result = await repository.signIn(SocialAuthProvider.google);

      // assert
      expect(result, isA<Error<void>>());
      expect((result as Error<void>).error, same(exception));
      expect(repository.session, isNull);
      expect(repository.isLoggedIn, isFalse);
    });
  });

  group('signOut', () {
    test('given user is logged in and signOut succeeds, '
        'when signOut is called, '
        'then session becomes null and isLoggedIn is false', () async {
      // arrange: log in first
      final session = createSession();
      when(mockAuthService.getCurrentSession())
          .thenAnswer((_) async => Result.ok(session));
      await repository.getSession();
      expect(repository.isLoggedIn, isTrue);

      when(mockAuthService.signOut())
          .thenAnswer((_) async => Result.ok(null));

      // act
      final result = await repository.signOut();

      // assert
      expect(result, isA<Ok<void>>());
      expect(repository.session, isNull);
      expect(repository.isLoggedIn, isFalse);
    });

    test('given user is logged in and signOut returns Error, '
        'when signOut is called, '
        'then error is returned and existing session is preserved', () async {
      // arrange: log in first
      final session = createSession();
      when(mockAuthService.getCurrentSession())
          .thenAnswer((_) async => Result.ok(session));
      await repository.getSession();
      expect(repository.isLoggedIn, isTrue);

      final exception = AppException(ErrorCode.unknown, 'sign out error');
      when(mockAuthService.signOut())
          .thenAnswer((_) async => Result.error(exception));

      // act
      final result = await repository.signOut();

      // assert
      expect(result, isA<Error<void>>());
      expect((result as Error<void>).error, same(exception));
      expect(repository.session, same(session));
      expect(repository.isLoggedIn, isTrue);
    });
  });
}
