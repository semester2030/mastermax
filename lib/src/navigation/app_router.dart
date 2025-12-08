import 'package:flutter/material.dart';
import '../features/auth/models/user_type.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/user_type_selection_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/main/screens/main_screen.dart';
import '../features/cars/screens/add_car_screen.dart';
import '../features/spotlight/screens/spotlight_subscription_screen.dart';
import '../features/spotlight/screens/spotlight_mada_payment_screen.dart';
import '../features/spotlight/screens/spotlight_bank_transfer_screen.dart';
import '../features/spotlight/screens/spotlight_payment_confirmation_screen.dart';
import '../features/spotlight/models/spotlight_plan.dart';
import '../features/map/screens/main_map_screen.dart';
import '../features/team/screens/team_management_screen.dart';
import '../features/properties/screens/add_property_screen.dart';
import '../features/cars/screens/car_details_screen.dart';
import '../features/profile/screens/real_estate/sales_management_screen.dart';
import '../core/constants/route_constants.dart';
import '../features/spotlight/camera/index.dart';
import '../features/auth/screens/otp_verification_screen.dart';
import '../features/chat/screens/chat_screen.dart';
import '../features/legal/screens/legal_home_screen.dart';
import '../features/legal/screens/privacy_policy_screen.dart';
import '../features/legal/screens/intellectual_property_screen.dart';
import '../features/legal/screens/terms_of_use_screen.dart';
import '../features/legal/screens/complaints_screen.dart';
import '../features/admin/screens/data_transfer_screen.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      
      case '/forgot-password':
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
      
      case '/register':
        if (settings.arguments is UserType) {
          return MaterialPageRoute(
            builder: (_) => RegisterScreen(userType: settings.arguments as UserType),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const RegisterScreen(userType: UserType.individual),
        );
      
      case '/user-type-selection':
        return MaterialPageRoute(
          builder: (_) => const UserTypeSelectionScreen(),
        );
      
      case '/auth/otp':
        if (settings.arguments is! Map<String, dynamic>) {
          throw ArgumentError('Required parameters are missing');
        }
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            phoneNumber: args['phoneNumber'] as String,
          ),
        );
      
      case '/main':
        if (settings.arguments is UserType) {
          return MaterialPageRoute(
            builder: (_) => MainScreen(userType: settings.arguments as UserType),
          );
        }
        return MaterialPageRoute(builder: (_) => const MainScreen());

      case '/map':
        return MaterialPageRoute(
          builder: (_) => const MainMapScreen(),
        );
      
      case '/properties/add':
        return MaterialPageRoute(
          builder: (_) => const AddPropertyScreen(),
        );
      
      case '/cars/add':
        return MaterialPageRoute(
          builder: (_) => const AddCarScreen(),
        );
      
      // Subscription and Payment Routes
      case '/subscription':
        return MaterialPageRoute(
          builder: (_) => const SubscriptionScreen(),
        );
      
      case '/spotlight/payments/mada':
        if (settings.arguments is! SpotlightPlan) {
          throw ArgumentError('Required plan parameter is missing');
        }
        return MaterialPageRoute(
          builder: (_) => SpotlightMadaPaymentScreen(
            plan: settings.arguments as SpotlightPlan,
          ),
        );
      
      case '/spotlight/payments/bank-transfer':
        if (settings.arguments is! SpotlightPlan) {
          throw ArgumentError('Required plan parameter is missing');
        }
        final plan = settings.arguments as SpotlightPlan;
        return MaterialPageRoute(
          builder: (_) => BankTransferScreen(
            amount: plan.price,
            planId: plan.id,
          ),
        );

      case '/spotlight/payments/confirmation':
        if (settings.arguments is! Map<String, dynamic>) {
          throw ArgumentError('Required parameters are missing');
        }
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => SpotlightPaymentConfirmationScreen(
            plan: args['plan'] as SpotlightPlan,
            success: args['success'] as bool,
            message: args['message'] as String,
          ),
        );
      
      case '/team-management':
        return MaterialPageRoute(
          builder: (_) => const TeamManagementScreen(),
        );
      
      case '/car-details':
        if (settings.arguments is! String) {
          throw ArgumentError('Required car ID parameter is missing');
        }
        return MaterialPageRoute(
          builder: (_) => CarDetailsScreen(
            carId: settings.arguments as String,
          ),
        );

      case '/profile/real-estate/features/sales':
        return MaterialPageRoute(
          builder: (_) => const RealEstateSalesManagementScreen(),
        );
      
      case Routes.camera:
        return MaterialPageRoute(
          builder: (_) => const CameraScreen(),
          settings: settings,
        );
      
      case '/chat':
        return MaterialPageRoute(
          builder: (_) => const ChatScreen(),
        );
      
      case '/legal':
        return MaterialPageRoute(
          builder: (_) => const LegalHomeScreen(),
        );
      
      case '/privacy-policy':
        return MaterialPageRoute(
          builder: (_) => const PrivacyPolicyScreen(),
        );
      
      case '/intellectual-property':
        return MaterialPageRoute(
          builder: (_) => const IntellectualPropertyScreen(),
        );
      
      case '/terms-of-use':
        return MaterialPageRoute(
          builder: (_) => const TermsOfUseScreen(),
        );
      
      case '/complaints':
        return MaterialPageRoute(
          builder: (_) => const ComplaintsScreen(),
        );
      
      case '/admin/data-transfer':
        return MaterialPageRoute(
          builder: (_) => const DataTransferScreen(),
        );
      
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('404 - Page not found')),
          ),
        );
    }
  }
} 