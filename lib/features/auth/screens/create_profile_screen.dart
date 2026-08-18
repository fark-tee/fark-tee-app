import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../auth_controller.dart';

final _usernamePattern = RegExp(r'^[a-zA-Z0-9_]+$');

/// Step 2: confirm/edit the profile prefilled from the Google account, plus
/// choose a username. Tapping the avatar picks a new photo from the
/// gallery; otherwise the Google photo shown as the default is downloaded
/// and uploaded automatically on submit (see [_submit]).
class CreateProfileScreen extends StatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  bool _saving = false;

  /// Set only if the user picks their own photo from the gallery. When null,
  /// [_submit] falls back to downloading the Google photo itself.
  File? _pickedImage;

  @override
  void initState() {
    super.initState();
    final authController = context.read<AuthController>();
    _nameController = TextEditingController(
      text: authController.pendingDisplayName ?? authController.user?.displayName ?? '',
    );
    // Google doesn't provide a username - the user must type their own.
    _usernameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  String? _validateUsername(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.length < 3 || trimmed.length > 20) {
      return 'ชื่อผู้ใช้ต้องมี 3-20 ตัวอักษร';
    }
    if (!_usernamePattern.hasMatch(trimmed)) {
      return 'ใช้ได้เฉพาะตัวอักษร ตัวเลข และขีดล่างเท่านั้น';
    }
    return context.read<AuthController>().usernameError;
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _pickedImage = File(picked.path));
  }

  /// Downloads the Google photo's bytes into a local temp file, so it can be
  /// uploaded through the same multipart endpoint as any other picked photo
  /// (there's no way to set the profile image by URL).
  Future<File> _downloadGooglePhoto(String url) async {
    final response = await Dio().get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final dir = await getTemporaryDirectory();
    final ext = _guessExtension(url);
    final file = File('${dir.path}/google-profile-photo$ext');
    await file.writeAsBytes(response.data!, flush: true);
    return file;
  }

  String _guessExtension(String url) {
    final path = Uri.parse(url).path;
    final dot = path.lastIndexOf('.');
    if (dot == -1) return '.jpg';
    final ext = path.substring(dot);
    // Google's photo URLs usually have no extension at all (just a size
    // suffix like "=s96-c" after the path) - guard against grabbing a
    // long, bogus "extension" from a path with no real dot-suffix.
    return ext.length <= 5 ? ext : '.jpg';
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final authController = context.read<AuthController>();
    setState(() => _saving = true);

    // Nothing picked - fall back to the Google default, downloading it now
    // so it can be uploaded through the same profile-image endpoint.
    var imageFile = _pickedImage;
    final googlePhotoUrl = authController.pendingProfileImageUrl;
    if (imageFile == null && googlePhotoUrl != null && googlePhotoUrl.isNotEmpty) {
      try {
        imageFile = await _downloadGooglePhoto(googlePhotoUrl);
      } catch (_) {
        // A failed download shouldn't block account creation - continue
        // without a photo; the user can add one later from their profile.
      }
    }

    final success = await authController.completeProfile(
      displayName: _nameController.text,
      username: _usernameController.text.trim(),
      profileImageFile: imageFile,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!success) {
      // Re-run validators so a fresh username-taken error (if any) shows up
      // inline immediately, without requiring another edit first.
      _formKey.currentState?.validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final user = authController.user;
    final googlePhotoUrl = authController.pendingProfileImageUrl;
    final previewUrl = (googlePhotoUrl?.isNotEmpty ?? false)
        ? googlePhotoUrl
        : ((user?.profileImageUrl.isNotEmpty ?? false) ? user!.profileImageUrl : null);

    ImageProvider? avatarImage;
    if (_pickedImage != null) {
      avatarImage = FileImage(_pickedImage!);
    } else if (previewUrl != null) {
      avatarImage = NetworkImage(previewUrl);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('สร้างโปรไฟล์ของคุณ')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundImage: avatarImage,
                        child: avatarImage == null
                            ? const Icon(Icons.person, size: 48)
                            : null,
                      ),
                      const Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          radius: 16,
                          child: Icon(Icons.camera_alt, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อ',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) =>
                      (value?.trim().isEmpty ?? true) ? 'กรุณากรอกชื่อ' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อผู้ใช้',
                    prefixText: '@',
                    border: OutlineInputBorder(),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                  ],
                  textInputAction: TextInputAction.done,
                  validator: _validateUsername,
                  onChanged: (_) => context.read<AuthController>().clearUsernameError(),
                  onFieldSubmitted: (_) => _saving ? null : _submit(),
                ),
                if (authController.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    authController.errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: Text(_saving ? 'กำลังบันทึก...' : 'ดำเนินการต่อ'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
