import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/preview/preview_config.dart';
import '../../../core/preview/preview_mock_data.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/domain/chat_message.dart';
import '../../chat/presentation/chat_room_screen.dart';
import '../../matching/domain/scored_profile.dart';
import '../../matching/presentation/widgets/profile_details_sheet.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/user_profile.dart';
import '../../profile/presentation/profile_controller.dart';
import '../../verification/presentation/identity_verification_screen.dart';
import '../domain/match_model.dart';
import 'likes_matches_controller.dart';
import 'widgets/match_success_dialog.dart';

/// Screen listing mutual matrimonial matches, received likes, and sent likes.
class MatchesScreen extends ConsumerStatefulWidget {
  const MatchesScreen({super.key});

  @override
  ConsumerState<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends ConsumerState<MatchesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref
            .read(likesMatchesControllerProvider.notifier)
            .setTab(_tabController.index);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(likesMatchesControllerProvider.notifier).loadAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(likesMatchesControllerProvider);
    final controller = ref.read(likesMatchesControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: Text(context.tr('navMatches')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: context.tr('refreshLists'),
            onPressed: controller.loadAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.secondaryPink,
          indicatorWeight: 3.h,
          labelColor: AppColors.primaryNavy,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: AppTextStyles.titleSmall.copyWith(
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: AppTextStyles.titleSmall,
          tabs: [
            _buildTabWithBadge(
              label: context.tr('mutualMatchesTab'),
              count: state.mutualMatches.length,
            ),
            _buildTabWithBadge(
              label: context.tr('receivedLikesTab'),
              count: state.receivedLikes.length,
              highlight: true,
            ),
            _buildTabWithBadge(
              label: context.tr('sentLikesTab'),
              count: state.sentLikes.length,
            ),
          ],
        ),
      ),
      body: state.isLoading &&
              state.mutualMatches.isEmpty &&
              state.receivedLikes.isEmpty &&
              state.sentLikes.isEmpty
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.secondaryPink,
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                // 1. Mutual Matches Tab
                _MutualMatchesList(
                  matches: state.mutualMatches,
                  onRefresh: controller.loadAll,
                  onUnmatch: controller.unmatch,
                ),

                // 2. Received Likes Tab
                _ReceivedLikesList(
                  likes: state.receivedLikes,
                  onRefresh: controller.loadAll,
                  onLikeBack: (like) async {
                    final result = await controller.likeBack(like);
                    if (result != null && context.mounted) {
                      MatchSuccessDialog.show(
                        context,
                        matchId: result.matchId,
                        partnerProfile: like.senderProfile,
                        partnerPhotoUrl: like.primaryPhotoUrl,
                      );
                    }
                  },
                ),

                // 3. Sent Likes Tab
                _SentLikesList(
                  likes: state.sentLikes,
                  onRefresh: controller.loadAll,
                  onCancel: controller.cancelSentLike,
                ),
              ],
            ),
    );
  }

  Widget _buildTabWithBadge({
    required String label,
    required int count,
    bool highlight = false,
  }) {
    return Tab(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label),
            if (count > 0) ...[
              SizedBox(width: 5.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: highlight
                      ? AppColors.secondaryPink
                      : AppColors.primaryNavy.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: highlight ? AppColors.surfaceWhite : AppColors.primaryNavy,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// 1. MUTUAL MATCHES LIST & CARD
// ----------------------------------------------------------------------------
class _MutualMatchesList extends StatelessWidget {
  final List<MutualMatch> matches;
  final Future<void> Function() onRefresh;
  final void Function(MutualMatch) onUnmatch;

  const _MutualMatchesList({
    required this.matches,
    required this.onRefresh,
    required this.onUnmatch,
  });

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return _EmptyState(
        icon: Icons.favorite_border_rounded,
        title: context.tr('noMatches'),
        subtitle: context.isArabic
            ? 'استمر في استكشاف الاقتراحات اليومية لزيادة فرصك في العثور على شريك حياتك.'
            : 'Keep exploring daily recommendations to increase your chances of finding your partner.',
        actionLabel: context.tr('refresh'),
        onAction: onRefresh,
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.secondaryPink,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        itemCount: matches.length,
        itemBuilder: (context, index) {
          final match = matches[index];
          return _MutualMatchCard(
            match: match,
            onUnmatch: () => _confirmUnmatch(context, match),
          );
        },
      ),
    );
  }

  void _confirmUnmatch(BuildContext context, MutualMatch match) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text(
          context.tr('unmatch'),
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.errorRed),
        ),
        content: Text(
          context.isArabic
              ? 'هل أنت متأكد من إنهاء التوافق مع "${match.partnerProfile.fullName}"؟ لن تتمكن من المحادثة بعدها.'
              : 'Are you sure you want to unmatch with "${match.partnerProfile.fullName}"? You will not be able to chat afterwards.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              onUnmatch(match);
            },
            child: Text(context.isArabic ? 'تأكيد الإنهاء' : 'Confirm Unmatch'),
          ),
        ],
      ),
    );
  }
}

class _MutualMatchCard extends ConsumerStatefulWidget {
  final MutualMatch match;
  final VoidCallback onUnmatch;

  const _MutualMatchCard({
    required this.match,
    required this.onUnmatch,
  });

  @override
  ConsumerState<_MutualMatchCard> createState() => _MutualMatchCardState();
}

class _MutualMatchCardState extends ConsumerState<_MutualMatchCard> {
  bool _isOpening = false;

  Future<void> _openChat(BuildContext context) async {
    if (_isOpening) return;
    setState(() => _isOpening = true);

    try {
      final match = widget.match;
      final profile = match.partnerProfile;
      final currentUserAuth = ref.read(currentUserProvider);

      if (currentUserAuth == null && !kPreviewMode) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.isArabic
                    ? 'يجب تسجيل الدخول أولاً'
                    : 'Please login first',
              ),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
        return;
      }

      final currentUid = currentUserAuth?.id ??
          (kPreviewMode ? PreviewMockData.currentUserId : '');

      // 1. Check current user verification status
      var currentProfile = ref.read(currentUserProfileProvider);
      if (currentProfile == null && !kPreviewMode && currentUid.isNotEmpty) {
        try {
          currentProfile = await ref
              .read(profileRepositoryProvider)
              .getProfile(currentUid);
        } catch (_) {}
      }

      final isCurrentUserVerified = kPreviewMode ||
          (currentProfile?.verificationStatus ==
              VerificationStatusType.verified) ||
          (currentUserAuth?.appMetadata['is_verified'] == true);

      if (!isCurrentUserVerified) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.r)),
              title: Row(
                children: [
                  const Icon(Icons.verified_user_outlined,
                      color: AppColors.warningOrange),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      ctx.isArabic
                          ? 'توثيق الهوية مطلوب'
                          : 'Verification Required',
                      style: AppTextStyles.titleMedium
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Text(
                ctx.isArabic
                    ? 'لضمان الجدية والأمان وحماية خصوصية الأعضاء، يُشترط توثيق هويتك الوطنية بالذكاء الاصطناعي قبل بدء المحادثة مع شريك حياتك.'
                    : 'For safety and seriousness, ID verification is required before starting a matrimonial chat.',
                style: AppTextStyles.bodyMedium,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(ctx.tr('cancel')),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondaryPink,
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const IdentityVerificationScreen(),
                      ),
                    );
                  },
                  child: Text(
                    ctx.isArabic ? 'توثيق الهوية الآن' : 'Verify ID Now',
                  ),
                ),
              ],
            ),
          );
        }
        return;
      }

      // 2. Check partner verification status
      final isPartnerVerified =
          profile.verificationStatus == VerificationStatusType.verified;
      if (!isPartnerVerified && !kPreviewMode) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.isArabic
                    ? 'الطرف الآخر لم يُتمم توثيق هويته بعد. المحادثة تتاح فقط بعد توثيق الطرفين لضمان الجدية والأمان.'
                    : 'The partner has not completed identity verification yet.',
              ),
              backgroundColor: AppColors.warningOrange,
            ),
          );
        }
        return;
      }

      // 3. Query backend or preview repository to get or create conversation
      final chatRepo = ref.read(chatRepositoryProvider);
      final authResult = await chatRepo.getOrCreateConversation(
        matchId: match.matchId,
        partnerId: profile.id,
      );

      if (!context.mounted) return;

      if (!authResult.isAllowed || authResult.conversationId == null) {
        final code = authResult.errorCode;
        final msg = authResult.errorMessage ??
            (context.isArabic ? 'تعذر فتح المحادثة' : 'Could not open chat');

        if (code == 'NOT_VERIFIED') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const IdentityVerificationScreen(),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
        return;
      }

      // 4. Construct Conversation object with retrieved conversation_id
      final conversation = Conversation(
        id: authResult.conversationId!,
        matchId: match.matchId,
        userOneId: currentUid,
        userTwoId: profile.id,
        partnerId: profile.id,
        partnerName: profile.fullName,
        partnerPhotoUrl: match.primaryPhotoUrl,
        partnerIsVerified: isPartnerVerified,
        lastMessageAt: DateTime.now(),
        createdAt: match.matchedAt,
      );

      // 5. Navigate directly to the ChatRoomScreen
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(conversation: conversation),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.isArabic
                  ? 'حدث خطأ أثناء فتح المحادثة، يرجى المحاولة لاحقاً'
                  : 'An error occurred while opening chat',
            ),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isOpening = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final profile = match.partnerProfile;
    final isVerified =
        profile.verificationStatus == VerificationStatusType.verified;

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadowColor,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20.r),
          onTap: _isOpening ? null : () => _openChat(context),
          child: Padding(
            padding: EdgeInsets.all(14.r),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar with Verification Indicator
                Stack(
                  children: [
                    Container(
                      width: 68.r,
                      height: 68.r,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.lightPink, width: 2),
                      ),
                      child: ClipOval(
                        child: match.primaryPhotoUrl != null &&
                                match.primaryPhotoUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: match.primaryPhotoUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => Container(
                                  color: AppColors.lightPink,
                                  child: Icon(
                                    Icons.person_rounded,
                                    color: AppColors.secondaryPink,
                                    size: 32.sp,
                                  ),
                                ),
                              )
                            : Container(
                                color: AppColors.lightPink,
                                child: Icon(
                                  Icons.person_rounded,
                                  color: AppColors.secondaryPink,
                                  size: 32.sp,
                                ),
                              ),
                      ),
                    ),
                    if (isVerified)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(3.r),
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceWhite,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.verified_rounded,
                            color: AppColors.successGreen,
                            size: 16.sp,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(width: 14.w),

                // Partner Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              profile.fullName,
                              style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryNavy,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        '${profile.age ?? 25} ${context.tr('yearsOld')} • ${profile.residenceCity}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (profile.jobTitle != null && profile.jobTitle!.isNotEmpty) ...[
                        SizedBox(height: 2.h),
                        Text(
                          profile.jobTitle!,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.primaryNavy.withValues(alpha: 0.8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      SizedBox(height: 6.h),
                      Text(
                        context.isArabic ? 'تم التوافق بنية الزواج 💍' : 'Matched for Marriage 💍',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: AppColors.secondaryPink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),

                // Action Buttons
                Column(
                  children: [
                    // Chat / Verification Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(84.w, 36.h),
                        backgroundColor: AppColors.secondaryPink,
                        padding: EdgeInsets.symmetric(horizontal: 10.w),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      onPressed: _isOpening ? null : () => _openChat(context),
                      child: _isOpening
                          ? SizedBox(
                              width: 16.r,
                              height: 16.r,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.surfaceWhite,
                              ),
                            )
                          : Text(
                              context.isArabic ? 'محادثة' : 'Chat',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.surfaceWhite,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    SizedBox(height: 4.h),

                    // View Profile Details & Unmatch Menu
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_horiz_rounded,
                        color: AppColors.textSecondary,
                        size: 20.sp,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      onSelected: (value) {
                        if (value == 'details') {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => ProfileDetailsSheet(
                              scoredCandidate: ScoredProfile(
                                profile: profile,
                                compatibilityScore: 90,
                                primaryPhotoUrl: match.primaryPhotoUrl,
                              ),
                              onLike: () {},
                              onPass: () => Navigator.of(context).pop(),
                            ),
                          );
                        } else if (value == 'unmatch') {
                          widget.onUnmatch();
                        }
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'details',
                          child: Row(
                            children: [
                              const Icon(Icons.badge_outlined, size: 18),
                              const SizedBox(width: 8),
                              Text(context.isArabic ? 'عرض الملف الكامل' : 'View Full Profile'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'unmatch',
                          child: Row(
                            children: [
                              const Icon(Icons.heart_broken_outlined,
                                  color: AppColors.errorRed, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                context.tr('unmatch'),
                                style: const TextStyle(color: AppColors.errorRed),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// 2. RECEIVED LIKES LIST & CARD
// ----------------------------------------------------------------------------
class _ReceivedLikesList extends StatelessWidget {
  final List<ReceivedLike> likes;
  final Future<void> Function() onRefresh;
  final void Function(ReceivedLike) onLikeBack;

  const _ReceivedLikesList({
    required this.likes,
    required this.onRefresh,
    required this.onLikeBack,
  });

  @override
  Widget build(BuildContext context) {
    if (likes.isEmpty) {
      return _EmptyState(
        icon: Icons.mark_email_read_rounded,
        title: context.tr('noLikes'),
        subtitle: context.isArabic
            ? 'احرص على توثيق هويتك وإكمال بيانات ملفك الشخصي لجذب اهتمام الشركاء الجادين.'
            : 'Make sure to verify your ID and complete your profile to attract serious partners.',
        actionLabel: context.tr('refresh'),
        onAction: onRefresh,
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.secondaryPink,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        itemCount: likes.length,
        itemBuilder: (context, index) {
          final like = likes[index];
          return _ReceivedLikeCard(
            like: like,
            onLikeBack: () => onLikeBack(like),
          );
        },
      ),
    );
  }
}

class _ReceivedLikeCard extends StatelessWidget {
  final ReceivedLike like;
  final VoidCallback onLikeBack;

  const _ReceivedLikeCard({
    required this.like,
    required this.onLikeBack,
  });

  @override
  Widget build(BuildContext context) {
    final profile = like.senderProfile;

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadowColor,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          Container(
            width: 64.r,
            height: 64.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.lightPink, width: 2),
            ),
            child: ClipOval(
              child: like.primaryPhotoUrl != null &&
                      like.primaryPhotoUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: like.primaryPhotoUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.lightPink,
                        child: Icon(
                          Icons.favorite_rounded,
                          color: AppColors.secondaryPink,
                          size: 30.sp,
                        ),
                      ),
                    )
                  : Container(
                      color: AppColors.lightPink,
                      child: Icon(
                        Icons.favorite_rounded,
                        color: AppColors.secondaryPink,
                        size: 30.sp,
                      ),
                    ),
            ),
          ),
          SizedBox(width: 14.w),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavy,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 3.h),
                Text(
                  '${profile.age ?? 25} ${context.tr('yearsOld')} • ${profile.residenceCity}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 4.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: AppColors.lightPink,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    context.isArabic ? 'أبدى اهتماماً جاداً بملفك 💖' : 'Showed serious interest in your profile 💖',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: AppColors.secondaryPink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),

          // Accept / Like Back Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              minimumSize: Size(94.w, 40.h),
              backgroundColor: AppColors.secondaryPink,
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r),
              ),
            ),
            onPressed: onLikeBack,
            icon: Icon(
              Icons.favorite_rounded,
              color: AppColors.surfaceWhite,
              size: 16.sp,
            ),
            label: Text(
              context.isArabic ? 'قبول' : 'Accept',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.surfaceWhite,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// 3. SENT LIKES LIST & CARD
// ----------------------------------------------------------------------------
class _SentLikesList extends StatelessWidget {
  final List<SentLike> likes;
  final Future<void> Function() onRefresh;
  final void Function(SentLike) onCancel;

  const _SentLikesList({
    required this.likes,
    required this.onRefresh,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (likes.isEmpty) {
      return _EmptyState(
        icon: Icons.send_rounded,
        title: context.tr('noSentLikes'),
        subtitle: context.isArabic
            ? 'تصفح الاقتراحات اليومية وأبدي اهتمامك الجاد بمن يناسب مواصفاتك الشرعية.'
            : 'Browse daily recommendations and show serious interest in candidates who match your criteria.',
        actionLabel: context.tr('refresh'),
        onAction: onRefresh,
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.secondaryPink,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        itemCount: likes.length,
        itemBuilder: (context, index) {
          final like = likes[index];
          return _SentLikeCard(
            like: like,
            onCancel: () => onCancel(like),
          );
        },
      ),
    );
  }
}

class _SentLikeCard extends StatelessWidget {
  final SentLike like;
  final VoidCallback onCancel;

  const _SentLikeCard({
    required this.like,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final profile = like.targetProfile;

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadowColor,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          Container(
            width: 60.r,
            height: 60.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderSubtle, width: 1.5),
            ),
            child: ClipOval(
              child: like.primaryPhotoUrl != null &&
                      like.primaryPhotoUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: like.primaryPhotoUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.offWhite,
                        child: Icon(
                          Icons.person_rounded,
                          color: AppColors.textSecondary,
                          size: 30.sp,
                        ),
                      ),
                    )
                  : Container(
                      color: AppColors.offWhite,
                      child: Icon(
                        Icons.person_rounded,
                        color: AppColors.textSecondary,
                        size: 30.sp,
                      ),
                    ),
            ),
          ),
          SizedBox(width: 14.w),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavy,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 3.h),
                Text(
                  '${profile.age ?? 25} ${context.tr('yearsOld')} • ${profile.residenceCity}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 6.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    context.isArabic ? 'بانتظار الرد ⏳' : 'Awaiting Reply ⏳',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: const Color(0xFF856404),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),

          // Cancel Like Button
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              color: AppColors.textSecondary,
              size: 22.sp,
            ),
            tooltip: context.isArabic ? 'إلغاء الإعجاب' : 'Cancel Like',
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// REUSABLE BRAND EMPTY STATE
// ----------------------------------------------------------------------------
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 32.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24.r),
              decoration: const BoxDecoration(
                color: AppColors.lightPink,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 56.sp,
                color: AppColors.secondaryPink,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              title,
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryNavy,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10.h),
            Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                minimumSize: Size(160.w, 44.h),
                backgroundColor: AppColors.primaryNavy,
              ),
              child: Text(
                actionLabel,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.surfaceWhite,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
