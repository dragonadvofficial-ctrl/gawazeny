import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../profile/presentation/widgets/report_user_sheet.dart';
import '../../domain/scored_profile.dart';

/// Modal bottom sheet displaying complete matrimonial biodata and values for a candidate.
class ProfileDetailsSheet extends ConsumerWidget {
  final ScoredProfile scoredCandidate;
  final VoidCallback onLike;
  final VoidCallback onPass;

  const ProfileDetailsSheet({
    super.key,
    required this.scoredCandidate,
    required this.onLike,
    required this.onPass,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = scoredCandidate.profile;
    final score = scoredCandidate.compatibilityScore;
    final photoUrl = scoredCandidate.primaryPhotoUrl;
    final currentUser = ref.watch(currentUserProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.offWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          ),
          child: Column(
            children: [
              // Sheet Top Bar (Close, Drag Handle, Report Action)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.textSecondary,
                      tooltip: context.tr('close'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Container(
                      width: 44.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.flag_outlined),
                      color: AppColors.errorRed.withValues(alpha: 0.8),
                      tooltip: context.tr('reportUser'),
                      onPressed: () {
                        ReportUserSheet.show(
                          context,
                          reportedUserId: profile.id,
                          reportedUserName: profile.fullName,
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Content Body
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  children: [
                    // Header Image / Avatar
                    Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 120.r,
                            height: 120.r,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.surfaceWhite,
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.cardShadowColor,
                                  blurRadius: 16,
                                  offset: Offset(0, 6),
                                ),
                              ],
                              border: Border.all(
                                color: AppColors.secondaryPink,
                                width: 2.5,
                              ),
                            ),
                            child: ClipOval(
                              child: photoUrl != null && photoUrl.isNotEmpty
                                  ? Image.network(
                                      photoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Icon(
                                        Icons.person_rounded,
                                        size: 70.sp,
                                        color: AppColors.primaryNavy,
                                      ),
                                    )
                                  : Icon(
                                      Icons.person_rounded,
                                      size: 70.sp,
                                      color: AppColors.primaryNavy,
                                    ),
                            ),
                          ),
                          if (scoredCandidate.isVerified)
                            Container(
                              padding: EdgeInsets.all(4.r),
                              decoration: const BoxDecoration(
                                color: AppColors.surfaceWhite,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.verified_rounded,
                                color: AppColors.successGreen,
                                size: 26.sp,
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: 14.h),

                    // Name, Age & City
                    Text(
                      '${profile.fullName}، ${profile.age ?? 25} ${context.tr('yearsOld')}',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headlineMedium.copyWith(
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${profile.jobTitle ?? context.tr('notSpecified')} • ${profile.residenceCity}، ${profile.nationality}',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium,
                    ),
                    SizedBox(height: 12.h),

                    // Compatibility Banner Badge
                    Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: score != null
                              ? AppColors.lightPink
                              : AppColors.borderSubtle.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(
                          score != null
                              ? '⚡ ${context.tr('compatibility')}: $score%'
                              : (currentUser != null && currentUser.id == profile.id
                                  ? context.tr('myProfile')
                                  : (currentUser != null &&
                                          currentUser.userMetadata?['gender'] ==
                                              profile.gender.toDbValue()
                                      ? '👁️ ${context.tr('browsingOnly')}'
                                      : '⏳ ${context.tr('compatibilityNotCalculated')}')),
                          style: AppTextStyles.labelMedium.copyWith(
                            color: score != null
                                ? AppColors.secondaryPink
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 24.h),

                    // Personal Bio Card
                    if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: EdgeInsets.all(16.r),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('personalBioCard'),
                                style: AppTextStyles.titleMedium,
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                profile.bio!,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                    ],

                    // Specifications Card
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: EdgeInsets.all(16.r),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('specificationsCard'),
                              style: AppTextStyles.titleMedium,
                            ),
                            SizedBox(height: 12.h),
                            _BiodataRow(
                              label: context.tr('maritalStatus'),
                              value: _maritalStatusArabic(context, profile.maritalStatus),
                            ),
                            if (profile.educationLevel != null)
                              _BiodataRow(
                                label: context.tr('educationLevel'),
                                value: profile.educationLevel!,
                              ),
                            if (profile.heightCm != null)
                              _BiodataRow(
                                label: context.isArabic ? 'الطول' : 'Height',
                                value: '${profile.heightCm} سم',
                              ),
                            if (profile.weightKg != null)
                              _BiodataRow(
                                label: context.isArabic ? 'الوزن التقريبي' : 'Weight',
                                value: '${profile.weightKg} كجم',
                              ),
                            _BiodataRow(
                              label: context.isArabic ? 'الالتزام بالصلاة' : 'Prayer Commitment',
                              value: profile.prays ?? (context.isArabic ? 'محافظ على الصلاة' : 'Regular in prayer'),
                            ),
                            _BiodataRow(
                              label: context.isArabic ? 'التدخين' : 'Smoking',
                              value: profile.smoker
                                  ? context.tr('smokerYesFull')
                                  : context.tr('smokerNever'),
                            ),
                            _BiodataRow(
                              label: context.isArabic ? 'الرغبة في الإنجاب' : 'Wants Children',
                              value: profile.wantsChildren
                                  ? context.tr('wantsChildrenYes')
                                  : context.tr('wantsChildrenNo'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Verification Status Card
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: EdgeInsets.all(16.r),
                        child: Row(
                          children: [
                            Icon(
                              scoredCandidate.isVerified
                                  ? Icons.verified_user_rounded
                                  : Icons.shield_outlined,
                              color: scoredCandidate.isVerified
                                  ? AppColors.successGreen
                                  : AppColors.textSecondary,
                              size: 28.sp,
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr('verificationStatusRow'),
                                    style: AppTextStyles.labelMedium,
                                  ),
                                  Text(
                                    scoredCandidate.isVerified
                                        ? context.tr('verificationFullDetail')
                                        : context.tr('verificationUnderway'),
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: scoredCandidate.isVerified
                                          ? AppColors.successGreen
                                          : AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 32.h),
                  ],
                ),
              ),

              // Bottom Actions (Pass & Serious Like)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 20.w,
                  vertical: 14.h,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceWhite,
                  border: Border(
                    top: BorderSide(
                      color: AppColors.borderSubtle,
                      width: 1.0,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.borderSubtle),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          onPass();
                        },
                        icon: const Icon(Icons.close_rounded),
                        label: Text(context.tr('pass')),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: scoredCandidate.isLiked
                              ? AppColors.textSecondary
                              : AppColors.secondaryPink,
                        ),
                        onPressed: scoredCandidate.isLiked
                            ? null
                            : () {
                                Navigator.of(context).pop();
                                onLike();
                              },
                        icon: Icon(
                          scoredCandidate.isMatched
                              ? Icons.favorite_rounded
                              : (scoredCandidate.isLiked
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.favorite_rounded),
                          color: AppColors.surfaceWhite,
                        ),
                        label: Text(
                          scoredCandidate.isMatched
                              ? context.tr('alreadyMatched')
                              : (scoredCandidate.isLiked
                                  ? context.tr('alreadyLiked')
                                  : context.tr('seriousLike')),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _maritalStatusArabic(BuildContext context, MaritalStatusType status) {
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

class _BiodataRow extends StatelessWidget {
  final String label;
  final String value;

  const _BiodataRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.primaryNavy,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
