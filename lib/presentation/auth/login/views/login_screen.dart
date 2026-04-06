import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/constants/enum/social_auth_provider.dart';
import 'package:yuktoe/data/repositories/auth_repository/auth_repository.dart';
import 'package:yuktoe/presentation/auth/login/vjew_models/login_view_model.dart';
import 'package:yuktoe/presentation/home/home_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => LoginViewModel(context.read<AuthRepository>()),
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatelessWidget {
  const _LoginView();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<LoginViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '로그인 테스트',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 48),
              if (viewModel.errorMessage != null) ...[
                Text(
                  viewModel.errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
              _LoginButton(
                label: 'Google로 로그인',
                icon: Icons.g_mobiledata,
                onPressed: viewModel.isLoading
                    ? null
                    : () => _handleSignIn(context, SocialAuthProvider.google),
              ),
              const SizedBox(height: 12),
              _LoginButton(
                label: 'Apple로 로그인',
                icon: Icons.apple,
                onPressed: viewModel.isLoading
                    ? null
                    : () => _handleSignIn(context, SocialAuthProvider.apple),
              ),
              const SizedBox(height: 12),
              _LoginButton(
                label: 'Kakao로 로그인',
                icon: Icons.chat_bubble,
                onPressed: viewModel.isLoading
                    ? null
                    : () => _handleSignIn(context, SocialAuthProvider.kakao),
              ),
              const SizedBox(height: 24),
              if (viewModel.isLoading) const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSignIn(
    BuildContext context,
    SocialAuthProvider provider,
  ) async {
    final viewModel = context.read<LoginViewModel>();

    await viewModel.signIn(provider);

    if (!context.mounted) return;

    if (viewModel.isLoggedIn) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  final double _height = 48;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: _height,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}
