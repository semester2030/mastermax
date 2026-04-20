import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/auth/models/user_type.dart';
import '../features/auth/screens/app_entry_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/user_type_selection_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/main/screens/main_screen.dart';
import '../features/cars/screens/add_car_screen.dart';
import '../features/cars/screens/edit_car_screen.dart';
import '../features/cars/models/car_model.dart';
import '../features/spotlight/config/spotlight_monetization_config.dart';
import '../features/spotlight/screens/spotlight_subscription_screen.dart';
import '../features/spotlight/screens/spotlight_mada_payment_screen.dart';
import '../features/spotlight/screens/spotlight_bank_transfer_screen.dart';
import '../features/spotlight/screens/spotlight_payment_confirmation_screen.dart';
import '../features/spotlight/screens/my_videos_screen.dart';
import '../features/spotlight/screens/add_video_screen.dart';
import '../features/spotlight/screens/migrate_videos_screen.dart';
import '../features/spotlight/screens/check_videos_status_screen.dart';
import '../features/spotlight/screens/admin_delete_videos_screen.dart';
import '../features/spotlight/screens/find_orphaned_videos_screen.dart';
import '../features/spotlight/screens/seller_videos_screen.dart';
import '../features/spotlight/screens/spotlight_location_map_screen.dart';
import '../features/spotlight/screens/video_history_screen.dart';
import '../features/auth/screens/admin_verification_screen.dart';
import '../features/spotlight/models/spotlight_plan.dart';
import '../features/spotlight/models/video_model.dart';
import '../features/spotlight/models/spotlight_category.dart';
import '../features/map/screens/main_map_screen.dart';
import '../features/team/screens/team_management_screen.dart';
import '../features/properties/screens/add_property_screen.dart';
import '../features/cars/screens/car_details_screen.dart';
import '../features/profile/screens/real_estate/sales_management_screen.dart';
import '../features/profile/screens/real_estate/customers_management_screen.dart';
import '../features/profile/screens/real_estate/branches_management_screen.dart';
import '../core/constants/route_constants.dart';
import '../features/spotlight/camera/index.dart';
import '../features/auth/screens/otp_verification_screen.dart';
import '../features/auth/providers/auth_state.dart';
import '../features/auth/utils/listing_vertical_guard.dart';
import '../features/auth/widgets/listing_access_denied_page.dart';
import '../features/chat/screens/chat_screen.dart';
import '../features/legal/screens/legal_home_screen.dart';
import '../features/legal/screens/privacy_policy_screen.dart';
import '../features/legal/screens/intellectual_property_screen.dart';
import '../features/legal/screens/terms_of_use_screen.dart';
import '../features/legal/screens/complaints_screen.dart';
import '../features/profile/screens/edit_profile_screen.dart';
import '../features/profile/screens/delete_account_screen.dart';
import '../features/properties/screens/property_virtual_tour_screen.dart';
import '../features/cars/screens/car_virtual_tour_screen.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.property360View:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text(
                'عذراً، هذه الميزة غير متوفرة حالياً\nسيتم إعادة تفعيلها قريباً',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        );

      case Routes.propertyVirtualTour:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => PropertyVirtualTourScreen(
            propertyId: args['propertyId'] as String,
            tourUrl: args['tourUrl'] as String,
          ),
        );

      case Routes.car360View:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text(
                'عذراً، هذه الميزة غير متوفرة حالياً\nسيتم إعادة تفعيلها قريباً',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        );

      case Routes.carVirtualTour:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => CarVirtualTourScreen(
            carId: args['carId'] as String,
            tourUrl: args['tourUrl'] as String,
          ),
        );

      case Routes.home:
        return MaterialPageRoute(builder: (_) => const AppEntryScreen());
      
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
        // ✅ التحقق من arguments لمعرفة إذا كانت الخريطة مفتوحة من Spotlight
        final args = settings.arguments;
        final showBackButton = args != null && args is Map && args.containsKey('selectedVideo');
        return MaterialPageRoute(
          builder: (_) => MainMapScreen(
            showBackButton: showBackButton,
          ),
        );
      
      case '/properties/add':
        return MaterialPageRoute(
          builder: (context) {
            final auth = Provider.of<AuthState>(context, listen: false);
            final t = auth.user?.type ?? auth.userType;
            if (!ListingVerticalGuard.mayPublishProperties(t, isAdmin: auth.isAdmin)) {
              return ListingAccessDeniedPage(
                message: ListingVerticalGuard.denialMessageForPropertyListing(t),
              );
            }
            return const AddPropertyScreen();
          },
        );
      
      case '/cars/add':
        return MaterialPageRoute(
          builder: (context) {
            final auth = Provider.of<AuthState>(context, listen: false);
            final t = auth.user?.type ?? auth.userType;
            if (!ListingVerticalGuard.mayPublishCars(t, isAdmin: auth.isAdmin)) {
              return ListingAccessDeniedPage(
                message: ListingVerticalGuard.carsDeniedMessage,
              );
            }
            return const AddCarScreen();
          },
        );

      case '/cars/edit':
        if (settings.arguments is! CarModel) {
          throw ArgumentError('تعديل المركبة يتطلب تمرير CarModel في arguments');
        }
        return MaterialPageRoute(
          builder: (context) {
            final auth = Provider.of<AuthState>(context, listen: false);
            final t = auth.user?.type ?? auth.userType;
            if (!ListingVerticalGuard.mayPublishCars(t, isAdmin: auth.isAdmin)) {
              return ListingAccessDeniedPage(
                message: ListingVerticalGuard.carsDeniedMessage,
              );
            }
            return EditCarScreen(car: settings.arguments as CarModel);
          },
        );
      
      // Subscription and Payment Routes (gated until IAP / compliance is ready)
      case '/subscription':
        if (!SpotlightMonetizationConfig.subscriptionsAndPaymentsEnabled) {
          return MaterialPageRoute(
            builder: (_) => const SpotlightMonetizationUnavailableScreen(),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const SubscriptionScreen(),
        );

      case '/spotlight/payments/mada':
        if (!SpotlightMonetizationConfig.subscriptionsAndPaymentsEnabled) {
          return MaterialPageRoute(
            builder: (_) => const SpotlightMonetizationUnavailableScreen(),
          );
        }
        if (settings.arguments is! SpotlightPlan) {
          throw ArgumentError('Required plan parameter is missing');
        }
        return MaterialPageRoute(
          builder: (_) => SpotlightMadaPaymentScreen(
            plan: settings.arguments as SpotlightPlan,
          ),
        );

      case '/spotlight/payments/bank-transfer':
        if (!SpotlightMonetizationConfig.subscriptionsAndPaymentsEnabled) {
          return MaterialPageRoute(
            builder: (_) => const SpotlightMonetizationUnavailableScreen(),
          );
        }
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
        if (!SpotlightMonetizationConfig.subscriptionsAndPaymentsEnabled) {
          return MaterialPageRoute(
            builder: (_) => const SpotlightMonetizationUnavailableScreen(),
          );
        }
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
      
      case '/sales-management':
        return MaterialPageRoute(
          builder: (_) => const RealEstateSalesManagementScreen(),
        );
      
      case '/customers-management':
        return MaterialPageRoute(
          builder: (_) => const CustomersManagementScreen(),
        );
      
      case '/inventory-management':
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('إدارة المخزون')),
            body: const Center(
              child: Text('شاشة إدارة المخزون قيد التطوير'),
            ),
          ),
        );
      
      case '/branches-management':
        return MaterialPageRoute(
          builder: (_) => const BranchesManagementScreen(),
        );
      
      case '/appointments':
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('جدولة المواعيد')),
            body: const Center(
              child: Text('شاشة جدولة المواعيد قيد التطوير'),
            ),
          ),
        );
      
      case Routes.camera:
        return MaterialPageRoute(
          builder: (_) => const CameraScreen(),
          settings: settings,
        );
      
      case '/chat':
        return MaterialPageRoute(
          builder: (_) => const ChatScreen(),
          settings: settings,
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
      
      case '/profile/edit':
        return MaterialPageRoute(
          builder: (_) => const EditProfileScreen(),
        );

      case Routes.deleteAccount:
        return MaterialPageRoute(
          builder: (_) => const DeleteAccountScreen(),
        );
      
      case '/spotlight/migrate':
        return MaterialPageRoute(
          builder: (_) => const MigrateVideosScreen(),
        );
      
      case '/spotlight/check-status':
        return MaterialPageRoute(
          builder: (_) => const CheckVideosStatusScreen(),
        );
      
      case '/spotlight/admin/delete-videos':
        return MaterialPageRoute(
          builder: (_) => const AdminDeleteVideosScreen(),
        );
      
      case '/spotlight/admin/find-orphaned':
        return MaterialPageRoute(
          builder: (_) => const FindOrphanedVideosScreen(),
        );
      
      case '/admin/verification':
        return MaterialPageRoute(
          builder: (_) => const AdminVerificationScreen(),
        );
      
      // Spotlight Routes
      case '/spotlight/my-videos':
        return MaterialPageRoute(
          builder: (_) => const MyVideosScreen(),
        );
      
      case '/spotlight/upload':
        if (settings.arguments is SpotlightCategory) {
          return MaterialPageRoute(
            builder: (_) => AddVideoScreen(
              category: settings.arguments as SpotlightCategory,
            ),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const AddVideoScreen(
            category: SpotlightCategory.mixed,
          ),
        );
      
      case '/spotlight/seller':
        // Route format: /spotlight/seller/{sellerId}
        if (settings.arguments is Map<String, dynamic>) {
          final args = settings.arguments as Map<String, dynamic>;
          final sellerId = args['sellerId'] as String?;
          final sellerName = args['sellerName'] as String? ?? 'غير معروف';
          
          if (sellerId != null && sellerId.isNotEmpty) {
            return MaterialPageRoute(
              builder: (_) => SellerVideosScreen(
                sellerId: sellerId,
                sellerName: sellerName,
              ),
            );
          }
        }
        // Fallback: إذا لم يتم تمرير arguments بشكل صحيح
        return MaterialPageRoute(
          builder: (_) => const MainScreen(),
        );
      
      case '/spotlight/history':
        return MaterialPageRoute(
          builder: (_) => const VideoHistoryScreen(),
        );

      case '/spotlight/location':
        if (settings.arguments is Map<String, dynamic>) {
          final args = settings.arguments as Map<String, dynamic>;
          final video = args['video'];
          if (video is VideoModel) {
            return MaterialPageRoute(
              builder: (_) => SpotlightLocationMapScreen(video: video),
            );
          }
        }
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('بيانات الموقع غير متوفرة')),
          ),
        );
      
      default:
        // Handle dynamic routes
        if (settings.name != null) {
          // Route format: /spotlight/edit/{videoId}
          if (settings.name!.startsWith('/spotlight/edit/')) {
            if (settings.arguments is VideoModel) {
              final video = settings.arguments as VideoModel;
              return MaterialPageRoute(
                builder: (_) => AddVideoScreen(
                  category: video.type == VideoType.car 
                      ? SpotlightCategory.cars 
                      : SpotlightCategory.realEstate,
                  editVideo: video,
                ),
              );
            }
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(child: Text('فيديو غير موجود')),
              ),
            );
          }
          
          // Route format: /spotlight/seller/{sellerId}
          if (settings.name!.startsWith('/spotlight/seller/')) {
            final sellerId = settings.name!.split('/spotlight/seller/').last;
            if (sellerId.isNotEmpty) {
              // محاولة الحصول على sellerName من arguments
              String sellerName = 'غير معروف';
              if (settings.arguments is Map<String, dynamic>) {
                sellerName = (settings.arguments as Map<String, dynamic>)['sellerName'] as String? ?? 'غير معروف';
              }
              
              return MaterialPageRoute(
                builder: (_) => SellerVideosScreen(
                  sellerId: sellerId,
                  sellerName: sellerName,
                ),
              );
            }
          }
        }
        
        // Default route for unknown paths
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('404 - Page not found')),
          ),
        );
    }
  }
} 