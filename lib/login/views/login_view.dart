import 'package:flutter/material.dart';
import 'package:yuktoe/common/views/logo.dart';
import 'package:yuktoe/gen/assets.gen.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.fromARGB(255, 121, 195, 255), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 48),
                  Logo(),
                  const SizedBox(height: 16),
                  const Text(
                    '내꿈은육퇴',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF101828),
                      letterSpacing: 0.37,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '우리 아기 성장 기록',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF6A7282),
                      letterSpacing: -0.31,
                    ),
                  ),
                  const SizedBox(height: 64),
                  SocialLoginButton(
                    onPressed: () {},
                    backgroundColor: const Color(0xFFFEE500),
                    icon: Assets.icons.kakao.svg(width: 24),
                    label: '카카오로 시작하기',
                    textColor: const Color(0xFF101828),
                  ),
                  const SizedBox(height: 16),
                  SocialLoginButton(
                    onPressed: () {},
                    backgroundColor: Colors.white,
                    icon: Assets.icons.google.svg(width: 24),
                    label: 'Google로 시작하기',
                    textColor: const Color(0xFF101828),
                  ),
                  const SizedBox(height: 16),
                  SocialLoginButton(
                    onPressed: () {},
                    backgroundColor: Colors.black,
                    icon: Assets.icons.apple.svg(width: 24),
                    label: 'Apple로 시작하기',
                    textColor: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SocialLoginButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Widget icon;
  final String label;
  final Color textColor;

  const SocialLoginButton({
    super.key,
    required this.onPressed,
    required this.backgroundColor,
    required this.icon,
    required this.label,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
                letterSpacing: -0.31,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
