import 'package:go_router/go_router.dart';
import 'package:yuktoe/domain/models/baby_registration/onboarding_flow.dart';
import 'package:yuktoe/onboarding/views/baby_profile_setup_view.dart';
import 'package:yuktoe/onboarding/views/baby_registration_view.dart';
import 'package:yuktoe/onboarding/views/invite_code_view.dart';
import 'package:yuktoe/onboarding/views/welcome_view.dart';

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
          builder: (context, state) => const BabyRegistrationView(),
        ),
        GoRoute(
          path: 'baby-profile-setup',
          builder: (context, state) {
            final flow = state.extra! as OnboardingFlow;
            return BabyProfileSetupView(flow: flow);
          },
        ),
        GoRoute(
          path: 'invite-code',
          builder: (context, state) => const InviteCodeView(),
        ),
      ],
    ),
  ],
);
