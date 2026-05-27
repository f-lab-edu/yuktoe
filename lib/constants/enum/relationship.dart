enum Relationship {
  mother('mother'),
  father('father'),
  family('family'),
  other('other');

  const Relationship(this.serverValue);
  final String serverValue;
}
