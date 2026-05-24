import 'package:yuktoe/constants/enum/record_type.dart';
import 'package:yuktoe/domain/models/record/record_detail_data.dart';

class CareRecord {
  final String id;
  final String babyId;
  final RecordType type;
  final RecordDetailData detail;
  final String createdBy;
  final DateTime createdAt;

  const CareRecord({
    required this.id,
    required this.babyId,
    required this.type,
    required this.detail,
    required this.createdBy,
    required this.createdAt,
  });
}
