import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/constants/enum/diaper_type.dart';
import 'package:yuktoe/domain/models/record/record_detail_data.dart';
import 'package:yuktoe/presentation/home/models/quick_log_kind.dart';
import 'package:yuktoe/presentation/home/record_type_labels.dart';

/// 일반 카테고리(breast / sleep 제외 7종)의 입력 dialog (spec §5.5).
///
/// 저장 시 [RecordDetailData] 를 반환한다(취소 시 null). 실제 생성 호출과
/// 리스트/최근 요약 반영은 화면이 담당한다(plan §3.1).
Future<RecordDetailData?> showRecordInputDialog({
  required BuildContext context,
  required QuickLogKind type,
  DateTime Function()? now,
}) {
  return showDialog<RecordDetailData>(
    context: context,
    builder: (_) => ChangeNotifierProvider(
      create: (_) => _InputDialogController(type: type, now: now ?? DateTime.now),
      child: const _RecordInputDialog(),
    ),
  );
}

class _InputDialogController extends ChangeNotifier {
  final QuickLogKind type;
  final DateTime Function() now;

  final TextEditingController amount = TextEditingController();
  final TextEditingController leftAmount = TextEditingController();
  final TextEditingController rightAmount = TextEditingController();
  final TextEditingController name = TextEditingController();

  DateTime _occurredAt;
  DiaperType? diaperType;

  _InputDialogController({required this.type, required this.now})
    : _occurredAt = now() {
    amount.addListener(notifyListeners);
    leftAmount.addListener(notifyListeners);
    rightAmount.addListener(notifyListeners);
    name.addListener(notifyListeners);
  }

  DateTime get occurredAt => _occurredAt;

  void setOccurredAt(DateTime value) {
    _occurredAt = value;
    notifyListeners();
  }

  void setDiaperType(DiaperType value) {
    diaperType = value;
    notifyListeners();
  }

  bool get isFuture => _occurredAt.isAfter(now());

  int? _parse(TextEditingController c) {
    final text = c.text.trim();
    if (text.isEmpty) return null;
    final value = int.tryParse(text);
    if (value == null || value < 0) return null;
    return value;
  }

  bool get canSave {
    if (isFuture) return false;
    switch (type) {
      case QuickLogKind.formula:
      case QuickLogKind.pumpingFeed:
      case QuickLogKind.water:
        return _parse(amount) != null;
      case QuickLogKind.pumping:
        final l = leftAmount.text.trim().isEmpty ? null : _parse(leftAmount);
        final r = rightAmount.text.trim().isEmpty ? null : _parse(rightAmount);
        final leftValid = leftAmount.text.trim().isEmpty || l != null;
        final rightValid = rightAmount.text.trim().isEmpty || r != null;
        final anyPresent =
            leftAmount.text.trim().isNotEmpty || rightAmount.text.trim().isNotEmpty;
        return leftValid && rightValid && anyPresent;
      case QuickLogKind.babyFood:
        return _parse(amount) != null;
      case QuickLogKind.snack:
        return true;
      case QuickLogKind.diaper:
        return diaperType != null;
      case QuickLogKind.breast:
      case QuickLogKind.sleep:
        return false; // 스탑워치 타입은 이 dialog 를 쓰지 않음.
    }
  }

  RecordDetailData? build() {
    if (!canSave) return null;
    final at = _occurredAt.toUtc();
    switch (type) {
      case QuickLogKind.formula:
        return FormulaDetail(occurredAt: at, amountMl: _parse(amount)!);
      case QuickLogKind.pumpingFeed:
        return PumpingFeedDetail(occurredAt: at, amountMl: _parse(amount)!);
      case QuickLogKind.water:
        return WaterDetail(occurredAt: at, amountMl: _parse(amount)!);
      case QuickLogKind.pumping:
        return PumpingDetail(
          occurredAt: at,
          leftAmountMl: leftAmount.text.trim().isEmpty ? null : _parse(leftAmount),
          rightAmountMl:
              rightAmount.text.trim().isEmpty ? null : _parse(rightAmount),
        );
      case QuickLogKind.babyFood:
        return BabyFoodDetail(
          occurredAt: at,
          name: name.text.trim(),
          amountMl: _parse(amount)!,
        );
      case QuickLogKind.snack:
        return SnackDetail(occurredAt: at, name: name.text.trim());
      case QuickLogKind.diaper:
        return DiaperDetail(occurredAt: at, diaperType: diaperType!);
      case QuickLogKind.breast:
      case QuickLogKind.sleep:
        return null;
    }
  }

  @override
  void dispose() {
    amount.dispose();
    leftAmount.dispose();
    rightAmount.dispose();
    name.dispose();
    super.dispose();
  }
}

class _RecordInputDialog extends StatelessWidget {
  const _RecordInputDialog();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<_InputDialogController>();
    final timeText = TimeOfDay.fromDateTime(controller.occurredAt).format(context);

    return AlertDialog(
      title: Text(controller.type.shortLabel),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('시각'),
              const SizedBox(width: 12),
              TextButton(
                key: const Key('input_time_button'),
                onPressed: () => _pickTime(context, controller),
                child: Text(timeText),
              ),
            ],
          ),
          if (controller.isFuture)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                '미래 시각은 저장할 수 없어요',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          const SizedBox(height: 8),
          ..._fields(context, controller),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('input_cancel_button'),
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          key: const Key('input_save_button'),
          onPressed: controller.canSave
              ? () => Navigator.pop(context, controller.build())
              : null,
          child: const Text('저장'),
        ),
      ],
    );
  }

  Future<void> _pickTime(
    BuildContext context,
    _InputDialogController controller,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(controller.occurredAt),
    );
    if (picked == null) return;
    final base = controller.occurredAt;
    var next = DateTime(
      base.year,
      base.month,
      base.day,
      picked.hour,
      picked.minute,
    );
    // 오늘 기준 미래면 어제로 해석 (spec §8.3: 과거 24h 허용).
    if (next.isAfter(controller.now())) {
      next = next.subtract(const Duration(days: 1));
    }
    controller.setOccurredAt(next);
  }

  List<Widget> _fields(BuildContext context, _InputDialogController c) {
    switch (c.type) {
      case QuickLogKind.formula:
      case QuickLogKind.pumpingFeed:
      case QuickLogKind.water:
        return [_amountField(c.amount, '용량 (ml)')];
      case QuickLogKind.pumping:
        return [
          _amountField(c.leftAmount, '왼쪽 (ml)'),
          const SizedBox(height: 8),
          _amountField(c.rightAmount, '오른쪽 (ml)'),
        ];
      case QuickLogKind.babyFood:
        return [
          _textField(c.name, '이름 (선택)'),
          const SizedBox(height: 8),
          _amountField(c.amount, '용량 (ml)'),
        ];
      case QuickLogKind.snack:
        return [_textField(c.name, '이름 (선택)')];
      case QuickLogKind.diaper:
        return [_diaperSelector(c)];
      case QuickLogKind.breast:
      case QuickLogKind.sleep:
        return const [];
    }
  }

  Widget _amountField(TextEditingController controller, String label) {
    return TextField(
      key: Key('input_field_${label.hashCode}'),
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _textField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      maxLength: 30,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _diaperSelector(_InputDialogController c) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final entry in const {
          DiaperType.pee: '소변',
          DiaperType.poop: '대변',
          DiaperType.mixed: '혼합',
        }.entries)
          ChoiceChip(
            label: Text(entry.value),
            selected: c.diaperType == entry.key,
            onSelected: (_) => c.setDiaperType(entry.key),
          ),
      ],
    );
  }
}
