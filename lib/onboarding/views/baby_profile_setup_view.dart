import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/common/design_system/app_colors.dart';
import 'package:yuktoe/common/design_system/app_text_styles.dart';
import 'package:yuktoe/constants/enum/relationship.dart';
import 'package:yuktoe/onboarding/view_models/baby_profile_setup_view_model.dart';

class BabyProfileSetupView extends StatefulWidget {
  const BabyProfileSetupView({super.key});

  @override
  State<BabyProfileSetupView> createState() => _BabyProfileSetupViewState();
}

class _BabyProfileSetupViewState extends State<BabyProfileSetupView> {
  final _nicknameController = TextEditingController();

  static const _backgroundGradientTop = Color(0xFFEEF2FF);
  static const _iconGradientStart = Color(0xFF615FFF);
  static const _iconGradientEnd = Color(0xFF9810FA);
  static const _buttonGradientStart = Color(0xFF615FFF);
  static const _buttonGradientEnd = Color(0xFF9810FA);

  static const _relationshipOptions = [
    (Relationship.mom, '👩', '엄마'),
    (Relationship.dad, '👨', '아빠'),
    (Relationship.family, '👨\u200D👩\u200D👧', '가족'),
    (Relationship.other, '👤', '기타'),
  ];

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    final viewModel = context.read<BabyProfileSetupViewModel>();
    try {
      await viewModel.submit();
      if (!mounted) return;
      // TODO: 홈 화면으로 이동
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.error ?? '오류가 발생했습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
                  _buildHeader(),
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
          _buildSubmitButton(viewModel),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
          colors: [_backgroundGradientTop, AppColors.backgroundPrimary],
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
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_iconGradientStart, _iconGradientEnd],
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
            '거의 다 왔어요!',
            style: AppTextStyles.heading1.bold.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '마지막으로 정보를 입력해주세요',
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
        _buildLabel('아기와의 관계', isRequired: true),
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
        _buildLabel('닉네임', isRequired: true),
        const SizedBox(height: 8),
        TextField(
          controller: _nicknameController,
          onChanged: viewModel.setNickname,
          maxLength: BabyProfileSetupViewModel.nicknameMaxLength,
          style: AppTextStyles.body.regular.copyWith(
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: '예: 리암엄마',
            hintStyle: AppTextStyles.body.regular.copyWith(
              color: AppColors.textPrimary.withValues(alpha: 0.5),
            ),
            helperText: '다른 가족 구성원에게 표시될 이름이에요',
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

  Widget _buildSubmitButton(BabyProfileSetupViewModel viewModel) {
    final isEnabled = viewModel.isValid;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: GestureDetector(
        onTap: isEnabled ? _onSubmit : null,
        child: AnimatedOpacity(
          opacity: isEnabled ? 1.0 : 0.5,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [_buttonGradientStart, _buttonGradientEnd],
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
                      '시작하기',
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
