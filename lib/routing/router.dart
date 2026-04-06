import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/data/repositories/baby_registration_repository/baby_registration_repository.dart';
import 'package:yuktoe/domain/models/baby_registration/onboarding_flow.dart';
import 'package:yuktoe/presentation/onboarding/view_models/baby_profile_setup_view_model.dart';
import 'package:yuktoe/presentation/onboarding/view_models/baby_registration_view_model.dart';
import 'package:yuktoe/presentation/onboarding/view_models/invite_code_view_model.dart';
import 'package:yuktoe/presentation/onboarding/views/baby_profile_setup_view.dart';
import 'package:yuktoe/presentation/onboarding/views/baby_registration_view.dart';
import 'package:yuktoe/presentation/onboarding/views/invite_code_view.dart';
import 'package:yuktoe/presentation/onboarding/views/welcome_view.dart';

abstract class AppRoutes {
  static const welcome = '/welcome';
  static const babyRegistration = '/welcome/baby-registration';
  static const babyProfileSetup = '/welcome/baby-profile-setup';
  static const inviteCode = '/welcome/invite-code';
}

final router = GoRouter(
  initialLocation: AppRoutes.welcome,
  routes: [
    GoRoute(
      path: AppRoutes.welcome,
      builder: (context, state) => const WelcomeView(),
      routes: [
        GoRoute(
          path: 'baby-registration',
          builder: (context, state) => ChangeNotifierProvider(
            create: (_) => BabyRegistrationViewModel(),
            child: const BabyRegistrationView(),
          ),
        ),
        GoRoute(
          path: 'baby-profile-setup',
          builder: (context, state) {
            final flow = state.extra! as OnboardingFlow;
            return ChangeNotifierProvider(
              create: (context) => BabyProfileSetupViewModel(
                flow: flow,
                repository: context.read<BabyRegistrationRepository>(),
              ),
              child: const BabyProfileSetupView(),
            );
          },
        ),
        GoRoute(
          path: 'invite-code',
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
