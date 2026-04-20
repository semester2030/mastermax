import 'package:flutter/material.dart';

/// Paid Spotlight plans and payment flows (Mada / bank / confirmation).
///
/// Keep [subscriptionsAndPaymentsEnabled] `false` until the flow complies with
/// store rules (e.g. In-App Purchase on iOS) and is fully implemented.
class SpotlightMonetizationConfig {
  SpotlightMonetizationConfig._();

  /// Set to `true` when ready to ship paid Spotlight again.
  static const bool subscriptionsAndPaymentsEnabled = false;
}

/// Shown when monetization routes are hit while disabled (e.g. stale deep link).
class SpotlightMonetizationUnavailableScreen extends StatelessWidget {
  const SpotlightMonetizationUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('غير متاح حالياً')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'خدمة اشتراك Spotlight غير متاحة حالياً. سيتم تفعيلها لاحقاً.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
