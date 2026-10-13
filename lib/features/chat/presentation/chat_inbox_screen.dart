import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/theme/text_styles.dart';
import '../domain/chat_message.dart';
import 'chat_controller.dart';
import 'chat_room_screen.dart';

/// Chat inbox screen listing all active conversations for the current user.
class ChatInboxScreen extends ConsumerStatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  ConsumerState<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends ConsumerState<ChatInboxScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inboxControllerProvider);
    final controller = ref.read(inboxControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(child: Text(context.tr('navChat'))),
            if (state.totalUnread > 0)
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: AppColors.secondaryPink,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  '${state.totalUnread}',
                  style: TextStyle(
                    color: AppColors.surfaceWhite,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: context.tr('refresh'),
            onPressed: controller.loadConversations,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: TextField(
              controller: _searchController,
              onChanged: controller.updateSearch,
              textDirection:
                  context.isArabic ? TextDirection.rtl : TextDirection.ltr,
              decoration: InputDecoration(
                hintText: context.tr('searchConversations'),
                hintStyle: AppTextStyles.bodyMedium,
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textSecondary),
                suffixIcon: state.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: AppColors.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          controller.clearSearch();
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surfaceWhite,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: const BorderSide(
                      color: AppColors.primaryNavy, width: 1.5),
                ),
              ),
            ),
          ),

          // Body
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.secondaryPink,
                    ),
                  )
                : state.filtered.isEmpty
                    ? _EmptyInboxState(
                        hasSearch: state.searchQuery.isNotEmpty,
                      )
                    : RefreshIndicator(
                        onRefresh: controller.loadConversations,
                        color: AppColors.secondaryPink,
                        child: ListView.separated(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16.w, vertical: 4.h),
                          itemCount: state.filtered.length,
                          separatorBuilder: (_, _) =>
                              SizedBox(height: 8.h),
                          itemBuilder: (context, index) {
                            final conv = state.filtered[index];
                            return _ConversationTile(
                              conversation: conv,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChatRoomScreen(
                                    conversation: conv,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CONVERSATION TILE
// ============================================================================
class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.unreadCount > 0;

    return Material(
      color: AppColors.surfaceWhite,
      borderRadius: BorderRadius.circular(18.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(18.r),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: hasUnread
                  ? AppColors.secondaryPink.withValues(alpha: 0.3)
                  : AppColors.borderSubtle,
            ),
            boxShadow: const [
              BoxShadow(
                color: AppColors.cardShadowColor,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar with verification badge
              Stack(
                children: [
                  CircleAvatar(
                    radius: 26.r,
                    backgroundColor: AppColors.lightPink,
                    backgroundImage: conversation.partnerPhotoUrl != null
                        ? CachedNetworkImageProvider(
                            conversation.partnerPhotoUrl!)
                        : null,
                    child: conversation.partnerPhotoUrl == null
                        ? Icon(Icons.person_rounded,
                            color: AppColors.primaryNavy, size: 28.sp)
                        : null,
                  ),
                  if (conversation.partnerIsVerified)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: Container(
                        width: 16.r,
                        height: 16.r,
                        decoration: BoxDecoration(
                          color: AppColors.successGreen,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.surfaceWhite, width: 1.5),
                        ),
                        child: Center(
                          child: Icon(Icons.check_rounded,
                              color: AppColors.surfaceWhite, size: 9.sp),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: 12.w),

              // Name + last message
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.partnerName,
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: hasUnread
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          conversation.lastMessageTimeLabel,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: hasUnread
                                ? AppColors.secondaryPink
                                : AppColors.textMuted,
                            fontWeight: hasUnread
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 3.h),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.lastMessage ??
                                (context.isArabic
                                    ? 'ابدأ المحادثة الآن...'
                                    : 'Start conversation now...'),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: hasUnread
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasUnread) ...[
                          SizedBox(width: 6.w),
                          Container(
                            padding: EdgeInsets.all(5.r),
                            decoration: const BoxDecoration(
                              color: AppColors.secondaryPink,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${conversation.unreadCount}',
                              style: TextStyle(
                                color: AppColors.surfaceWhite,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// EMPTY STATE
// ============================================================================
class _EmptyInboxState extends StatelessWidget {
  final bool hasSearch;
  const _EmptyInboxState({required this.hasSearch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
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
                hasSearch
                    ? Icons.search_off_rounded
                    : Icons.chat_bubble_outline_rounded,
                color: AppColors.secondaryPink,
                size: 48.sp,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              hasSearch
                  ? (context.isArabic ? 'لا توجد نتائج للبحث' : 'No search results')
                  : (context.isArabic ? 'لا توجد محادثات بعد' : 'No conversations yet'),
              style: AppTextStyles.titleLarge.copyWith(
                color: AppColors.primaryNavy,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              hasSearch
                  ? (context.isArabic ? 'جرّب البحث باسم آخر' : 'Try searching with a different name')
                  : (context.isArabic
                      ? 'عند حصول توافق مع شخص موثّق، يمكنكما بدء محادثة جادة هنا.'
                      : 'When you match with a verified member, you can start a serious chat here.'),
              style: AppTextStyles.bodyMedium
                  .copyWith(height: 1.5, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
