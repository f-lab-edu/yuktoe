import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/data/repositories/auth_repository/auth_repository.dart';
import 'package:yuktoe/presentation/auth/login/views/login_view.dart';
import 'package:yuktoe/presentation/auth/login/vjew_models/login_view_model.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => LoginViewModel(context.read<AuthRepository>()),
      child: const LoginView(),
    );
  }
}
