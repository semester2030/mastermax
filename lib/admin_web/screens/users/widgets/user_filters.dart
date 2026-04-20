import 'package:flutter/material.dart';

class UserFilters extends StatelessWidget {
  final String? typeFilter;
  final ValueChanged<String?> onTypeChanged;
  final VoidCallback onRefresh;

  const UserFilters({
    super.key,
    this.typeFilter,
    required this.onTypeChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DropdownButton<String?>(
          value: typeFilter,
          hint: const Text('نوع المستخدم'),
          items: const [
            DropdownMenuItem(value: null, child: Text('الكل')),
            DropdownMenuItem(value: 'individual', child: Text('فرد')),
            DropdownMenuItem(value: 'realEstateCompany', child: Text('شركة عقارية')),
            DropdownMenuItem(value: 'carDealer', child: Text('معرض سيارات')),
            DropdownMenuItem(value: 'realEstateAgent', child: Text('وسيط عقاري')),
            DropdownMenuItem(value: 'carTrader', child: Text('تاجر سيارات')),
          ],
          onChanged: onTypeChanged,
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: onRefresh,
          tooltip: 'تحديث',
        ),
      ],
    );
  }
}
