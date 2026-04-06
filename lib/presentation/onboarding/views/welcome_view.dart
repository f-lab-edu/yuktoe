import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:yuktoe/common/design_system/app_colors.dart';
import 'package:yuktoe/common/design_system/app_text_styles.dart';
import 'package:yuktoe/constants/app_strings.dart';
import 'package:yuktoe/routing/router.dart';

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

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
                    AppStrings.welcomeTitle,
                    style: AppTextStyles.heading1.bold.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: _titleSubtitleSpacing),
                  Text(
                    AppStrings.welcomeSubtitle,
                    style: AppTextStyles.body.regular.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: _headerContentSpacing),
                  _OptionCard(
                    icon: Icons.person_add_outlined,
                    iconGradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.brandAccent, AppColors.violet.t500],
                    ),
                    title: AppStrings.registerBabyTitle,
                    description: AppStrings.registerBabyDescription,
                    onTap: () => context.push(AppRoutes.babyRegistration),
                  ),
                  const SizedBox(height: _cardSpacing),
                  _OptionCard(
                    icon: Icons.key_outlined,
                    iconGradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.pink.t400, AppColors.pink.t600],
                    ),
                    title: AppStrings.inviteCodeTitle,
                    description: AppStrings.inviteCodeDescription,
                    onTap: () => context.push(AppRoutes.inviteCode),
                  ),
                  const SizedBox(height: _footerTopSpacing),
                  Text(
                    AppStrings.welcomeFooter,
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
