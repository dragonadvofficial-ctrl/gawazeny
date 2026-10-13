import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/network/supabase_client.dart';
import '../../likes_matches/presentation/widgets/match_success_dialog.dart';
import '../../profile/domain/user_profile.dart';
import '../domain/scored_profile.dart';
import 'matching_controller.dart';
import 'widgets/profile_details_sheet.dart';
import 'widgets/search_filter_sheet.dart';

/// Discovery feed displaying candidate partner profiles prioritized by the 3-Tier Recommendation Engine.
class MatchingScreen extends ConsumerWidget {
  const MatchingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matchingControllerProvider);
    final controller = ref.read(matchingControllerProvider.notifier);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: Text(
          context.tr('appName'),
          style: AppTextStyles.titleLarge.copyWith(
            color: AppColors.primaryNavy,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: context.tr('refreshMatches'),
          onPressed: controller.loadRecommendations,
        ),
        actions: [
          // Filter Button with Active Filter Count Badge
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: context.tr('filterAndSearchTooltip'),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => SearchFilterSheet(
                      initialFilters: state.filters,
                      onApply: controller.applyFilters,
                    ),
                  );
                },
              ),
              if (state.filters.activeFiltersCount > 0)
                Positioned(
                  top: 8.h,
                  right: 8.w,
                  child: Container(
                    padding: EdgeInsets.all(4.r),
                    decoration: const BoxDecoration(
                      color: AppColors.secondaryPink,
                      shape: BoxShape.circle,
                    ),
                    constraints: BoxConstraints(
                      minWidth: 16.r,
                      minHeight: 16.r,
                    ),
                    child: Center(
                      child: Text(
                        '${state.filters.activeFiltersCount}',
                        style: TextStyle(
                          color: AppColors.surfaceWhite,
                          fontSize: 9.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            // 1. Loading State
            if (state.isLoading) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 36.r,
                      height: 36.r,
                      child: const CircularProgressIndicator(
                        strokeWidth: 3.0,
                        color: AppColors.secondaryPink,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      context.tr('calculatingMatches'),
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                ),
              );
            }

            // 2. Error State
            if (state.errorMessage != null && state.profiles.isEmpty) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 64.sp,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        state.errorMessage!,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium,
                      ),
                      SizedBox(height: 20.h),
                      ElevatedButton(
                        onPressed: controller.loadRecommendations,
                        child: Text(context.tr('retry')),
                      ),
                    ],
                  ),
                ),
              );
            }

            // 3. Empty State (No Candidates Left)
            if (!state.hasMoreCandidates) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(24.r),
                        decoration: BoxDecoration(
                          color: AppColors.lightPink,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.favorite_border_rounded,
                          size: 60.sp,
                          color: AppColors.secondaryPink,
                        ),
                      ),
                      SizedBox(height: 24.h),
                      Text(
                        context.tr('noMoreProfiles'),
                        style: AppTextStyles.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        context.tr('noMoreProfilesSub'),
                        style: AppTextStyles.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 28.h),
                      ElevatedButton.icon(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => SearchFilterSheet(
                              initialFilters: state.filters,
                              onApply: controller.applyFilters,
                            ),
                          );
                        },
                        icon: const Icon(Icons.tune_rounded),
                        label: Text(context.tr('modifySearchCriteria')),
                      ),
                      SizedBox(height: 12.h),
                      TextButton(
                        onPressed: controller.resetFilters,
                        child: Text(context.tr('resetAllFilters')),
                      ),
                    ],
                  ),
                ),
              );
            }

            // 4. Candidate Discovery Card Stack
            final candidate = state.currentCandidate!;

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Column(
                children: [
                  Expanded(
                    child: _CandidateDiscoveryCard(
                      candidate: candidate,
                      onTapDetails: () => _openDetailsSheet(context, candidate, controller),
                    ),
                  ),
                  SizedBox(height: 14.h),

                  // Action Buttons (Dislike, Details, Like)
                  _MatchingActionBar(
                    onPass: controller.swipeLeft,
                    onOpenDetails: () => _openDetailsSheet(context, candidate, controller),
                    onLike: () async {
                      if (user == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(AppStrings.errorAuthRequired),
                            backgroundColor: AppColors.errorRed,
                          ),
                        );
                        return;
                      }
                      final targetProfile = candidate.profile;
                      final targetPhoto = candidate.primaryPhotoUrl;
                      final result = await controller.swipeRight();
                      if (result != null && result.isMatch && context.mounted) {
                        MatchSuccessDialog.show(
                          context,
                          partnerProfile: targetProfile,
                          partnerPhotoUrl: targetPhoto,
                        );
                      }
                    },
                  ),
                  SizedBox(height: 10.h),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _openDetailsSheet(
    BuildContext context,
    ScoredProfile candidate,
    MatchingController controller,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProfileDetailsSheet(
        scoredCandidate: candidate,
        onPass: controller.swipeLeft,
        onLike: () async {
          Navigator.of(context).pop();
          final targetProfile = candidate.profile;
          final targetPhoto = candidate.primaryPhotoUrl;
          final result = await controller.swipeRight();
          if (result != null && result.isMatch && context.mounted) {
            MatchSuccessDialog.show(
              context,
              partnerProfile: targetProfile,
              partnerPhotoUrl: targetPhoto,
            );
          }
        },
      ),
    );
  }
}

/// Floating matrimonial candidate card with 28px rounded corners and glassmorphism compatibility badge.
class _CandidateDiscoveryCard extends StatelessWidget {
  final ScoredProfile candidate;
  final VoidCallback onTapDetails;

  const _CandidateDiscoveryCard({
    required this.candidate,
    required this.onTapDetails,
  });

  @override
  Widget build(BuildContext context) {
    final profile = candidate.profile;
    final photoUrl = candidate.primaryPhotoUrl;

    return GestureDetector(
      onTap: onTapDetails,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28.r),
          color: AppColors.surfaceWhite,
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadowColor,
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image or Placeholder
            if (photoUrl != null && photoUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: photoUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppColors.lightPink.withValues(alpha: 0.3),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.secondaryPink,
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => _buildPlaceholderBackground(),
              )
            else
              _buildPlaceholderBackground(),

            // Top Badges (Floating Compatibility Badge & Identity Verification)
            Positioned(
              top: 18.h,
              right: 18.w,
              left: 18.w,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Glassmorphism Compatibility Score Badge
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWhite.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.cardShadowColor,
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          color: AppColors.secondaryPink,
                          size: 18.sp,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          '${candidate.compatibilityScore}% ${context.tr('compatibility')}',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.primaryNavy,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Verification Badge
                  if (candidate.isVerified)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(20.r),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.cardShadowColor,
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            color: AppColors.successGreen,
                            size: 16.sp,
                          ),
                          SizedBox(width: 5.w),
                          Text(
                            context.tr('verifiedIdChip'),
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.primaryNavy,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Bottom Profile Information Scrim Overlay
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.all(22.r),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppColors.primaryNavy.withValues(alpha: 0.8),
                      AppColors.primaryNavy.withValues(alpha: 0.98),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Name & Age
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${profile.fullName}، ${profile.age ?? 25} ${context.tr('yearsOld')}',
                            style: AppTextStyles.headlineLarge.copyWith(
                              color: AppColors.surfaceWhite,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.surfaceWhite.withValues(alpha: 0.8),
                          size: 22.sp,
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),

                    // Job & City
                    Text(
                      '${profile.jobTitle ?? context.tr('notSpecified')} • ${profile.residenceCity}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.surfaceWhite.withValues(alpha: 0.9),
                      ),
                    ),
                    SizedBox(height: 12.h),

                    // Quick Matrimonial Attribute Chips
                    Wrap(
                      spacing: 6.w,
                      runSpacing: 6.h,
                      children: [
                        _QuickChip(text: _maritalStatusText(context, profile.maritalStatus)),
                        if (profile.educationLevel != null)
                          _QuickChip(text: profile.educationLevel!),
                        if (profile.prays != null)
                          _QuickChip(text: profile.prays!),
                        _QuickChip(
                          text: profile.smoker
                              ? context.tr('smokerYes')
                              : context.tr('smokerNo'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE2E8F0), Color(0xFFCBD5E1)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: 130.sp,
          color: AppColors.primaryNavy.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  String _maritalStatusText(BuildContext context, MaritalStatusType status) {
    switch (status) {
      case MaritalStatusType.single:
        return context.tr('single');
      case MaritalStatusType.divorced:
        return context.tr('divorced');
      case MaritalStatusType.widowed:
        return context.tr('widowed');
    }
  }
}

class _QuickChip extends StatelessWidget {
  final String text;

  const _QuickChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        text,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.surfaceWhite,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Action bar with Dislike (Skip), View Profile Details, and Like buttons.
class _MatchingActionBar extends StatelessWidget {
  final VoidCallback onPass;
  final VoidCallback onOpenDetails;
  final VoidCallback onLike;

  const _MatchingActionBar({
    required this.onPass,
    required this.onOpenDetails,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // 1. Pass / Skip Button
        Container(
          width: 58.r,
          height: 58.r,
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.borderSubtle, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: AppColors.cardShadowColor,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            onPressed: onPass,
            icon: Icon(
              Icons.close_rounded,
              color: AppColors.textSecondary,
              size: 28.sp,
            ),
          ),
        ),

        // 2. View Profile Details Button
        Container(
          width: 50.r,
          height: 50.r,
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.borderSubtle, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: AppColors.cardShadowColor,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            onPressed: onOpenDetails,
            icon: Icon(
              Icons.info_outline_rounded,
              color: AppColors.primaryNavy,
              size: 24.sp,
            ),
          ),
        ),

        // 3. Like Button (Pink Gradient Fill)
        Container(
          width: 68.r,
          height: 68.r,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.pinkGradient,
            boxShadow: [
              BoxShadow(
                color: Color(0x33E94B7A),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: IconButton(
            onPressed: onLike,
            icon: Icon(
              Icons.favorite_rounded,
              color: AppColors.surfaceWhite,
              size: 32.sp,
            ),
          ),
        ),
      ],
    );
  }
}
