class TokenPair {
  const TokenPair({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

class GoogleLoginResult {
  const GoogleLoginResult({
    required this.tokens,
    required this.isNewUser,
    this.googleDisplayName,
    this.googleProfileImageUrl,
  });

  final TokenPair tokens;
  final bool isNewUser;

  /// Only present when [isNewUser] is true - prefill values for the
  /// create-profile screen, straight from the Google account. Never
  /// persisted directly; the user must confirm/edit them before they're
  /// saved to the backend.
  final String? googleDisplayName;
  final String? googleProfileImageUrl;
}

/// Mirrors the backend's UserResponse DTO (pkg/dto/user.go) field-for-field.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.username,
    required this.profileImageUrl,
    required this.googleUserId,
    required this.rating,
    required this.ratingCount,
    required this.onTimeCount,
    required this.lateCount,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      username: json['username'] as String? ?? '',
      profileImageUrl: json['profileImageUrl'] as String,
      googleUserId: json['googleUserId'] as String,
      rating: (json['rating'] as num).toDouble(),
      ratingCount: json['ratingCount'] as int,
      onTimeCount: json['onTimeCount'] as int,
      lateCount: json['lateCount'] as int,
    );
  }

  final String id;
  final String displayName;
  final String username;
  final String profileImageUrl;
  final String googleUserId;
  final double rating;
  final int ratingCount;
  final int onTimeCount;
  final int lateCount;
}
