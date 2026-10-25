import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../profile/domain/user_profile.dart';
import '../../domain/scored_profile.dart';

/// Matrimonial candidate card designed for the "Discover Members" directory.
class DiscoverMemberCard extends StatelessWidget {
  final ScoredProfile candidate;
  final VoidCallback onTapDetails;
  final VoidCallback onLike;
  final GenderType? currentUserGender;

  const DiscoverMemberCard({
    super.key,
    required this.candidate,
    required this.onTapDetails,
    required this.onLike,
    this.currentUserGender,
  });

  @override
  Widget build(BuildContext context) {
    final profile = candidate.profile;
    final photoUrl = candidate.primaryPhotoUrl ?? profile.photoUrl;
    final isSameGender = currentUserGender != null && currentUserGender == profile.gender;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: candidate.isMatched
              ? AppColors.secondaryPink.withValues(alpha: 0.5)
              : AppColors.borderSubtle,
          width: candidate.isMatched ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadowColor,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTapDetails,
        child: Padding(
          padding: EdgeInsets.all(16.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Avatar, Identity info, and Verification/Compatibility Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Photo / Avatar
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 72.r,
                        height: 72.r,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.lightPink.withValues(alpha: 0.3),
                          border: Border.all(
                            color: AppColors.secondaryPink.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: ClipOval(
                          child: photoUrl != null && photoUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: photoUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.secondaryPink,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Icon(
                                    Icons.person_rounded,
                                    size: 40.sp,
                                    color: AppColors.primaryNavy.withValues(alpha: 0.4),
                                  ),
                                )
                              : Icon(
                                  Icons.person_rounded,
                                  size: 40.sp,
                                  color: AppColors.primaryNavy.withValues(alpha: 0.4),
                                ),
                        ),
                      ),
                      if (candidate.isVerified)
                        Container(
                          padding: EdgeInsets.all(2.r),
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceWhite,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.verified_rounded,
                            color: AppColors.successGreen,
                            size: 18.sp,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(width: 14.w),

                  // Name, Age, Job, City
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${profile.fullName}، ${profile.age ?? 25} ${context.tr('yearsOld')}',
                                style: AppTextStyles.titleMedium.copyWith(
                                  color: AppColors.primaryNavy,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          '${profile.jobTitle ?? context.tr('notSpecified')} • ${profile.residenceCity}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 8.h),

                        // Badges Row (Compatibility badge + Matched status)
                        Wrap(
                          spacing: 6.w,
                          runSpacing: 4.h,
                          children: [
                            // 1. Compatibility Badge
                            _buildCompatibilityBadge(context, isSameGender),

                            // 2. Verified ID Pill
                            if (candidate.isVerified)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 3.h,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.successGreen.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                child: Text(
                                  context.tr('verifiedIdChip'),
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.successGreen,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10.sp,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),

              // Matrimonial Specification Chips
              Wrap(
                spacing: 6.w,
                runSpacing: 6.h,
                children: [
                  _SpecChip(text: _maritalStatusText(context, profile.maritalStatus)),
                  if (profile.educationLevel != null && profile.educationLevel!.isNotEmpty)
                    _SpecChip(text: profile.educationLevel!),
                  if (profile.prays != null && profile.prays!.isNotEmpty)
                    _SpecChip(text: profile.prays!),
                  _SpecChip(
                    text: profile.smoker
                        ? context.tr('smokerYes')
                        : context.tr('smokerNo'),
                  ),
                ],
              ),

              // Short Bio excerpt
              if (profile.bio != null && profile.bio!.trim().isNotEmpty) ...[
                SizedBox(height: 10.h),
                Text(
                  profile.bio!.trim(),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              SizedBox(height: 14.h),

              // Bottom Action Buttons: [ View Details | Like ]
              Row(
                children: [
                  // View Details Button
                  Expanded(
                    flex: 1,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 10.h),
                        foregroundColor: AppColors.primaryNavy,
                        side: const BorderSide(color: AppColors.borderSubtle),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      onPressed: onTapDetails,
                      icon: Icon(
                        Icons.visibility_outlined,
                        size: 16.sp,
                        color: AppColors.primaryNavy,
                      ),
                      label: Text(
                        context.tr('viewProfile'),
                        style: AppTextStyles.labelSmall.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),

                  // Like Button
                  Expanded(
                    flex: 1,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 10.h),
                        backgroundColor: candidate.isMatched
                            ? AppColors.primaryNavy
                            : (candidate.isLiked
                                ? AppColors.textSecondary
                                : AppColors.secondaryPink),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      onPressed: candidate.isLiked ? null : onLike,
                      icon: Icon(
                        candidate.isMatched
                            ? Icons.favorite_rounded
                            : (candidate.isLiked
                                ? Icons.check_circle_rounded
                                : Icons.favorite_rounded),
                        size: 16.sp,
                        color: AppColors.surfaceWhite,
                      ),
                      label: Text(
                        candidate.isMatched
                            ? context.tr('alreadyMatched')
                            : (candidate.isLiked
                                ? context.tr('alreadyLiked')
                                : context.tr('sendLike')),
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.surfaceWhite,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompatibilityBadge(BuildContext context, bool isSameGender) {
    if (candidate.compatibilityScore != null) {
      final score = candidate.compatibilityScore!;
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
        decoration: BoxDecoration(
          color: AppColors.lightPink,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bolt_rounded,
              color: AppColors.secondaryPink,
              size: 14.sp,
            ),
            SizedBox(width: 3.w),
            Text(
              '$score% ${context.tr('compatibility')}',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.secondaryPink,
                fontWeight: FontWeight.bold,
                fontSize: 10.sp,
              ),
            ),
          ],
        ),
      );
    } else if (isSameGender) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
        decoration: BoxDecoration(
          color: AppColors.borderSubtle.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Text(
          context.tr('browsingOnly'),
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 10.sp,
          ),
        ),
      );
    } else {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
        decoration: BoxDecoration(
          color: AppColors.borderSubtle.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Text(
          context.tr('compatibilityNotCalculated'),
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 10.sp,
          ),
        ),
      );
    }
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

class _SpecChip extends StatelessWidget {
  final String text;

  const _SpecChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        text,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.primaryNavy.withValues(alpha: 0.8),
          fontSize: 10.sp,
        ),
      ),
    );
  }
}
