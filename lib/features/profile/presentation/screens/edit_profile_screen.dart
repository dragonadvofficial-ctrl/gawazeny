import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/theme/text_styles.dart';
import '../../domain/user_profile.dart';
import '../profile_controller.dart';
import '../widgets/profile_photo_crop_dialog.dart';

/// Screen allowing the user to update their personal details, lifestyle, and matrimonial bio.
class EditProfileScreen extends ConsumerStatefulWidget {
  final UserProfile profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _jobController;
  late TextEditingController _educationController;
  late TextEditingController _cityController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _bioController;

  late MaritalStatusType _maritalStatus;
  late bool _smoker;
  late String _prays;
  late bool _wantsChildren;

  final List<String> _prayerOptions = const [
    'محافظ على الصلاة في المسجد',
    'محافظ على الصلاة في وقتها',
    'أصلي معظم الأوقات وبانتظام',
    'أحاول الالتزام وأسعى للأفضل',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameController = TextEditingController(text: p.fullName);
    _jobController = TextEditingController(text: p.jobTitle ?? '');
    _educationController = TextEditingController(text: p.educationLevel ?? '');
    _cityController = TextEditingController(text: p.residenceCity);
    _heightController = TextEditingController(text: p.heightCm?.toString() ?? '');
    _weightController = TextEditingController(text: p.weightKg?.toString() ?? '');
    _bioController = TextEditingController(text: p.bio ?? '');

    _maritalStatus = p.maritalStatus;
    _smoker = p.smoker;
    _prays = p.prays ?? _prayerOptions.first;
    _wantsChildren = p.wantsChildren;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _jobController.dispose();
    _educationController.dispose();
    _cityController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _showPhotoOptionsSheet() {
    final currentProfile = ref.read(profileControllerProvider).profile ?? widget.profile;
    final photoUrl = currentProfile.photoUrl;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44.w,
                height: 5.h,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
            SizedBox(height: 18.h),
            Text(
              context.tr('changeProfilePhoto'),
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryNavy,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 18.h),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: AppColors.lightPink.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: const Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.primaryNavy,
                ),
              ),
              title: Text(
                context.tr('chooseFromGallery'),
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await _pickAndCropImage(ImageSource.gallery);
              },
            ),
            SizedBox(height: 6.h),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: AppColors.lightPink.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: const Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.primaryNavy,
                ),
              ),
              title: Text(
                context.tr('takePhotoCamera'),
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await _pickAndCropImage(ImageSource.camera);
              },
            ),
            if (photoUrl != null && photoUrl.isNotEmpty) ...[
              SizedBox(height: 6.h),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: AppColors.errorRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.errorRed,
                  ),
                ),
                title: Text(
                  context.tr('removePhoto'),
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.errorRed,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final success = await ref
                      .read(profileControllerProvider.notifier)
                      .removeProfilePhoto();
                  if (success && mounted) {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr('photoRemovedSuccess')),
                        backgroundColor: AppColors.successGreen,
                      ),
                    );
                  }
                },
              ),
            ],
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndCropImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 88,
      );

      if (pickedFile == null || !mounted) return;

      final rawBytes = await pickedFile.readAsBytes();
      if (!mounted) return;

      final croppedBytes = await ProfilePhotoCropDialog.show(context, rawBytes);
      if (croppedBytes == null || !mounted) return;

      final extension = pickedFile.name.split('.').last;
      final success = await ref
          .read(profileControllerProvider.notifier)
          .uploadProfilePhoto(croppedBytes, extension);

      if (success && mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('photoUpdatedSuccess')),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('photoUploadError')),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final currentPhoto = ref.read(profileControllerProvider).profile?.photoUrl ?? widget.profile.photoUrl;

    final updated = widget.profile.copyWith(
      fullName: _nameController.text.trim(),
      jobTitle: _jobController.text.trim().isEmpty ? null : _jobController.text.trim(),
      educationLevel: _educationController.text.trim().isEmpty ? null : _educationController.text.trim(),
      residenceCity: _cityController.text.trim(),
      heightCm: int.tryParse(_heightController.text.trim()),
      weightKg: int.tryParse(_weightController.text.trim()),
      maritalStatus: _maritalStatus,
      smoker: _smoker,
      prays: _prays,
      wantsChildren: _wantsChildren,
      bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
      photoUrl: currentPhoto,
      updatedAt: DateTime.now(),
    );

    final success = await ref
        .read(profileControllerProvider.notifier)
        .updateProfile(updated);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('profileUpdatedSuccess')),
            backgroundColor: AppColors.successGreen,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('profileUpdateError')),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    final activeProfile = state.profile ?? widget.profile;
    final photoUrl = activeProfile.photoUrl;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: Text(context.tr('editProfile')),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: state.isSaving ? null : _handleSave,
            child: state.isSaving
                ? SizedBox(
                    width: 20.w,
                    height: 20.h,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.secondaryPink,
                    ),
                  )
                : Text(
                    context.tr('save'),
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.secondaryPink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            children: [
              // 0. Profile Photo Section Card
              Container(
                padding: EdgeInsets.all(18.r),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: AppColors.borderSubtle),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.cardShadowColor,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        GestureDetector(
                          onTap: _showPhotoOptionsSheet,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: hasPhoto ? AppColors.secondaryPink : AppColors.borderSubtle,
                                width: 3,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 44.r,
                              backgroundColor: AppColors.lightPink,
                              backgroundImage: hasPhoto
                                  ? (photoUrl.startsWith('data:')
                                      ? MemoryImage(base64Decode(photoUrl.split(',').last)) as ImageProvider
                                      : CachedNetworkImageProvider(photoUrl))
                                  : null,
                              child: !hasPhoto
                                  ? Icon(
                                      Icons.person_rounded,
                                      size: 50.sp,
                                      color: AppColors.primaryNavy,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: context.isArabic ? null : 0,
                          left: context.isArabic ? 0 : null,
                          child: GestureDetector(
                            onTap: _showPhotoOptionsSheet,
                            child: Container(
                              padding: EdgeInsets.all(6.r),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryPink,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.surfaceWhite, width: 2),
                              ),
                              child: Icon(
                                Icons.camera_alt_rounded,
                                color: AppColors.surfaceWhite,
                                size: 14.sp,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    TextButton.icon(
                      onPressed: _showPhotoOptionsSheet,
                      icon: Icon(
                        hasPhoto ? Icons.edit_rounded : Icons.add_a_photo_rounded,
                        size: 16.sp,
                        color: AppColors.primaryNavy,
                      ),
                      label: Text(
                        hasPhoto ? context.tr('changeProfilePhoto') : context.tr('uploadProfilePhotoBtn'),
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primaryNavy,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),

              // 1. Basic Info Section
              _buildSectionCard(
                title: context.tr('basicData'),
                icon: Icons.person_outline_rounded,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: context.tr('fullName'),
                      hintText: context.tr('fullNameHint'),
                      prefixIcon: const Icon(Icons.badge_outlined),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return context.tr('fullName');
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 14.h),
                  TextFormField(
                    controller: _cityController,
                    decoration: InputDecoration(
                      labelText: context.tr('residenceCity'),
                      prefixIcon: const Icon(Icons.location_on_outlined),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return context.tr('residenceCity');
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 14.h),
                  DropdownButtonFormField<MaritalStatusType>(
                    initialValue: _maritalStatus,
                    decoration: InputDecoration(
                      labelText: context.tr('maritalStatus'),
                      prefixIcon: const Icon(Icons.family_restroom_rounded),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: MaritalStatusType.single,
                        child: Text(context.tr('single')),
                      ),
                      DropdownMenuItem(
                        value: MaritalStatusType.divorced,
                        child: Text(context.tr('divorced')),
                      ),
                      DropdownMenuItem(
                        value: MaritalStatusType.widowed,
                        child: Text(context.tr('widowed')),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _maritalStatus = val);
                      }
                    },
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              // 2. Career & Education Section
              _buildSectionCard(
                title: context.tr('educationAndWork'),
                icon: Icons.work_outline_rounded,
                children: [
                  TextFormField(
                    controller: _jobController,
                    decoration: InputDecoration(
                      labelText: context.tr('jobTitle'),
                      hintText: context.tr('jobTitleHint'),
                      prefixIcon: const Icon(Icons.business_center_outlined),
                    ),
                  ),
                  SizedBox(height: 14.h),
                  TextFormField(
                    controller: _educationController,
                    decoration: InputDecoration(
                      labelText: context.tr('educationLevel'),
                      prefixIcon: const Icon(Icons.school_outlined),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              // 3. Physical Specs & Lifestyle
              _buildSectionCard(
                title: context.tr('lifestyleValues'),
                icon: Icons.accessibility_new_rounded,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _heightController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: context.tr('height'),
                          ),
                        ),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: TextFormField(
                          controller: _weightController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: context.tr('weight'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14.h),
                  DropdownButtonFormField<String>(
                    initialValue: _prayerOptions.contains(_prays) ? _prays : _prayerOptions.first,
                    decoration: InputDecoration(
                      labelText: context.tr('prayerCommitment'),
                      prefixIcon: const Icon(Icons.mosque_outlined),
                    ),
                    items: _prayerOptions
                        .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _prays = val);
                      }
                    },
                  ),
                  SizedBox(height: 14.h),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.tr('smoker')),
                    subtitle: Text(_smoker ? context.tr('yes') : context.tr('no')),
                    value: _smoker,
                    activeTrackColor: AppColors.secondaryPink,
                    onChanged: (val) => setState(() => _smoker = val),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.tr('wantsChildren')),
                    subtitle: Text(_wantsChildren ? context.tr('yes') : context.tr('no')),
                    value: _wantsChildren,
                    activeTrackColor: AppColors.secondaryPink,
                    onChanged: (val) => setState(() => _wantsChildren = val),
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              // 4. Matrimonial Bio Section
              _buildSectionCard(
                title: context.tr('bio'),
                icon: Icons.format_quote_rounded,
                children: [
                  TextFormField(
                    controller: _bioController,
                    maxLines: 4,
                    maxLength: 400,
                    decoration: InputDecoration(
                      hintText: context.tr('bioHint'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),

              // Save button at bottom
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  onPressed: state.isSaving ? null : _handleSave,
                  icon: const Icon(Icons.save_rounded),
                  label: Text(
                    state.isSaving ? context.tr('loading') : context.tr('save'),
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.surfaceWhite,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 32.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadowColor,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.secondaryPink, size: 22.sp),
              SizedBox(width: 8.w),
              Text(
                title,
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryNavy,
                ),
              ),
            ],
          ),
          const Divider(color: AppColors.dividerColor, height: 24),
          ...children,
        ],
      ),
    );
  }
}
