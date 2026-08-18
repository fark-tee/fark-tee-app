import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/auth/auth_models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/mock_identity.dart';
import '../../../../core/widgets/avatar_circle.dart';
import '../../../../core/widgets/pill_button.dart';
import '../../meetups_controller.dart';

/// Step 3 (final) of the Create Meetup wizard: search for real users by
/// display name/ID and pick who to invite, then submit the draft. On
/// success this replaces the wizard stack with the Meetup Detail screen.
class InviteFriendsStep extends StatefulWidget {
  const InviteFriendsStep({super.key});

  @override
  State<InviteFriendsStep> createState() => _InviteFriendsStepState();
}

class _InviteFriendsStepState extends State<InviteFriendsStep> {
  bool _searching = false;
  bool _submitting = false;
  String _query = '';
  List<UserProfile> _results = [];

  /// Every user ever returned by a search this step, keyed by ID - needed so
  /// a selected user's display info survives the query changing underneath
  /// it (search results aren't a stable list like the old mock friend list
  /// was).
  final Map<String, UserProfile> _knownUsers = {};
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String query) async {
    setState(() => _searching = true);
    final results = await context.read<MeetupsController>().searchUsers(query);
    if (!mounted || _query != query) return;
    for (final user in results) {
      _knownUsers[user.id] = user;
    }
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  Future<void> _submit(Set<String> selectedIds) async {
    final invitedFriends = [
      for (final id in selectedIds)
        if (_knownUsers[id] case final user?)
          (
            id: user.id,
            displayName: user.displayName,
            handle: mockHandleFor(user.displayName),
            initials: initialsFor(user.displayName),
          ),
    ];

    setState(() => _submitting = true);
    final meetup = await context.read<MeetupsController>().submitDraft(
      invitedFriends: invitedFriends,
    );
    if (!mounted) return;
    context.pushReplacement('/meetup/${meetup.id}');
  }

  @override
  Widget build(BuildContext context) {
    final selectedIds = context.watch<MeetupsController>().draftInvitedFriendIds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderSubtle, width: 0.6),
          ),
          child: TextField(
            style: AppTextStyles.bodyMd,
            decoration: InputDecoration(
              hintText: 'ค้นหาด้วยชื่อ...',
              hintStyle: AppTextStyles.bodyMd.copyWith(color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            ),
            onChanged: _onQueryChanged,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('เลือกแล้ว ${selectedIds.length} คน', style: AppTextStyles.captionMd),
        const SizedBox(height: AppSpacing.sm),
        Expanded(child: _buildResults(selectedIds)),
        const SizedBox(height: AppSpacing.lg),
        PillButton(
          label: 'ส่งคำเชิญ ${selectedIds.length} คน',
          loading: _submitting,
          onPressed: selectedIds.isEmpty ? null : () => _submit(selectedIds),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _buildResults(Set<String> selectedIds) {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_query.trim().isEmpty) {
      return Center(
        child: Text('ค้นหาคนที่จะเชิญ', style: AppTextStyles.captionMd),
      );
    }
    if (_results.isEmpty) {
      return Center(child: Text('ไม่พบผู้ใช้', style: AppTextStyles.captionMd));
    }
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final user = _results[index];
        final selected = selectedIds.contains(user.id);
        return InkWell(
          onTap: () => context.read<MeetupsController>().toggleDraftFriend(user.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                AvatarCircle(
                  initials: initialsFor(user.displayName),
                  imageUrl: user.profileImageUrl,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.displayName, style: AppTextStyles.bodyMd),
                      Text(mockHandleFor(user.displayName), style: AppTextStyles.captionMd),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? AppColors.accentDanger : AppColors.borderMuted,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
