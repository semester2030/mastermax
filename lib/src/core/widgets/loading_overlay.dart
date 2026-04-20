import 'package:flutter/material.dart';

/// واجهة تحميل متراكبة — يدعم [message] للمرحلة و [progress] 0…1 لنسبة الرفع (null = غير محدد).
class LoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String? message;
  /// بين 0 و 1 لعرض تقدم محدد؛ `null` لدائرة غير محددة النسبة.
  final double? progress;

  const LoadingOverlay({
    required this.child,
    required this.isLoading,
    super.key,
    this.message,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Theme.of(context).colorScheme.scrim.withOpacity(0.54),
            child: Center(
              child: Semantics(
                label: message ?? 'جاري التحميل',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: CircularProgressIndicator(
                        value: progress != null ? progress!.clamp(0.0, 1.0) : null,
                        valueColor: AlwaysStoppedAnimation<Color>(onPrimary),
                        strokeWidth: 4,
                      ),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          message!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: onPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    if (progress != null && progress! > 0 && progress! < 1) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${(progress!.clamp(0.0, 1.0) * 100).round()}٪',
                        style: TextStyle(
                          color: onPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
