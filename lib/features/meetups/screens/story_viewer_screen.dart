import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/avatar_circle.dart';
import '../models/meetup_member.dart';
import '../models/meetup_story.dart';

/// Full-screen, swipe-through viewer for one member's story photos -
/// Instagram-style progress bar up top, tap-to-close.
class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.member,
    required this.stories,
  });

  final MeetupMember member;
  final List<MeetupStory> stories;

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  final _pageController = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.stories.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => _StoryImage(url: widget.stories[i].imageUrl),
            ),
            Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              child: Row(
                children: [
                  for (var i = 0; i < widget.stories.length; i++)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 3,
                        decoration: BoxDecoration(
                          color: i <= _index
                              ? AppColors.textPrimary
                              : AppColors.textPrimary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              top: AppSpacing.lg + 8,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              child: Row(
                children: [
                  AvatarCircle(
                    initials: widget.member.initials,
                    imageUrl: widget.member.profileImageUrl,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      widget.member.displayName,
                      style: AppTextStyles.titleMd,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textPrimary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryImage extends StatelessWidget {
  const _StoryImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final image = url.startsWith('http')
        ? Image.network(url, fit: BoxFit.contain)
        : Image.file(File(url), fit: BoxFit.contain);
    return Center(child: image);
  }
}
