import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/common/design_system/app_colors.dart';
import 'package:yuktoe/common/design_system/app_text_styles.dart';
import 'package:yuktoe/constants/app_strings.dart';
import 'package:yuktoe/constants/enum/gender.dart';
import 'package:yuktoe/domain/models/baby_registration/onboarding_flow.dart';
import 'package:yuktoe/onboarding/view_models/baby_registration_view_model.dart';
import 'package:yuktoe/routing/router.dart';

class BabyRegistrationView extends StatelessWidget {
  const BabyRegistrationView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<BabyRegistrationViewModel>();

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
          AppStrings.babyRegistrationAppBar,
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
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NameField(
                    onChanged: viewModel.setName,
                  ),
                  const SizedBox(height: 24),
                  _GenderField(
                    selectedGender: viewModel.gender,
                    onSelect: viewModel.setGender,
                  ),
                  const SizedBox(height: 24),
                  _DateField(
                    label: AppStrings.birthDate,
                    isRequired: true,
                    value: viewModel.birthDate,
                    onSelect: viewModel.setBirthDate,
                  ),
                  const SizedBox(height: 24),
                  _DateField(
                    label: AppStrings.dueDateLabel,
                    isRequired: false,
                    value: viewModel.dueDate,
                    onSelect: viewModel.setDueDate,
                  ),
                  const SizedBox(height: 32),
                  _TermsCheckbox(
                    value: viewModel.agreedToTerms,
                    onToggle: viewModel.toggleAgreedToTerms,
                  ),
                ],
              ),
            ),
          ),
          _SubmitButton(
            isEnabled: viewModel.isValid,
            onPressed: () {
              context.push(
                AppRoutes.babyProfileSetup,
                extra: CreateBabyFlow(
                  name: viewModel.name,
                  gender: viewModel.gender!,
                  birthDate: viewModel.birthDate!,
                  dueDate: viewModel.dueDate,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _NameField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(AppStrings.nameLabel, isRequired: true),
        const SizedBox(height: 8),
        TextField(
          onChanged: onChanged,
          style: AppTextStyles.body.regular.copyWith(
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: AppStrings.nameHint,
            hintStyle: AppTextStyles.body.regular.copyWith(
              color: AppColors.textPrimary.withValues(alpha: 0.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
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
}

class _GenderField extends StatelessWidget {
  final Gender? selectedGender;
  final ValueChanged<Gender> onSelect;

  const _GenderField({required this.selectedGender, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(AppStrings.genderLabel, isRequired: true),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _GenderButton(
                label: AppStrings.maleLabel,
                isSelected: selectedGender == Gender.male,
                onTap: () => onSelect(Gender.male),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _GenderButton(
                label: AppStrings.femaleLabel,
                isSelected: selectedGender == Gender.female,
                onTap: () => onSelect(Gender.female),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final bool isRequired;
  final DateTime? value;
  final ValueChanged<DateTime> onSelect;

  const _DateField({
    required this.label,
    required this.isRequired,
    required this.value,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final formattedDate = value != null
        ? '${value!.year}.${value!.month.toString().padLeft(2, '0')}.${value!.day.toString().padLeft(2, '0')}'
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label, isRequired: isRequired),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showDatePicker(context),
          child: Container(
            width: double.infinity,
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderPrimary, width: 2),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 20,
                  color: value != null
                      ? AppColors.textPrimary
                      : AppColors.textDisabled,
                ),
                if (value != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    formattedDate,
                    style: AppTextStyles.body.regular.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showDatePicker(BuildContext context) {
    final now = DateTime.now();
    final initialDate = value ?? now;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    if (isIOS) {
      var selectedDate = initialDate;
      showCupertinoModalPopup(
        context: context,
        builder: (_) => Container(
          height: 300,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      child: const Text(AppStrings.cancel),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    CupertinoButton(
                      child: const Text(AppStrings.done),
                      onPressed: () {
                        onSelect(selectedDate);
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initialDate,
                  maximumDate: DateTime(now.year + 2, 12, 31),
                  minimumDate: DateTime(2000),
                  onDateTimeChanged: (date) => selectedDate = date,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(now.year + 2, 12, 31),
      ).then((date) {
        if (date != null) onSelect(date);
      });
    }
  }
}

class _TermsCheckbox extends StatelessWidget {
  final bool value;
  final VoidCallback onToggle;

  const _TermsCheckbox({required this.value, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: value,
              onChanged: (_) => onToggle(),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              activeColor: AppColors.brandPrimary,
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
                      color: AppColors.brandPrimary,
                    ),
                  ),
                  const TextSpan(
                    text: ', ',
                    style: TextStyle(color: Color(0xFF364153)),
                  ),
                  TextSpan(
                    text: AppStrings.privacyPolicy,
                    style: AppTextStyles.label.semibold.copyWith(
                      color: AppColors.brandPrimary,
                    ),
                  ),
                  const TextSpan(
                    text: AppStrings.termsAgreeSuffix,
                    style: TextStyle(color: Color(0xFF364153)),
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
}

class _SubmitButton extends StatelessWidget {
  final bool isEnabled;
  final VoidCallback onPressed;

  const _SubmitButton({required this.isEnabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: GestureDetector(
        onTap: isEnabled ? onPressed : null,
        child: AnimatedOpacity(
          opacity: isEnabled ? 1.0 : 0.5,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFF2B7FFF), Color(0xFF4F39F6)],
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
              child: Text(
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

class _GenderButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brandPrimaryLight : AppColors.gray.t100,
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? Border.all(color: AppColors.brandPrimary, width: 2)
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.body.semibold.copyWith(
              color: isSelected ? AppColors.brandPrimary : AppColors.gray.t700,
            ),
          ),
        ),
      ),
    );
  }
}
