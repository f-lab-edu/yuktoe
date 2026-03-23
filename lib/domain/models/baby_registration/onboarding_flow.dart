import 'package:yuktoe/constants/enum/gender.dart';

sealed class OnboardingFlow {
  const OnboardingFlow();
}

class CreateBabyFlow extends OnboardingFlow {
  final String name;
  final Gender gender;
  final DateTime? birthDate;
  final DateTime? dueDate;

  const CreateBabyFlow({
    required this.name,
    required this.gender,
    this.birthDate,
    this.dueDate,
  });
}

class JoinBabyFlow extends OnboardingFlow {
  final String inviteCode;

  const JoinBabyFlow({required this.inviteCode});
}
