import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:yuktoe/common/design_system/app_colors.dart';
import 'package:yuktoe/common/design_system/app_text_styles.dart';
import 'package:yuktoe/routing/router.dart';

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  static const _title = '환영합니다!';
  static const _subtitle = '시작 방법을 선택해주세요';
  static const _footerText = '가족 구성원과 함께 아기의 성장을 기록하고 공유하세요';

  static const _horizontalPadding = 16.0;
  static const _titleSubtitleSpacing = 12.0;
  static const _headerContentSpacing = 48.0;
  static const _cardSpacing = 20.0;
  static const _footerTopSpacing = 32.0;

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
            colors: [AppColors.brandPrimaryLight, AppColors.backgroundPrimary],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: _horizontalPadding,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _title,
                    style: AppTextStyles.heading1.bold.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: _titleSubtitleSpacing),
                  Text(
                    _subtitle,
                    style: AppTextStyles.body.regular.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: _headerContentSpacing),
                  _OptionCard(
                    icon: Icons.person_add_outlined,
                    iconGradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2B7FFF), Color(0xFF4F39F6)],
                    ),
                    title: '우리 아기 등록하기',
                    description: '새로운 아기의 정보를 등록합니다',
                    onTap: () => context.push(AppRoutes.babyRegistration),
                  ),
                  const SizedBox(height: _cardSpacing),
                  _OptionCard(
                    icon: Icons.key_outlined,
                    iconGradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF6339A), Color(0xFFEC003F)],
                    ),
                    title: '초대 코드가 있어요',
                    description: '가족 초대 코드로 참여합니다',
                    onTap: () => context.push(AppRoutes.inviteCode),
                  ),
                  const SizedBox(height: _footerTopSpacing),
                  Text(
                    _footerText,
                    style: AppTextStyles.caption.regular.copyWith(
                      color: AppColors.textSecondary,
                    ),
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

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final Gradient iconGradient;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.iconGradient,
    required this.title,
    required this.description,
    required this.onTap,
  });

  static const _cardRadius = 24.0;
  static const _cardPadding = 32.0;
  static const _iconContainerSize = 64.0;
  static const _iconSize = 32.0;
  static const _iconRadius = 16.0;
  static const _iconTitleSpacing = 16.0;
  static const _titleDescriptionSpacing = 4.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(_cardPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_cardRadius),
            border: Border.all(color: AppColors.borderPrimary, width: 2),
          ),
          child: Column(
            children: [
              Container(
                width: _iconContainerSize,
                height: _iconContainerSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_iconRadius),
                  gradient: iconGradient,
                ),
                child: Center(
                  child: Icon(icon, size: _iconSize, color: AppColors.white),
                ),
              ),
              const SizedBox(height: _iconTitleSpacing),
              Text(
                title,
                style: AppTextStyles.title.bold.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: _titleDescriptionSpacing),
              Text(
                description,
                style: AppTextStyles.label.medium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
    );
  }
}
