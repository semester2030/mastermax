import 'package:flutter/material.dart';
import '../screens/legal_home_screen.dart';
import '../screens/privacy_policy_screen.dart';
import '../screens/intellectual_property_screen.dart';
import '../screens/terms_of_use_screen.dart';
import '../screens/complaints_screen.dart';

class LegalNavigationService {
  static void navigateToLegalHome(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LegalHomeScreen()),
    );
  }

  static void navigateToPrivacyPolicy(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
    );
  }

  static void navigateToIntellectualProperty(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const IntellectualPropertyScreen()),
    );
  }

  static void navigateToTermsOfUse(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TermsOfUseScreen()),
    );
  }

  static void navigateToComplaints(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ComplaintsScreen()),
    );
  }
} 