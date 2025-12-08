import 'package:flutter/material.dart';
import '../constants/route_constants.dart';
import '../../features/properties/screens/property_virtual_tour_screen.dart';
import '../../features/cars/screens/car_virtual_tour_screen.dart';

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
      
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
} 