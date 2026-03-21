class AppUser {
  final String id;
  final String? email;
  final String? name;

  const AppUser({
    required this.id,
    this.email,
    this.name,
  });
}