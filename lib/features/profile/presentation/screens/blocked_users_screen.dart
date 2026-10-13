import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/theme/text_styles.dart';
import '../../domain/blocked_user_model.dart';
import '../profile_controller.dart';

/// Screen displaying the list of blocked users with unblock actions and empty state.
class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileControllerProvider.notifier).loadBlockedUsers();
    });
  }

  void _confirmUnblock(BlockedUserModel user) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Text(
          context.tr('unblockUserTitle'),
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          context.isArabic
              ? 'هل أنت متأكد من إلغاء حظر "${user.fullName}"؟ سيتمكن مجدداً من الظهور في نتائج البحث والتوافقات.'
              : 'Are you sure you want to unblock "${user.fullName}"? They will be able to appear in your matches and search results.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondaryPink,
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final success = await ref
                  .read(profileControllerProvider.notifier)
                  .unblockUser(user.blockedUserId);
              if (!mounted) return;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.isArabic
                          ? 'تم إلغاء حظر ${user.fullName} بنجاح'
                          : '${user.fullName} unblocked successfully',
                    ),
                    backgroundColor: AppColors.successGreen,
                  ),
                );
              }
            },
            child: Text(context.isArabic ? 'إلغاء الحظر' : 'Unblock'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: Text(context.tr('blockedUsersTitle')),
        centerTitle: true,
      ),
      body: SafeArea(
        child: state.isLoadingBlocked
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.secondaryPink,
                ),
              )
            : state.blockedUsers.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 16.h,
                    ),
                    itemCount: state.blockedUsers.length,
                    separatorBuilder: (_, _) => SizedBox(height: 12.h),
                    itemBuilder: (context, index) {
                      final blocked = state.blockedUsers[index];
                      return _buildBlockedUserTile(context, blocked);
                    },
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100.r,
              height: 100.r,
              decoration: const BoxDecoration(
                color: AppColors.lightPink,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.block_outlined,
                size: 52.sp,
                color: AppColors.secondaryPink,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              context.tr('noBlockedUsersYet'),
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryNavy,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              context.isArabic
                  ? 'لم تقم بحظر أي شخص. أي مستخدم تقوم بحظره لن يظهر في نتائج البحث أو يتمكن من مراسلتك وسيظهر هنا.'
                  : 'You haven\'t blocked anyone. Any user you block will not appear in search or be able to message you.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockedUserTile(BuildContext context, BlockedUserModel blocked) {
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadowColor,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26.r,
            backgroundColor: AppColors.lightPink,
            backgroundImage: blocked.photoUrl != null
                ? NetworkImage(blocked.photoUrl!)
                : null,
            child: blocked.photoUrl == null
                ? Icon(
                    Icons.person,
                    color: AppColors.primaryNavy,
                    size: 28.sp,
                  )
                : null,
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  blocked.fullName,
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  blocked.residenceCity,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryNavy,
              side: const BorderSide(color: AppColors.borderSubtle),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            ),
            onPressed: () => _confirmUnblock(blocked),
            child: Text(context.isArabic ? 'إلغاء الحظر' : 'Unblock'),
          ),
        ],
      ),
    );
  }
}
