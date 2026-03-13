import 'package:flutter/material.dart';
import 'package:yuktoe/common/design_system/app_colors.dart';
import 'package:yuktoe/common/views/logo.dart';
import 'package:yuktoe/gen/assets.gen.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  static const _appTitle = '내꿈은육퇴';
  static const _appSubtitle = '우리 아기 성장 기록';
  static const _kakaoLoginText = '카카오로 시작하기';
  static const _googleLoginText = 'Google로 시작하기';
  static const _appleLoginText = 'Apple로 시작하기';

  static const _horizontalPadding = 32.0;
  static const _topSpacing = 48.0;
  static const _logoTitleSpacing = 16.0;
  static const _titleSubtitleSpacing = 8.0;
  static const _buttonSectionSpacing = 64.0;
  static const _buttonSpacing = 16.0;

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
            colors: [AppColors.loginGradientTop, AppColors.backgroundPrimary],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: _topSpacing),
                  Logo(),
                  const SizedBox(height: _logoTitleSpacing),
                  const Text(
                    _appTitle,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.37,
                    ),
                  ),
                  const SizedBox(height: _titleSubtitleSpacing),
                  const Text(
                    _appSubtitle,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                      letterSpacing: -0.31,
                    ),
                  ),
                  const SizedBox(height: _buttonSectionSpacing),
                  SocialLoginButton(
                    onPressed: () {},
                    backgroundColor: AppColors.kakaoBackground,
                    icon: Assets.icons.kakao.svg(width: 24),
                    label: _kakaoLoginText,
                    textColor: AppColors.textPrimary,
                  ),
                  const SizedBox(height: _buttonSpacing),
                  SocialLoginButton(
                    onPressed: () {},
                    backgroundColor: AppColors.backgroundPrimary,
                    icon: Assets.icons.google.svg(width: 24),
                    label: _googleLoginText,
                    textColor: AppColors.textPrimary,
                  ),
                  const SizedBox(height: _buttonSpacing),
                  SocialLoginButton(
                    onPressed: () {},
                    backgroundColor: AppColors.black,
                    icon: Assets.icons.apple.svg(width: 24),
                    label: _appleLoginText,
                    textColor: AppColors.textOnDark,
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

  static const _buttonHeight = 56.0;
  static const _buttonRadius = 16.0;
  static const _iconLabelSpacing = 12.0;
  static const _buttonFontSize = 16.0;
  static const _buttonLetterSpacing = -0.31;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: _buttonHeight,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_buttonRadius),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: _iconLabelSpacing),
            Text(
              label,
              style: TextStyle(
                fontSize: _buttonFontSize,
                fontWeight: FontWeight.w600,
                color: textColor,
                letterSpacing: _buttonLetterSpacing,
              ),
            ),
          ],
        ),
      ),
    );
  }
}