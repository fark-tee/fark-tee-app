import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_models.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/token_storage.dart';
import 'auth_state.dart';

/// Orchestrates the 2-step auth flow and exposes the app's current auth
/// status to the widget tree.
class AuthController extends ChangeNotifier {
  AuthController({
    required ApiClient apiClient,
    required AuthRepository authRepository,
    required TokenStorage tokenStorage,
  }) : _authRepository = authRepository,
       _tokenStorage = tokenStorage {
    apiClient.onSessionExpired = _handleSessionExpired;
  }

  final AuthRepository _authRepository;
  final TokenStorage _tokenStorage;

  AuthStatus status = AuthStatus.checking;
  UserProfile? user;
  String? errorMessage;

  /// Field-specific error for the create-profile screen's username input
  /// (backend 409 USERNAME_TAKEN), kept separate from [errorMessage] so it
  /// can be surfaced inline rather than as a generic banner.
  String? usernameError;

  /// Prefill values for the create-profile screen, captured from the Google
  /// OAuth callback for brand-new users only. Cleared once the profile is
  /// completed - never persisted, just a one-time prefill.
  String? pendingDisplayName;
  String? pendingProfileImageUrl;

  /// Call once at app startup: resumes a session from stored tokens if any.
  /// Never leaves [status] stuck at `checking` - any failure here (including
  /// the secure storage read itself) falls back to unauthenticated.
  Future<void> bootstrap() async {
    try {
      final refreshToken = await _tokenStorage.readRefreshToken();
      if (refreshToken == null) {
        _update(AuthStatus.unauthenticated);
        return;
      }

      user = await _authRepository.getMe();
      _update(AuthStatus.authenticated);
    } catch (_) {
      try {
        await _tokenStorage.clear();
      } catch (_) {
        // Best-effort - fall through to unauthenticated regardless.
      }
      _update(AuthStatus.unauthenticated);
    }
  }

  Future<void> signInWithGoogle() async {
    errorMessage = null;
    try {
      final result = await _authRepository.loginWithGoogle();
      await _tokenStorage.save(result.tokens);

      // The callback deeplink only carries tokens + isNewUser (+ the Google
      // prefill fields below for new users), not the full profile, so fetch
      // it explicitly for both branches here.
      user = await _authRepository.getMe();

      if (result.isNewUser) {
        pendingDisplayName = result.googleDisplayName;
        pendingProfileImageUrl = result.googleProfileImageUrl;
        _update(AuthStatus.needsProfile);
      } else {
        _update(AuthStatus.authenticated);
      }
    } catch (_) {
      errorMessage = 'การเข้าสู่ระบบถูกยกเลิกหรือไม่สำเร็จ กรุณาลองใหม่อีกครั้ง';
      notifyListeners();
    }
  }

  /// Clears a stale username-taken error once the user edits the field
  /// again, so it doesn't linger after they've changed the value.
  void clearUsernameError() {
    if (usernameError == null) return;
    usernameError = null;
    notifyListeners();
  }

  /// Completes new-user profile setup. If [profileImageFile] is given, it's
  /// uploaded first (POST /me/profile-image) and only then is the
  /// display name/username saved (PATCH /me) - both must succeed before the
  /// user is considered `authenticated`. If no image was picked/confirmed,
  /// nothing is uploaded and no profile image is persisted.
  Future<bool> completeProfile({
    required String displayName,
    required String username,
    File? profileImageFile,
  }) async {
    final trimmedName = displayName.trim();
    final trimmedUsername = username.trim();
    if (trimmedName.isEmpty || trimmedUsername.isEmpty) return false;

    errorMessage = null;
    usernameError = null;

    if (profileImageFile != null) {
      try {
        user = await _authRepository.uploadProfileImage(profileImageFile);
      } on DioException {
        errorMessage = 'อัปโหลดรูปภาพไม่สำเร็จ กรุณาลองใหม่อีกครั้ง';
        notifyListeners();
        return false;
      }
    }

    try {
      user = await _authRepository.updateProfile(
        displayName: trimmedName,
        username: trimmedUsername,
      );
      pendingDisplayName = null;
      pendingProfileImageUrl = null;
      _update(AuthStatus.authenticated);
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        usernameError = 'ชื่อผู้ใช้นี้ถูกใช้ไปแล้ว';
      } else {
        errorMessage = 'บันทึกโปรไฟล์ไม่สำเร็จ กรุณาลองใหม่อีกครั้ง';
      }
      notifyListeners();
      return false;
    }
  }

  /// Re-fetches the current user from GET /me. Used to refresh profile data
  /// (rating, stats, badges) when the profile screen is opened, since
  /// [bootstrap] only runs once at app startup.
  Future<void> refreshUser() async {
    try {
      user = await _authRepository.getMe();
      notifyListeners();
    } catch (_) {
      // Best-effort refresh - keep showing the last known profile.
    }
  }

  Future<void> signOut() async {
    await _tokenStorage.clear();
    user = null;
    pendingDisplayName = null;
    pendingProfileImageUrl = null;
    _update(AuthStatus.unauthenticated);
  }

  void _handleSessionExpired() {
    user = null;
    _update(AuthStatus.unauthenticated);
  }

  void _update(AuthStatus next) {
    status = next;
    notifyListeners();
  }
}
