class UserProfile {
  final String username;
  final String displayName;
  final int age;
  final String token;

  const UserProfile({
    required this.username,
    required this.displayName,
    required this.age,
    required this.token,
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        username: j['username'] as String,
        displayName: j['displayName'] as String? ?? j['username'],
        age: (j['age'] as num?)?.toInt() ?? 0,
        token: j['token'] as String? ?? '',
      );
}
