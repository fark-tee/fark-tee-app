import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/avatar_circle.dart';
import '../../../core/widgets/pill_button.dart';
import '../meetups_controller.dart';
import '../models/meetup_enums.dart';
import '../models/meetup_member.dart';
import '../models/meetup_review.dart';

/// Lets the current user rate the other party members who have already
/// arrived at the venue, once they themselves have arrived too. Pushed from
/// the live meetup screen's "arrived" status card.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.meetupId});

  final String meetupId;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

const _arrivedStatuses = {
  MemberArrivalStatus.arrived,
  MemberArrivalStatus.headingHome,
  MemberArrivalStatus.returned,
};

class _ReviewScreenState extends State<ReviewScreen> {
  bool _loading = true;
  String? _error;
  List<MeetupMember> _reviewableMembers = [];
  final Map<String, MeetupReview> _reviewsByUserId = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final controller = context.read<MeetupsController>();
    try {
      final meetup =
          controller.selectedMeetup ?? await controller.loadMeetup(widget.meetupId);
      final reviews = await controller.fetchMyReviews(widget.meetupId);
      if (!mounted) return;
      setState(() {
        _reviewableMembers = meetup.otherMembers
            .where((m) => _arrivedStatuses.contains(m.arrivalStatus))
            .toList();
        _reviewsByUserId.addAll({for (final r in reviews) r.targetUserId: r});
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'โหลดข้อมูลไม่สำเร็จ กรุณาลองใหม่อีกครั้ง';
        _loading = false;
      });
    }
  }

  void _onReviewed(MeetupReview review) {
    setState(() => _reviewsByUserId[review.targetUserId] = review);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => context.pop(),
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.chevron_left,
                    color: AppColors.textPrimary,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('ให้คะแนนเพื่อนๆ', style: AppTextStyles.displayLg),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'บอกให้เพื่อนรู้ว่าวันนี้เป็นยังไงบ้าง',
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Expanded(child: _buildBody()),
              const SizedBox(height: AppSpacing.md),
              PillButton(label: 'เสร็จแล้ว', onPressed: () => context.pop()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_reviewableMembers.isEmpty) {
      return Center(
        child: Text(
          'ยังไม่มีเพื่อนที่ถึงที่นัดให้ให้คะแนนตอนนี้',
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView(
      children: [
        for (final member in _reviewableMembers) ...[
          _ReviewCard(
            meetupId: widget.meetupId,
            member: member,
            existingReview: _reviewsByUserId[member.userId],
            onReviewed: _onReviewed,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _ReviewCard extends StatefulWidget {
  const _ReviewCard({
    required this.meetupId,
    required this.member,
    required this.existingReview,
    required this.onReviewed,
  });

  final String meetupId;
  final MeetupMember member;
  final MeetupReview? existingReview;
  final void Function(MeetupReview review) onReviewed;

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  int _score = 0;
  final _commentController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final controller = context.read<MeetupsController>();
    final messenger = ScaffoldMessenger.of(context);
    final review = await controller.submitReview(
      widget.meetupId,
      widget.member.userId,
      score: _score,
      comment: _commentController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (review == null) {
      if (controller.errorMessage != null) {
        messenger.showSnackBar(SnackBar(content: Text(controller.errorMessage!)));
      }
      return;
    }
    widget.onReviewed(review);
  }

  @override
  Widget build(BuildContext context) {
    final submitted = widget.existingReview;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarCircle(
                initials: widget.member.initials,
                imageUrl: widget.member.profileImageUrl,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(widget.member.displayName, style: AppTextStyles.bodyMd),
              ),
              _StarRow(
                score: submitted?.score ?? _score,
                enabled: submitted == null && !_submitting,
                onChanged: (score) => setState(() => _score = score),
              ),
            ],
          ),
          if (submitted == null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.borderSubtle, width: 0.6),
              ),
              child: TextField(
                controller: _commentController,
                style: AppTextStyles.bodyMd,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'บอกอะไรเพิ่มเติมไหม (ไม่บังคับ)',
                  hintStyle: AppTextStyles.bodyMd.copyWith(color: AppColors.textMuted),
                  border: InputBorder.none,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            PillButton(
              label: 'ส่งคะแนน',
              loading: _submitting,
              onPressed: _score == 0 ? null : _submit,
            ),
          ] else if (submitted.comment.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              submitted.comment,
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tappable row of 5 stars. Read-only once [enabled] is false, e.g. after a
/// review has already been submitted for this member.
class _StarRow extends StatelessWidget {
  const _StarRow({
    required this.score,
    required this.enabled,
    required this.onChanged,
  });

  final int score;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          GestureDetector(
            onTap: enabled ? () => onChanged(i) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Icon(
                i <= score ? Icons.star : Icons.star_border,
                size: 20,
                color: AppColors.textPrimary,
              ),
            ),
          ),
      ],
    );
  }
}
