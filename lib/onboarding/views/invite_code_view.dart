import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/common/design_system/app_colors.dart';
import 'package:yuktoe/common/design_system/app_text_styles.dart';
import 'package:yuktoe/constants/app_strings.dart';
import 'package:yuktoe/constants/enum/gender.dart';
import 'package:yuktoe/domain/models/baby_registration/baby_summary.dart';
import 'package:yuktoe/domain/models/baby_registration/onboarding_flow.dart';
import 'package:yuktoe/onboarding/view_models/invite_code_view_model.dart';
import 'package:yuktoe/routing/router.dart';

class InviteCodeView extends StatefulWidget {
  const InviteCodeView({super.key});

  @override
  State<InviteCodeView> createState() => _InviteCodeViewState();
}

class _InviteCodeViewState extends State<InviteCodeView> {
  void _onViewModelChanged() {
    final viewModel = context.read<InviteCodeViewModel>();

    if (viewModel.verifiedBaby != null) {
      _showBabyConfirmModal(viewModel.verifiedBaby!);
    } else if (viewModel.error != null) {
      _showNotFoundAlert();
    }
  }

  void _showNotFoundAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          AppStrings.babyNotFoundTitle,
          style: AppTextStyles.title.bold.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          AppStrings.babyNotFoundBody,
          style: AppTextStyles.label.regular.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              AppStrings.confirm,
              style: AppTextStyles.label.semibold.copyWith(
                color: AppColors.brandPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBabyConfirmModal(BabySummary baby) {
    final genderText = baby.gender == Gender.male ? AppStrings.maleLabel : AppStrings.femaleLabel;
    final birthDate = baby.birthDate ?? baby.dueDate;
    if (birthDate == null) return;

    final dDay = DateTime.now().difference(birthDate).inDays;
    final formattedDate =
        '${birthDate.year}년 ${birthDate.month}월 ${birthDate.day}일';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: EdgeInsets.fromLTRB(
          24,
          32,
          24,
          MediaQuery.of(sheetContext).padding.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: AppColors.backgroundPrimary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.gray.t300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppStrings.babyConfirmTitle,
              style: AppTextStyles.heading3.bold.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderPrimary),
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.brandAccent, AppColors.violet.t500],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          baby.name,
                          style: AppTextStyles.heading2.bold.copyWith(
                            color: AppColors.textOnDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          genderText,
                          style: AppTextStyles.label.regular.copyWith(
                            color: AppColors.textOnDark.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            'D+$dDay',
                            style: AppTextStyles.label.semibold.copyWith(
                              color: AppColors.textOnDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.t100,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.calendar_today_outlined,
                              size: 20,
                              color: AppColors.primary.t600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.birthDate,
                              style: AppTextStyles.caption.semibold.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formattedDate,
                              style: AppTextStyles.body.semibold.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      context.read<InviteCodeViewModel>().clearVerifiedBaby();
                    },
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.gray.t100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          AppStrings.no,
                          style: AppTextStyles.body.semibold.copyWith(
                            color: AppColors.gray.t700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      final code =
                          context.read<InviteCodeViewModel>().code;
                      Navigator.of(sheetContext).pop();
                      context.push(
                        AppRoutes.babyProfileSetup,
                        extra: JoinBabyFlow(inviteCode: code),
                      );
                    },
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.brandAccent, AppColors.violet.t500],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          AppStrings.yes,
                          style: AppTextStyles.body.semibold.copyWith(
                            color: AppColors.textOnDark,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSubmit() async {
    final viewModel = context.read<InviteCodeViewModel>();
    await viewModel.verifyInviteCode();
    if (!mounted) return;
    _onViewModelChanged();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<InviteCodeViewModel>();

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          AppStrings.inviteCodeAppBar,
          style: AppTextStyles.title.bold.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        titleSpacing: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.borderPrimary),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 48),
                  _buildIcon(),
                  const SizedBox(height: 32),
                  _buildDescription(),
                  const SizedBox(height: 32),
                  _buildCodeField(viewModel),
                  const SizedBox(height: 24),
                  _buildInfoBox(),
                  const SizedBox(height: 24),
                  _buildTermsCheckbox(viewModel),
                ],
              ),
            ),
          ),
          _buildSubmitButton(viewModel),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.pink.t400, AppColors.pink.t600],
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
        child: Icon(Icons.key_outlined, size: 40, color: AppColors.textOnDark),
      ),
    );
  }

  Widget _buildDescription() {
    return Column(
      children: [
        Text(
          AppStrings.inviteCodeHeading,
          style: AppTextStyles.heading3.bold.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.inviteCodeSubheading,
          textAlign: TextAlign.center,
          style: AppTextStyles.label.regular.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildCodeField(InviteCodeViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: AppTextStyles.label.semibold.copyWith(
              color: AppColors.gray.t700,
            ),
            children: const [
              TextSpan(text: AppStrings.inviteCodeFieldLabel),
              TextSpan(
                text: '*',
                style: TextStyle(color: AppColors.error),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          onChanged: viewModel.setCode,
          textAlign: TextAlign.left,
          style: const TextStyle(
            fontSize: 18,
            fontFamily: 'Menlo',
            color: AppColors.textPrimary,
            letterSpacing: 0.9,
          ),
          decoration: InputDecoration(
            hintText: AppStrings.inviteCodeHint,
            hintStyle: TextStyle(
              fontSize: 18,
              fontFamily: 'Menlo',
              color: AppColors.textPrimary.withValues(alpha: 0.5),
              letterSpacing: 0.9,
            ),
            contentPadding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(minHeight: 64),
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
        const SizedBox(height: 8),
        Center(
          child: Text(
            AppStrings.inviteCodeHelp,
            style: AppTextStyles.caption.regular.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brandPrimaryLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.t200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: AppColors.brandAccent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                'i',
                style: AppTextStyles.caption.bold.copyWith(
                  color: AppColors.textOnDark,
                  height: 1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.inviteCodeInfoTitle,
                  style: AppTextStyles.label.semibold.copyWith(
                    color: AppColors.infoTitle,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppStrings.inviteCodeInfoBody,
                  style: AppTextStyles.caption.regular.copyWith(
                    color: AppColors.infoBody,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsCheckbox(InviteCodeViewModel viewModel) {
    return GestureDetector(
      onTap: viewModel.toggleAgreedToTerms,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: viewModel.agreedToTerms,
              onChanged: (_) => viewModel.toggleAgreedToTerms(),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              activeColor: AppColors.pink.t500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTextStyles.label.medium,
                children: [
                  TextSpan(
                    text: AppStrings.termsOfService,
                    style: AppTextStyles.label.semibold.copyWith(
                      color: AppColors.pink.t500,
                    ),
                  ),
                  const TextSpan(
                    text: ', ',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                  TextSpan(
                    text: AppStrings.privacyPolicy,
                    style: AppTextStyles.label.semibold.copyWith(
                      color: AppColors.pink.t500,
                    ),
                  ),
                  const TextSpan(
                    text: AppStrings.termsAgreeSuffix,
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                  const TextSpan(
                    text: AppStrings.requiredMark,
                    style: TextStyle(color: AppColors.error),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(InviteCodeViewModel viewModel) {
    final isEnabled = viewModel.isValid;

    return Padding(
      padding: const EdgeInsets.all(24),
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
              gradient: LinearGradient(
                colors: [AppColors.pink.t400, AppColors.pink.t600],
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
                      AppStrings.next,
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
