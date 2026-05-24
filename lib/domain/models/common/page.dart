class Page<T> {
  final List<T> items;
  final String? nextCursor;
  final bool hasMore;

  const Page({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });
}
