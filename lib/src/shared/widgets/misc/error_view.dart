import 'package:flutter/material.dart';
import 'package:mastermax_2030/src/core/constants/app_constants.dart';

class ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final String? buttonText;
  final VoidCallback? onRetry;
  final bool showHomeButton;
  final IconData? icon;

  const ErrorView({
    required this.title, required this.message, super.key,
    this.buttonText,
    this.onRetry,
    this.showHomeButton = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 24),
            ],
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (onRetry != null) ...[
              ElevatedButton(
                onPressed: onRetry,
                child: Text(buttonText ?? AppConstants.retry),
              ),
              const SizedBox(height: 16),
            ],
            if (showHomeButton)
              TextButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('العودة للرئيسية'),
              ),
          ],
        ),
      ),
    );
  }
}

class NetworkErrorView extends ErrorView {
  const NetworkErrorView({
    super.key,
    super.onRetry,
  }) : super(
          title: 'خطأ في الاتصال',
          message: AppConstants.networkError,
          buttonText: AppConstants.retry,
          icon: Icons.wifi_off,
        );
}

class ServerErrorView extends ErrorView {
  const ServerErrorView({
    super.key,
    super.onRetry,
  }) : super(
          title: 'خطأ في الخادم',
          message: AppConstants.serverError,
          buttonText: AppConstants.retry,
          icon: Icons.error_outline,
        );
}

class TimeoutErrorView extends ErrorView {
  const TimeoutErrorView({
    super.key,
    super.onRetry,
  }) : super(
          title: 'انتهت المهلة',
          message: AppConstants.timeoutError,
          buttonText: AppConstants.retry,
          icon: Icons.timer_off,
        );
}

class EmptyErrorView extends ErrorView {
  const EmptyErrorView({
    required super.title, required super.message, super.key,
    super.buttonText,
    super.onRetry,
  }) : super(
          icon: Icons.inbox,
        );
}

class NotFoundErrorView extends ErrorView {
  const NotFoundErrorView({
    super.key,
  }) : super(
          title: 'الصفحة غير موجودة',
          message: 'عذراً، الصفحة التي تبحث عنها غير موجودة',
          showHomeButton: true,
          icon: Icons.search_off,
        );
}

class UnauthorizedErrorView extends ErrorView {
  const UnauthorizedErrorView({
    super.key,
  }) : super(
          title: 'غير مصرح',
          message: 'عذراً، لا يمكنك الوصول إلى هذه الصفحة',
          showHomeButton: true,
          icon: Icons.lock,
        );
}

class MaintenanceErrorView extends ErrorView {
  const MaintenanceErrorView({
    super.key,
    super.onRetry,
  }) : super(
          title: 'الصيانة',
          message: 'عذراً، التطبيق في وضع الصيانة حالياً، يرجى المحاولة لاحقاً',
          buttonText: AppConstants.retry,
          icon: Icons.build,
        );
} 