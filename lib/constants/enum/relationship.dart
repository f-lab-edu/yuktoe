enum Relationship {
  mom('mom'),
  dad('dad'),
  family('family'),
  other('other');

  const Relationship(this.serverValue);
  final String serverValue;
}
