import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/supabase_client.dart';

/// Model representing admin-configurable payment settings from the database.
class PaymentSettings {
  final String vodafoneCashNumber;
  final String vodafoneCashName;
  final bool vodafoneCashEnabled;
  final String instapayAccount;
  final String instapayName;
  final bool instapayEnabled;
  final String supportWhatsapp;

  const PaymentSettings({
    this.vodafoneCashNumber = '01099887766',
    this.vodafoneCashName = 'جوزيني يا ماما',
    this.vodafoneCashEnabled = true,
    this.instapayAccount = 'gawezeny@instapay',
    this.instapayName = 'جوزيني يا ماما',
    this.instapayEnabled = true,
    this.supportWhatsapp = '01099887766',
  });

  factory PaymentSettings.fromMap(Map<String, dynamic> map) {
    return PaymentSettings(
      vodafoneCashNumber: map['vodafone_cash_number'] as String? ?? '01099887766',
      vodafoneCashName: map['vodafone_cash_name'] as String? ?? 'جوزيني يا ماما',
      vodafoneCashEnabled: map['vodafone_cash_enabled'] as bool? ?? true,
      instapayAccount: map['instapay_account'] as String? ?? 'gawezeny@instapay',
      instapayName: map['instapay_name'] as String? ?? 'جوزيني يا ماما',
      instapayEnabled: map['instapay_enabled'] as bool? ?? true,
      supportWhatsapp: map['support_whatsapp'] as String? ?? '01099887766',
    );
  }
}

/// Repository to fetch payment settings from Supabase.
class PaymentSettingsRepository {
  final SupabaseService _supabase;

  const PaymentSettingsRepository(this._supabase);

  /// Fetches the payment settings from the `payment_settings` table.
  /// Falls back to defaults if the table doesn't exist yet.
  Future<PaymentSettings> getPaymentSettings() async {
    try {
      final response = await _supabase.client
          .from('payment_settings')
          .select()
          .eq('id', 'default')
          .maybeSingle();

      if (response != null) {
        return PaymentSettings.fromMap(Map<String, dynamic>.from(response));
      }
    } catch (e, stack) {
      developer.log(
        'PaymentSettingsRepository.getPaymentSettings notice: $e',
        error: e,
        stackTrace: stack,
      );
    }
    return const PaymentSettings();
  }
}

/// Provider for [PaymentSettingsRepository].
final paymentSettingsRepositoryProvider = Provider<PaymentSettingsRepository>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return PaymentSettingsRepository(supabase);
});

/// Provider that fetches payment settings from the database.
final paymentSettingsProvider = FutureProvider<PaymentSettings>((ref) async {
  final repo = ref.watch(paymentSettingsRepositoryProvider);
  return repo.getPaymentSettings();
});
