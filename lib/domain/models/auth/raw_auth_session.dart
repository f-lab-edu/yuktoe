class RawAuthSession {
  final String userId;
  final String accessToken;
  final String? email;
  final String? name;

  const RawAuthSession({
    required this.userId,
    required this.accessToken,
    this.email,
    this.name,
  });
}
