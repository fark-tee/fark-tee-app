import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import '../api/api_client.dart';
import '../config/app_config.dart';
import 'auth_models.dart';

/// Pure data layer for auth: talks to the backend and to the OS-level OAuth
/// browser session. Holds no app state of its own.
class AuthRepository {
  AuthRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<GoogleLoginResult> loginWithGoogle() async {
    final startUrl = Uri.parse(
      '${AppConfig.apiBaseUrl}/v1/auth/google/start',
    ).replace(queryParameters: {'redirect_uri': AppConfig.callbackUri});

    final callback = await FlutterWebAuth2.authenticate(
      url: startUrl.toString(),
      callbackUrlScheme: AppConfig.deeplinkScheme,
    );

    final params = Uri.parse(callback).queryParameters;

    return GoogleLoginResult(
      tokens: TokenPair(
        accessToken: params['accessToken']!,
        refreshToken: params['refreshToken']!,
      ),
      isNewUser: params['isNewUser'] == 'true',
      // Only sent by the backend when isNewUser=true.
      googleDisplayName: params['name'],
      googleProfileImageUrl: params['profileImageUrl'],
    );
  }

  Future<UserProfile> getMe() async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>('/v1/me');
    return UserProfile.fromJson(response.data!);
  }

  Future<UserProfile> updateProfile({
    required String displayName,
    required String username,
    String emergencyContactName = '',
    String emergencyContactPhone = '',
  }) async {
    final response = await _apiClient.dio.patch<Map<String, dynamic>>(
      '/v1/me',
      data: {
        'displayName': displayName,
        'username': username,
        'emergencyContactName': emergencyContactName,
        'emergencyContactPhone': emergencyContactPhone,
      },
    );
    return UserProfile.fromJson(response.data!);
  }

  /// Uploads the given image file as the user's profile picture. There is no
  /// way to set the profile image via a plain URL - the backend only
  /// accepts the raw bytes through this multipart endpoint.
  Future<UserProfile> uploadProfileImage(File imageFile) async {
    final filename = Uri.file(imageFile.path).pathSegments.last;
    final mimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';

    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/v1/me/profile-image',
      data: FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: filename,
          contentType: MediaType.parse(mimeType),
        ),
      }),
    );
    return UserProfile.fromJson(response.data!);
  }
}
