import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/repositories/baby_repository/baby_repository.dart';
import 'package:yuktoe/domain/models/baby/baby_list_item.dart';
import 'package:yuktoe/presentation/common/current_baby_controller.dart';

/// baby 전환 bottom sheet (spec §5.6). 선택 시 [CurrentBabyController.select]
/// 를 호출해 홈 영역들이 재로드되도록 한다.
Future<void> showBabySwitchSheet(BuildContext context) {
  final babyRepo = context.read<BabyRepository>();
  final currentBaby = context.read<CurrentBabyController>();

  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => _BabySwitchSheet(
      babyRepository: babyRepo,
      currentBaby: currentBaby,
    ),
  );
}

class _BabySwitchSheet extends StatelessWidget {
  final BabyRepository babyRepository;
  final CurrentBabyController currentBaby;

  const _BabySwitchSheet({
    required this.babyRepository,
    required this.currentBaby,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<Result<List<BabyListItem>>>(
        future: babyRepository.getMyBabies(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final result = snapshot.data!;
          switch (result) {
            case Ok<List<BabyListItem>>(:final value):
              return _list(context, value);
            case Error<List<BabyListItem>>():
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('아기 목록을 불러오지 못했어요')),
              );
          }
        },
      ),
    );
  }

  Widget _list(BuildContext context, List<BabyListItem> babies) {
    final selectedId = currentBaby.selectedBabyId;
    return ListView(
      shrinkWrap: true,
      children: [
        for (final baby in babies)
          ListTile(
            key: Key('baby_switch_${baby.id}'),
            title: Text(baby.name),
            trailing: baby.id == selectedId
                ? const Icon(Icons.check, color: Colors.deepPurple)
                : null,
            onTap: () async {
              await currentBaby.select(baby.id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
      ],
    );
  }
}
