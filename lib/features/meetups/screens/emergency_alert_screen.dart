import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

/// Full-screen "your friend answered not okay" alert, shown to every other
/// party member (never the member who answered) once a check-in response
/// comes back [CheckInStatus.notOk] - see `CheckInAlertScreen` for the other
/// side of that flow.
///
/// Pushed imperatively onto the app's root [Navigator] by
/// `NudgeMessagingCoordinator`, same as [NudgeAlertScreen]/
/// [CheckInAlertScreen] - see [NudgeAlertScreen]'s doc comment for why.
class EmergencyAlertScreen extends StatefulWidget {
  const EmergencyAlertScreen({
    super.key,
    required this.fromDisplayName,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
  });

  /// Display name of the member who answered "not okay".
  final String fromDisplayName;

  /// That member's emergency contact, when they've set one - see
  /// `entity.User.EmergencyContactName`'s doc comment on the backend. Either
  /// can be empty.
  final String emergencyContactName;
  final String emergencyContactPhone;

  @override
  State<EmergencyAlertScreen> createState() => _EmergencyAlertScreenState();
}

class _EmergencyAlertScreenState extends State<EmergencyAlertScreen> {
  final _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _startLoopingSound();
  }

  Future<void> _startLoopingSound() async {
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('sounds/nudge_alert.mp3'));
    } catch (e) {
      debugPrint('[emergency] failed to play alert sound (asset likely missing): $e');
    }
  }

  Future<void> _dismiss() async {
    try {
      await _player.stop();
    } catch (_) {
      // Best-effort - still dismiss even if the player is already stopped.
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: widget.emergencyContactPhone);
    try {
      await launchUrl(uri);
    } catch (e) {
      debugPrint('[emergency] failed to launch dialer: $e');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPhone = widget.emergencyContactPhone.trim().isNotEmpty;
    final contactLabel = widget.emergencyContactName.trim().isNotEmpty
        ? widget.emergencyContactName
        : 'ไม่ได้ตั้งชื่อผู้ติดต่อ';

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
                    const Icon(Icons.warning_amber_rounded, size: 96, color: AppColors.textPrimary),
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      '${widget.fromDisplayName} ตอบว่าไม่โอเค!',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.displayLg.copyWith(fontSize: 28, height: 1.3),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      hasPhone
                          ? 'ติดต่อผู้ติดต่อฉุกเฉินของเพื่อนได้เลย'
                          : 'เพื่อนยังไม่ได้ตั้งค่าเบอร์ติดต่อฉุกเฉิน',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMd,
                    ),
                    if (hasPhone) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        contactLabel,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        widget.emergencyContactPhone,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.displayLg.copyWith(fontSize: 24),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xxl * 2),
                    if (hasPhone)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _call,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.bgSurface,
                            foregroundColor: AppColors.textPrimary,
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                            shape: const StadiumBorder(),
                          ),
                          icon: const Icon(Icons.call),
                          label: const Text('โทรหาผู้ติดต่อฉุกเฉิน'),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _dismiss,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.textPrimary),
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('ปิด'),
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
