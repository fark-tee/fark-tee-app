import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

/// Full-screen, sound-looping "your friend nudged you" alert.
///
/// Pushed imperatively onto the app's root [Navigator] by
/// `NudgeMessagingCoordinator` (foreground FCM message, background-tap, or
/// cold-start check) rather than declared as a go_router route, since it
/// needs to be reachable from raw FCM callbacks that have no
/// `BuildContext`/router state of their own. `Navigator.of(context)` still
/// resolves to the same root navigator go_router itself renders into, so
/// dismissing behaves normally.
class NudgeAlertScreen extends StatefulWidget {
  const NudgeAlertScreen({super.key, required this.fromDisplayName});

  /// Display name of the member who sent the nudge, when known (FCM data
  /// payload). Falls back to a generic Thai placeholder otherwise.
  final String fromDisplayName;

  @override
  State<NudgeAlertScreen> createState() => _NudgeAlertScreenState();
}

class _NudgeAlertScreenState extends State<NudgeAlertScreen> {
  // Mirrors MainActivity.kt's LOCK_SCREEN_CHANNEL - clears the
  // show-when-locked/turn-screen-on flags that were set (Android only) so
  // this alert could wake a locked device like an incoming call. Without
  // this, whatever screen is underneath would stay drawn over a still-locked
  // device after the alert is dismissed.
  static const _lockScreenChannel = MethodChannel(
    'com.balerion.fark_tee_app/nudge_lock_screen',
  );

  final _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _startLoopingSound();
  }

  Future<void> _startLoopingSound() async {
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      // TODO(human): no bundled "fun sound" asset exists in this repo yet -
      // add a real file at assets/sounds/nudge_alert.mp3 (already declared
      // under `flutter: assets:` in pubspec.yaml). Until then this throws
      // and is swallowed below, falling back silently to just the Android
      // notification channel's own sound (see NudgeNotificationService).
      await _player.play(AssetSource('sounds/nudge_alert.mp3'));
    } catch (e) {
      debugPrint('[nudge] failed to play alert sound (asset likely missing): $e');
    }
  }

  Future<void> _dismiss() async {
    try {
      await _player.stop();
    } catch (_) {
      // Best-effort - still dismiss even if the player is already stopped.
    }
    if (Platform.isAndroid) {
      try {
        await _lockScreenChannel.invokeMethod<void>('clearShowWhenLocked');
      } catch (e) {
        debugPrint('[nudge] failed to clear show-when-locked flags: $e');
      }
    }
    if (!mounted) return;
    // canPop is false on the PopScope below, so maybePop() would just be
    // re-blocked and bounce back into onPopInvokedWithResult -> _dismiss()
    // again. pop() bypasses that check and actually closes the route.
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _dismiss();
      },
      child: Scaffold(
        backgroundColor: AppColors.accentDanger,
        body: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/mascots/t.png',
                      width: 160,
                      height: 160,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      'รีบมาได้แล้ว\nเพื่อนตามแล้ว!!',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.displayLg.copyWith(fontSize: 32, height: 1.3),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '${widget.fromDisplayName} กำลังรอคุณอยู่',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMd,
                    ),
                    const SizedBox(height: AppSpacing.xxl * 2),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _dismiss,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.bgSurface,
                          foregroundColor: AppColors.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('โอเค ไปแล้ว!'),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: AppSpacing.md,
                right: AppSpacing.md,
                child: IconButton(
                  onPressed: _dismiss,
                  icon: const Icon(Icons.close, color: AppColors.textPrimary),
                  tooltip: 'ปิด',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
