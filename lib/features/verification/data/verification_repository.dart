import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/network/supabase_client.dart';
import '../../profile/domain/user_profile.dart';
import '../domain/identity_verification.dart';

/// Result returned after submitting a verification request.
class VerificationSubmissionResult {
  final bool success;
  final String message;
  final IdentityVerification verification;

  const VerificationSubmissionResult({
    required this.success,
    required this.message,
    required this.verification,
  });
}

/// Repository managing identity document uploads and manual admin verification workflow.
class VerificationRepository {
  final SupabaseClient _client;

  VerificationRepository(this._client);

  String? get _userId => _client.auth.currentUser?.id;

  // ---------------------------------------------------------------------------
  // Upload a document image to the private identity-documents bucket.
  // ---------------------------------------------------------------------------
  Future<String> uploadDocument(
    Uint8List bytes,
    String filename,
  ) async {
    final uid = _userId;
    if (uid == null) throw 'يجب تسجيل الدخول لرفع المستندات';

    final path = '$uid/$filename';

    try {
      await _client.storage
          .from(SupabaseConstants.identityDocumentsBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      final signedUrl = await _client.storage
          .from(SupabaseConstants.identityDocumentsBucket)
          .createSignedUrl(path, 3600 * 24 * 365);

      return signedUrl;
    } catch (e) {
      developer.log('Error uploading document: $e');
      throw 'تعذر رفع الصورة، يرجى التحقق من اتصالك بالإنترنت';
    }
  }

  // ---------------------------------------------------------------------------
  // Submit verification request to Admin queue (Manual Review Workflow)
  // 1. Sets status to PENDING
  // 2. Returns expected review notification:
  //    «تم استلام طلب توثيق حسابك بنجاح. برجاء الانتظار، سيتم مراجعة طلبك خلال 15 دقيقة.»
  // ---------------------------------------------------------------------------
  Future<VerificationSubmissionResult> submitVerificationRequest({
    required String idCardUrl,
    required String selfieUrl,
  }) async {
    final uid = _userId;
    if (uid == null) throw 'يجب تسجيل الدخول لإرسال طلب التوثيق';

    const promptMessage =
        'تم استلام طلب توثيق حسابك بنجاح. برجاء الانتظار، سيتم مراجعة طلبك خلال 15 دقيقة.';

    // Fetch user profile for full name
    String? userFullName;
    try {
      final profileData = await _client
          .from(SupabaseConstants.profilesTable)
          .select('full_name')
          .eq('id', uid)
          .maybeSingle();
      if (profileData != null) {
        userFullName = profileData['full_name'] as String?;
      }
    } catch (_) {}

    // Try RPC first
    try {
      final rpcRes = await _client.rpc(
        'submit_identity_verification',
        params: {
          'p_id_url': idCardUrl,
          'p_selfie_url': selfieUrl,
        },
      );

      final recordId = rpcRes is Map ? (rpcRes['record_id'] as String? ?? 'verif-$uid') : 'verif-$uid';

      final verification = IdentityVerification(
        id: recordId,
        userId: uid,
        userFullName: userFullName,
        idCardImageUrl: idCardUrl,
        selfieImageUrl: selfieUrl,
        status: VerificationStatusType.pending,
        rejectionReason: null,
        createdAt: DateTime.now(),
      );

      return VerificationSubmissionResult(
        success: true,
        message: promptMessage,
        verification: verification,
      );
    } catch (e, stack) {
      developer.log(
        'RPC submit_identity_verification failed, falling back to direct table query: $e',
        error: e,
        stackTrace: stack,
      );
    }

    // Direct table upsert fallback
    try {
      final res = await _client.from(SupabaseConstants.identityVerificationsTable).upsert(
        {
          'user_id': uid,
          'id_card_image_url': idCardUrl,
          'selfie_image_url': selfieUrl,
          'status': VerificationStatusType.pending.toDbValue(),
          'rejection_reason': null,
          'created_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id',
      ).select().maybeSingle();

      // Sync verification_status to PENDING on profiles table
      await _client
          .from(SupabaseConstants.profilesTable)
          .update({
            'verification_status': VerificationStatusType.pending.toDbValue(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', uid);

      final verification = res != null
          ? IdentityVerification.fromMap(Map<String, dynamic>.from(res), registeredFullName: userFullName)
          : IdentityVerification(
              id: 'verif-$uid',
              userId: uid,
              userFullName: userFullName,
              idCardImageUrl: idCardUrl,
              selfieImageUrl: selfieUrl,
              status: VerificationStatusType.pending,
              rejectionReason: null,
              createdAt: DateTime.now(),
            );

      return VerificationSubmissionResult(
        success: true,
        message: promptMessage,
        verification: verification,
      );
    } catch (e) {
      developer.log('Fallback submitVerificationRequest failed: $e');
      throw 'تعذر إرسال طلب التوثيق، يرجى التحقق من الاتصال وإعادة المحاولة';
    }
  }

  // ---------------------------------------------------------------------------
  // Fetch the latest verification record for the current user.
  // ---------------------------------------------------------------------------
  Future<IdentityVerification?> fetchUserVerificationStatus() async {
    final uid = _userId;
    if (uid == null) return null;

    String? userFullName;
    try {
      final profileData = await _client
          .from(SupabaseConstants.profilesTable)
          .select('full_name')
          .eq('id', uid)
          .maybeSingle();
      if (profileData != null) {
        userFullName = profileData['full_name'] as String?;
      }
    } catch (_) {}

    // Direct query on identity_verifications
    try {
      final data = await _client
          .from(SupabaseConstants.identityVerificationsTable)
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data != null) {
        return IdentityVerification.fromMap(
          Map<String, dynamic>.from(data),
          registeredFullName: userFullName,
        );
      }
    } catch (e) {
      developer.log('fetchUserVerificationStatus direct query error: $e');
    }

    // Try RPC get_my_verification_status
    try {
      final rpcResult = await _client.rpc('get_my_verification_status');
      if (rpcResult != null) {
        final map = Map<String, dynamic>.from(rpcResult as Map);
        final status = VerificationStatusType.fromDbValue(
          map['status'] as String? ?? 'UNVERIFIED',
        );
        if (status == VerificationStatusType.unverified) return null;

        return IdentityVerification(
          id: map['id'] as String? ?? '',
          userId: uid,
          userFullName: userFullName,
          idCardImageUrl: '',
          selfieImageUrl: '',
          status: status,
          rejectionReason: map['rejection_reason'] as String?,
          createdAt: map['created_at'] != null
              ? DateTime.parse(map['created_at'] as String)
              : DateTime.now(),
        );
      }
    } catch (e, stack) {
      developer.log('RPC get_my_verification_status error: $e',
          error: e, stackTrace: stack);
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Admin action helper: approve or reject verification request
  // ---------------------------------------------------------------------------
  Future<bool> reviewVerificationAsAdmin({
    required String verificationId,
    required bool approve,
    String? rejectionReason,
  }) async {
    final action = approve ? 'APPROVE' : 'REJECT';
    try {
      final rpcRes = await _client.rpc('admin_review_verification', params: {
        'p_verification_id': verificationId,
        'p_action': action,
        'p_rejection_reason': rejectionReason,
      });
      if (rpcRes is Map && rpcRes['success'] == true) {
        return true;
      }
    } catch (e) {
      developer.log('RPC admin_review_verification failed, using direct update: $e');
    }

    // Fallback: direct updates
    try {
      final vRecord = await _client
          .from(SupabaseConstants.identityVerificationsTable)
          .select('user_id')
          .eq('id', verificationId)
          .maybeSingle();

      final newStatus = approve
          ? VerificationStatusType.verified.toDbValue()
          : VerificationStatusType.failed.toDbValue();

      await _client
          .from(SupabaseConstants.identityVerificationsTable)
          .update({
            'status': newStatus,
            'rejection_reason': approve ? null : rejectionReason,
            'reviewed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', verificationId);

      if (vRecord != null && vRecord['user_id'] != null) {
        await _client
            .from(SupabaseConstants.profilesTable)
            .update({
              'verification_status': newStatus,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', vRecord['user_id'] as String);
      }
      return true;
    } catch (e) {
      developer.log('reviewVerificationAsAdmin fallback error: $e');
      return false;
    }
  }
}

/// Riverpod provider for [VerificationRepository].
final verificationRepositoryProvider = Provider<VerificationRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return VerificationRepository(client);
});
