import 'package:yuktoe/constants/enum/gender.dart';

class Baby {
  final String id;
  final String name;
  final DateTime? birthDate;
  final DateTime? dueDate;
  final Gender gender;

  Baby({
    required this.id,
    required this.name,
    this.birthDate,
    this.dueDate,
    required this.gender,
  }) : assert(id.trim().isNotEmpty, 'id must not be blank'),
       assert(name.trim().isNotEmpty, 'name must not be blank'),
       assert(
         birthDate == null || birthDate.isUtc,
         'birthDate must be UTC',
       ),
       assert(dueDate == null || dueDate.isUtc, 'dueDate must be UTC');

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Baby && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
