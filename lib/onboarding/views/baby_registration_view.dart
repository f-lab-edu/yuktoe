import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:yuktoe/common/design_system/app_colors.dart';
import 'package:yuktoe/common/design_system/app_text_styles.dart';
import 'package:yuktoe/constants/enum/gender.dart';
import 'package:yuktoe/domain/models/baby_registration/onboarding_flow.dart';
import 'package:yuktoe/onboarding/view_models/baby_registration_view_model.dart';
import 'package:yuktoe/routing/router.dart';

class BabyRegistrationView extends StatefulWidget {
  const BabyRegistrationView({super.key});

  @override
  State<BabyRegistrationView> createState() => _BabyRegistrationViewState();
}

class _BabyRegistrationViewState extends State<BabyRegistrationView> {
  final _viewModel = BabyRegistrationViewModel();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          '우리 아기 등록',
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
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildNameField(),
                      const SizedBox(height: 24),
                      _buildGenderField(),
                      const SizedBox(height: 24),
                      _buildDateField(
                        label: '생년월일',
                        isRequired: true,
                        value: _viewModel.birthDate,
                        onSelect: _viewModel.setBirthDate,
                      ),
                      const SizedBox(height: 24),
                      _buildDateField(
                        label: '출산 예정일',
                        isRequired: false,
                        value: _viewModel.dueDate,
                        onSelect: _viewModel.setDueDate,
                      ),
                      const SizedBox(height: 32),
                      _buildTermsCheckbox(),
                    ],
                  ),
                ),
              ),
              _buildSubmitButton(),
            ],
          );
        },
      ),
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

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('이름', isRequired: true),
        const SizedBox(height: 8),
        TextField(
          onChanged: _viewModel.setName,
          style: AppTextStyles.body.regular.copyWith(
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: '아기 이름을 입력하세요',
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

  Widget _buildGenderField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('성별', isRequired: true),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _GenderButton(
                label: '남자 아기',
                isSelected: _viewModel.gender == Gender.male,
                onTap: () => _viewModel.setGender(Gender.male),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _GenderButton(
                label: '여자 아기',
                isSelected: _viewModel.gender == Gender.female,
                onTap: () => _viewModel.setGender(Gender.female),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required bool isRequired,
    required DateTime? value,
    required ValueChanged<DateTime> onSelect,
  }) {
    final formattedDate = value != null
        ? '${value.year}.${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')}'
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label, isRequired: isRequired),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showDatePicker(
            context: context,
            currentValue: value,
            onSelect: onSelect,
          ),
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

  void _showDatePicker({
    required BuildContext context,
    required DateTime? currentValue,
    required ValueChanged<DateTime> onSelect,
  }) {
    final now = DateTime.now();
    final initialDate = currentValue ?? now;
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
                      child: const Text('취소'),
                      onPressed: () => context.pop(),
                    ),
                    CupertinoButton(
                      child: const Text('완료'),
                      onPressed: () {
                        onSelect(selectedDate);
                        context.pop();
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

  Widget _buildTermsCheckbox() {
    return GestureDetector(
      onTap: _viewModel.toggleAgreedToTerms,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: _viewModel.agreedToTerms,
              onChanged: (_) => _viewModel.toggleAgreedToTerms(),
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
                    text: '서비스 이용약관',
                    style: AppTextStyles.label.semibold.copyWith(
                      color: AppColors.brandPrimary,
                    ),
                  ),
                  const TextSpan(
                    text: ', ',
                    style: TextStyle(color: Color(0xFF364153)),
                  ),
                  TextSpan(
                    text: '개인정보 처리방침',
                    style: AppTextStyles.label.semibold.copyWith(
                      color: AppColors.brandPrimary,
                    ),
                  ),
                  const TextSpan(
                    text: '에 동의합니다 ',
                    style: TextStyle(color: Color(0xFF364153)),
                  ),
                  const TextSpan(
                    text: '*',
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

  Widget _buildSubmitButton() {
    final isEnabled = _viewModel.isValid;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: GestureDetector(
        onTap: isEnabled
            ? () {
                context.push(
                  AppRoutes.babyProfileSetup,
                  extra: CreateBabyFlow(
                    name: _viewModel.name,
                    gender: _viewModel.gender!,
                    birthDate: _viewModel.birthDate!,
                    dueDate: _viewModel.dueDate,
                  ),
                );
              }
            : null,
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
                '다음으로',
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
