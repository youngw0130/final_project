class AuthResponse {
  final String token;
  final int userId;
  final String username;
  final int linkScore;

  AuthResponse({
    required this.token,
    required this.userId,
    required this.username,
    required this.linkScore,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        token: json['token'] as String,
        userId: json['userId'] as int,
        username: json['username'] as String,
        linkScore: json['linkScore'] as int,
      );
}
