import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/data/repositories/auth_repository/auth_repository.dart';
import 'package:yuktoe/data/repositories/baby_registration_repository/baby_registration_repository.dart';
import 'package:yuktoe/presentation/auth/login/view_models/login_view_model.dart';
import 'package:yuktoe/presentation/auth/login/views/login_view.dart';
import 'package:yuktoe/presentation/home/home_screen.dart';
import 'package:yuktoe/presentation/onboarding/view_models/baby_profile_setup_view_model.dart';
import 'package:yuktoe/presentation/onboarding/view_models/baby_registration_view_model.dart';
import 'package:yuktoe/presentation/onboarding/view_models/invite_code_view_model.dart';
import 'package:yuktoe/presentation/onboarding/views/baby_profile_setup_view.dart';
import 'package:yuktoe/presentation/onboarding/views/baby_registration_view.dart';
import 'package:yuktoe/presentation/onboarding/views/invite_code_view.dart';
import 'package:yuktoe/presentation/onboarding/views/welcome_view.dart';

abstract class AppRoutes {
  static const login = '/login';
  static const welcome = '/welcome';
  static const home = '/home';
  static const babyRegistration = '$welcome/$_babyRegistration';
  static const babyProfileSetup = '$welcome/$_babyProfileSetup';
  static const inviteCode = '$welcome/$_inviteCode';

  static const _babyRegistration = 'baby-registration';
  static const _babyProfileSetup = 'baby-profile-setup';
  static const _inviteCode = 'invite-code';
}

final router = GoRouter(
  initialLocation: AppRoutes.login,
  routes: [
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => ChangeNotifierProvider(
        create: (context) => LoginViewModel(context.read<AuthRepository>()),
        child: const LoginView(),
      ),
    ),
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.welcome,
      builder: (context, state) => const WelcomeView(),
      routes: [
        GoRoute(
          path: AppRoutes._babyRegistration,
          builder: (context, state) => ChangeNotifierProvider(
            create: (context) => BabyRegistrationViewModel(
              repository: context.read<BabyRegistrationRepository>(),
            ),
            child: const BabyRegistrationView(),
          ),
        ),
        GoRoute(
          path: AppRoutes._babyProfileSetup,
          builder: (context, state) {
            final babyId = state.extra! as String;
            return ChangeNotifierProvider(
              create: (context) => BabyProfileSetupViewModel(
                babyId: babyId,
                repository: context.read<BabyRegistrationRepository>(),
              ),
              child: const BabyProfileSetupView(),
            );
          },
        ),
        GoRoute(
          path: AppRoutes._inviteCode,
          builder: (context, state) => ChangeNotifierProvider(
            create: (context) => InviteCodeViewModel(
              repository: context.read<BabyRegistrationRepository>(),
            ),
            child: const InviteCodeView(),
          ),
        ),
      ],
    ),
  ],
);
