import 'package:yuktoe/constants/enum/relationship.dart';

class RelationshipOption {
  final Relationship value;
  final String emoji;
  final String label;

  const RelationshipOption({
    required this.value,
    required this.emoji,
    required this.label,
  });
}
