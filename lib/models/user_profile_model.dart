class UserProfile {
  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    this.photoSource,
  });

  final String uid;
  final String name;
  final String email;
  final String? photoSource;
}
