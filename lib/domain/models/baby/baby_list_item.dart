class BabyListItem {
  final String id;
  final String name;

  BabyListItem({required this.id, required this.name})
    : assert(id.trim().isNotEmpty, 'id must not be blank'),
      assert(name.trim().isNotEmpty, 'name must not be blank');

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is BabyListItem && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
