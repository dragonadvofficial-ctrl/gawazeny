import 'package:flutter/material.dart';

/// Preview configuration for visual review, interactive showcase, and screenshot capturing.
/// Set [kPreviewMode] to false to return to live Supabase production mode.
const bool kPreviewMode = false;

/// Global navigator key allowing overlays and quick switcher navigation from anywhere.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Enumeration of previewable screens for the Global Quick Navigator.
enum PreviewScreenId {
  welcome,
  loginRegister,
  onboarding,
  matchingFeed,
  profileDetails,
  filterSheet,
  matchSuccessDialog,
  matchesAndLikes,
  verificationWizard,
  chatInbox,
  chatRoom,
  subscriptions,
  profileOverview,
  editProfile,
  blockedUsers,
  privacySecurity,
}
