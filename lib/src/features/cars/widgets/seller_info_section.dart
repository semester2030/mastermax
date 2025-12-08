import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/color_utils.dart';

class SellerInfoSection extends StatelessWidget {
  final String name;
  final String phone;

  const SellerInfoSection({
    required this.name, required this.phone, super.key,
  });

  Future<void> _makePhoneCall() async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phone,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'معلومات البائع',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: ColorUtils.withOpacity(Theme.of(context).colorScheme.outline, 0.2),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.person_outline),
                  const SizedBox(width: 12),
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _makePhoneCall,
                icon: const Icon(Icons.phone),
                label: const Text('اتصال'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 