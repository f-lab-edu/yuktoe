import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/common/design_system/app_colors.dart';
import 'package:yuktoe/common/design_system/app_text_styles.dart';
import 'package:yuktoe/constants/app_strings.dart';
import 'package:yuktoe/constants/enum/relationship.dart';
import 'package:yuktoe/presentation/onboarding/view_models/baby_profile_setup_view_model.dart';

class BabyProfileSetupView extends StatelessWidget {
  const BabyProfileSetupView({super.key});

  static const _relationshipOptions = [
    (Relationship.mom, '👩', AppStrings.relationshipMom),
    (Relationship.dad, '👨', AppStrings.relationshipDad),
    (Relationship.family, '👨\u200D👩\u200D👧', AppStrings.relationshipFamily),
    (Relationship.other, '👤', AppStrings.relationshipOther),
  ];

  Future<void> _onSubmit(BuildContext context) async {
    final viewModel = context.read<BabyProfileSetupViewModel>();
    await viewModel.submit();
    if (!context.mounted) return;

    if (viewModel.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.error!),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // TODO: 홈 화면으로 이동
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<BabyProfileSetupViewModel>();

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(context),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildRelationshipGrid(viewModel),
                        const SizedBox(height: 32),
                        _buildNicknameField(viewModel),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildSubmitButton(context, viewModel),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 24,
        bottom: 32,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.backgroundVioletLight, AppColors.backgroundPrimary],
        ),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: () => context.pop(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.violet.t400, AppColors.violet.t600],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.favorite,
                size: 40,
                color: AppColors.textOnDark,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.profileSetupHeading,
            style: AppTextStyles.heading1.bold.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.profileSetupSubheading,
            style: AppTextStyles.body.regular.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelationshipGrid(BabyProfileSetupViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(AppStrings.relationshipLabel, isRequired: true),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 194 / 128,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          children: _relationshipOptions.map((option) {
            final (relationship, emoji, label) = option;
            final isSelected = viewModel.relationship == relationship;
            return _RelationshipCard(
              emoji: emoji,
              label: label,
              isSelected: isSelected,
              onTap: () => viewModel.setRelationship(relationship),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNicknameField(BabyProfileSetupViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(AppStrings.nicknameLabel, isRequired: true),
        const SizedBox(height: 8),
        TextField(
          onChanged: viewModel.setNickname,
          maxLength: BabyProfileSetupViewModel.nicknameMaxLength,
          style: AppTextStyles.body.regular.copyWith(
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: AppStrings.nicknameHint,
            hintStyle: AppTextStyles.body.regular.copyWith(
              color: AppColors.textPrimary.withValues(alpha: 0.5),
            ),
            helperText: AppStrings.nicknameHelper,
            helperStyle: AppTextStyles.caption.regular.copyWith(
              color: AppColors.textSecondary,
            ),
            counterStyle: AppTextStyles.caption.regular.copyWith(
              color: AppColors.textDisabled,
            ),
            contentPadding: const EdgeInsets.all(16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.borderPrimary,
                width: 2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.brandPrimary,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text, {bool isRequired = false}) {
    return RichText(
      text: TextSpan(
        style: AppTextStyles.label.semibold.copyWith(
          color: AppColors.gray.t700,
        ),
        children: [
          TextSpan(text: '$text '),
          if (isRequired)
            const TextSpan(
              text: '*',
              style: TextStyle(color: AppColors.error),
            ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(
    BuildContext context,
    BabyProfileSetupViewModel viewModel,
  ) {
    final isEnabled = viewModel.isValid;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: GestureDetector(
        onTap: isEnabled ? () => _onSubmit(context) : null,
        child: AnimatedOpacity(
          opacity: isEnabled ? 1.0 : 0.5,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [AppColors.violet.t400, AppColors.violet.t600],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: viewModel.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: AppColors.textOnDark,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      AppStrings.start,
                      style: AppTextStyles.body.bold.copyWith(
                        color: AppColors.textOnDark,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RelationshipCard extends StatelessWidget {
  final String emoji;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _RelationshipCard({
    required this.emoji,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundPrimary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.brandPrimary
                : AppColors.borderPrimary,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 12),
            Text(
              label,
              style: AppTextStyles.body.semibold.copyWith(
                color: isSelected
                    ? AppColors.brandPrimary
                    : AppColors.gray.t700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
