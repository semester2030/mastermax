import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'property_form_helpers.dart';

/// Widget لعرض قسم تفاصيل الغرف والمساحات
///
/// يعرض حقول تفصيلية للغرف والمساحات مع collapse/expand
/// يتبع الثيم الموحد للتطبيق
class PropertyRoomDetailsSection extends StatefulWidget {
  final TextEditingController bedroomsController;
  final TextEditingController masterBedroomsController;
  final TextEditingController livingRoomsController;
  final TextEditingController majlisController;
  final TextEditingController menMajlisController;
  final TextEditingController womenMajlisController;
  final TextEditingController diningRoomsController;
  final TextEditingController kitchensController;
  final TextEditingController masterBathroomsController;
  final TextEditingController guestBathroomsController;
  final TextEditingController serviceBathroomsController;
  final TextEditingController storageRoomsController;
  final TextEditingController maidRoomsController;
  final TextEditingController driverRoomsController;
  final TextEditingController laundryRoomsController;
  final TextEditingController totalBuiltAreaController;
  final TextEditingController landAreaController;
  final TextEditingController gardenAreaController;
  final TextEditingController yardAreaController;
  final TextEditingController roomsController; // للتحقق من صحة غرف النوم
  final VoidCallback onChanged;

  const PropertyRoomDetailsSection({
    super.key,
    required this.bedroomsController,
    required this.masterBedroomsController,
    required this.livingRoomsController,
    required this.majlisController,
    required this.menMajlisController,
    required this.womenMajlisController,
    required this.diningRoomsController,
    required this.kitchensController,
    required this.masterBathroomsController,
    required this.guestBathroomsController,
    required this.serviceBathroomsController,
    required this.storageRoomsController,
    required this.maidRoomsController,
    required this.driverRoomsController,
    required this.laundryRoomsController,
    required this.totalBuiltAreaController,
    required this.landAreaController,
    required this.gardenAreaController,
    required this.yardAreaController,
    required this.roomsController,
    required this.onChanged,
  });

  @override
  State<PropertyRoomDetailsSection> createState() => _PropertyRoomDetailsSectionState();
}

class _PropertyRoomDetailsSectionState extends State<PropertyRoomDetailsSection> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: propertySectionCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.room_preferences, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'تفاصيل الغرف والمساحات',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: propertyFormInfoBannerDecoration(),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'هذه التفاصيل اختيارية ولكنها تحسن من جودة العرض',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  PropertySectionTitle(title: 'غرف النوم'),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: widget.bedroomsController,
                          decoration: getPropertyInputDecoration(
                            'عدد غرف النوم',
                            hint: 'مثال: 5',
                            prefixIcon: Icons.bed,
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            widget.onChanged();
                            if (value.isNotEmpty && widget.roomsController.text.isNotEmpty) {
                              final bedrooms = int.tryParse(value) ?? 0;
                              final totalRooms = int.tryParse(widget.roomsController.text) ?? 0;
                              if (bedrooms > totalRooms && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('عدد غرف النوم يجب أن يكون أقل من أو يساوي إجمالي الغرف'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: widget.masterBedroomsController,
                          decoration: getPropertyInputDecoration(
                            'غرف نوم رئيسية',
                            hint: 'مثال: 2',
                            prefixIcon: Icons.bedroom_parent,
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => widget.onChanged(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PropertySectionTitle(title: 'غرف المعيشة'),
                  TextFormField(
                    controller: widget.livingRoomsController,
                    decoration: getPropertyInputDecoration(
                      'عدد غرف المعيشة',
                      hint: 'مثال: 2',
                      prefixIcon: Icons.chair,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => widget.onChanged(),
                  ),
                  const SizedBox(height: 16),
                  PropertySectionTitle(title: 'المجالس'),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: widget.majlisController,
                          decoration: getPropertyInputDecoration('إجمالي المجالس'),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => widget.onChanged(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: widget.menMajlisController,
                          decoration: getPropertyInputDecoration('مجلس رجال'),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => widget.onChanged(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: widget.womenMajlisController,
                          decoration: getPropertyInputDecoration('مجلس نساء'),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => widget.onChanged(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PropertySectionTitle(title: 'المقلط (غرفة الطعام)'),
                  TextFormField(
                    controller: widget.diningRoomsController,
                    decoration: getPropertyInputDecoration('عدد المقلط'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => widget.onChanged(),
                  ),
                  const SizedBox(height: 16),
                  PropertySectionTitle(title: 'المطابخ'),
                  TextFormField(
                    controller: widget.kitchensController,
                    decoration: getPropertyInputDecoration('عدد المطابخ'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => widget.onChanged(),
                  ),
                  const SizedBox(height: 16),
                  PropertySectionTitle(title: 'الحمامات'),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: widget.masterBathroomsController,
                          decoration: getPropertyInputDecoration('حمامات رئيسية'),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => widget.onChanged(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: widget.guestBathroomsController,
                          decoration: getPropertyInputDecoration('حمامات ضيوف'),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => widget.onChanged(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: widget.serviceBathroomsController,
                          decoration: getPropertyInputDecoration('حمامات خدمة'),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => widget.onChanged(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PropertySectionTitle(title: 'غرف أخرى'),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: widget.storageRoomsController,
                          decoration: getPropertyInputDecoration('غرف تخزين'),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => widget.onChanged(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: widget.maidRoomsController,
                          decoration: getPropertyInputDecoration('غرف خادمة'),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => widget.onChanged(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: widget.driverRoomsController,
                          decoration: getPropertyInputDecoration('غرف سائق'),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => widget.onChanged(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: widget.laundryRoomsController,
                          decoration: getPropertyInputDecoration('غرف غسيل'),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => widget.onChanged(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PropertySectionTitle(title: 'المساحات (م²)'),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: widget.totalBuiltAreaController,
                          decoration: getPropertyInputDecoration('المساحة المبنية'),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => widget.onChanged(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: widget.landAreaController,
                          decoration: getPropertyInputDecoration('مساحة الأرض'),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => widget.onChanged(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: widget.gardenAreaController,
                          decoration: getPropertyInputDecoration('مساحة الحديقة'),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => widget.onChanged(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: widget.yardAreaController,
                          decoration: getPropertyInputDecoration('مساحة الحوش'),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => widget.onChanged(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
