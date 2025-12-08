import 'package:flutter/material.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:intl/intl.dart' as intl;

enum InspectionStatus {
  scheduled,
  completed,
  cancelled,
  inProgress
}

extension InspectionStatusExtension on InspectionStatus {
  String get arabicName {
    switch (this) {
      case InspectionStatus.scheduled:
        return 'مجدولة';
      case InspectionStatus.completed:
        return 'مكتملة';
      case InspectionStatus.cancelled:
        return 'ملغية';
      case InspectionStatus.inProgress:
        return 'جارية';
    }
  }

  Color get color {
    switch (this) {
      case InspectionStatus.scheduled:
        return AppColors.primary;
      case InspectionStatus.completed:
        return AppColors.success;
      case InspectionStatus.cancelled:
        return AppColors.error;
      case InspectionStatus.inProgress:
        return AppColors.warning;
    }
  }
}

class Inspection {
  final String id;
  final String propertyTitle;
  final String clientName;
  final String clientPhone;
  final DateTime dateTime;
  final String location;
  final String notes;
  final InspectionStatus status;

  Inspection({
    required this.id,
    required this.propertyTitle,
    required this.clientName,
    required this.clientPhone,
    required this.dateTime,
    required this.location,
    required this.notes,
    required this.status,
  });

  Inspection copyWith({
    String? id,
    String? propertyTitle,
    String? clientName,
    String? clientPhone,
    DateTime? dateTime,
    String? location,
    String? notes,
    InspectionStatus? status,
  }) {
    return Inspection(
      id: id ?? this.id,
      propertyTitle: propertyTitle ?? this.propertyTitle,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      dateTime: dateTime ?? this.dateTime,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      status: status ?? this.status,
    );
  }
}

class InspectionSchedulingScreen extends StatefulWidget {
  const InspectionSchedulingScreen({super.key});

  @override
  State<InspectionSchedulingScreen> createState() => _InspectionSchedulingScreenState();
}

class _InspectionSchedulingScreenState extends State<InspectionSchedulingScreen> {
  DateTime selectedDate = DateTime.now();
  List<Inspection> inspections = [
    Inspection(
      id: '1',
      propertyTitle: 'فيلا فاخرة في حي النرجس',
      clientName: 'أحمد محمد',
      clientPhone: '0501234567',
      dateTime: DateTime.now().add(const Duration(hours: 2)),
      location: 'حي النرجس، شارع الملك فهد',
      notes: 'العميل مهتم بشراء الفيلا',
      status: InspectionStatus.scheduled,
    ),
    Inspection(
      id: '2',
      propertyTitle: 'شقة في برج السلام',
      clientName: 'سارة عبدالله',
      clientPhone: '0507654321',
      dateTime: DateTime.now().add(const Duration(hours: 4)),
      location: 'برج السلام، شارع العليا',
      notes: 'معاينة للإيجار',
      status: InspectionStatus.inProgress,
    ),
    Inspection(
      id: '3',
      propertyTitle: 'أرض سكنية في حي الياسمين',
      clientName: 'محمد علي',
      clientPhone: '0503456789',
      dateTime: DateTime.now().add(const Duration(hours: 6)),
      location: 'حي الياسمين، شارع الأمير سلطان',
      notes: 'قطعة أرض للاستثمار',
      status: InspectionStatus.completed,
    ),
  ];

  void _addInspection(Inspection newInspection) {
    setState(() {
      inspections.add(newInspection.copyWith(
        id: (inspections.length + 1).toString(),
      ));
    });
  }

  List<Inspection> _getInspectionsByDate(DateTime date) {
    return inspections.where((inspection) {
      return inspection.dateTime.year == date.year &&
          inspection.dateTime.month == date.month &&
          inspection.dateTime.day == date.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredInspections = _getInspectionsByDate(selectedDate);
    
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.surface,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.secondary,
              ],
            ),
          ),
        ),
        title: const Text(
          'جدولة المعاينات',
          style: TextStyle(
            color: AppColors.accent,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: AppColors.accent),
            onPressed: () => _selectDate(context),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: AppColors.accent),
            onPressed: () => _showFilterDialog(),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ColorUtils.withOpacity(AppColors.primary, 0.1),
              ColorUtils.withOpacity(AppColors.secondary, 0.1),
            ],
          ),
        ),
        child: Column(
          children: [
            _buildDateSelector(),
            _buildSummaryCards(filteredInspections),
            Expanded(
              child: _buildInspectionsList(filteredInspections),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddInspectionDialog,
        backgroundColor: const Color(0xFFFFD700),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryCards(List<Inspection> inspections) {
    final totalInspections = inspections.length;
    final completedInspections = inspections.where((i) => i.status == InspectionStatus.completed).length;
    final cancelledInspections = inspections.where((i) => i.status == InspectionStatus.cancelled).length;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryCard(
            'إجمالي المعاينات',
            totalInspections.toString(),
            Icons.calendar_today,
          ),
          _buildSummaryCard(
            'المعاينات المكتملة',
            completedInspections.toString(),
            Icons.check_circle,
            color: Colors.green,
          ),
          _buildSummaryCard(
            'المعاينات الملغاة',
            cancelledInspections.toString(),
            Icons.cancel,
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildInspectionsList(List<Inspection> inspections) {
    if (inspections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              size: 48,
              color: ColorUtils.withOpacity(Colors.grey, 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد معاينات في هذا اليوم',
              style: TextStyle(
                color: ColorUtils.withOpacity(Colors.grey, 0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: inspections.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final inspection = inspections[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              inspection.propertyTitle,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person, size: 16),
                    const SizedBox(width: 8),
                    Text(inspection.clientName),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.phone, size: 16),
                    const SizedBox(width: 8),
                    Text(inspection.clientPhone),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(inspection.location)),
                  ],
                ),
                if (inspection.notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.note, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(inspection.notes)),
                    ],
                  ),
                ],
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ColorUtils.withOpacity(inspection.status.color, 0.3),
                ),
              ),
              child: Text(
                inspection.status.arabicName,
                style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                selectedDate = selectedDate.subtract(const Duration(days: 1));
              });
            },
          ),
          Expanded(
            child: Text(
              intl.DateFormat.yMMMMd('ar').format(selectedDate),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                selectedDate = selectedDate.add(const Duration(days: 1));
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, {Color? color}) {
    final cardColor = color ?? Colors.blue;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ColorUtils.withOpacity(cardColor, 0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: cardColor),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: AppColors.white,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: AppColors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.brightGold,
              onPrimary: AppColors.white,
              surface: AppColors.royalPurple,
              onSurface: AppColors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primary,
        title: Text(
          'تصفية المعاينات',
          style: TextStyle(
            color: AppColors.brightGold,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: InspectionStatus.values.map((status) {
            return CheckboxListTile(
              title: Text(
                status.arabicName,
                style: TextStyle(color: AppColors.text),
              ),
              value: true,
              activeColor: AppColors.brightGold,
              onChanged: (bool? value) {
                // تنفيذ التصفية
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: TextStyle(color: AppColors.brightGold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brightGold,
            ),
            onPressed: () {
              // تطبيق التصفية
              Navigator.pop(context);
            },
            child: const Text('تطبيق'),
          ),
        ],
      ),
    );
  }

  void _showAddInspectionDialog() {
    final TextEditingController propertyTitleController = TextEditingController();
    final TextEditingController clientNameController = TextEditingController();
    final TextEditingController clientPhoneController = TextEditingController();
    final TextEditingController locationController = TextEditingController();
    final TextEditingController notesController = TextEditingController();
    DateTime selectedDateTime = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primary,
        title: Text(
          'إضافة معاينة جديدة',
          style: TextStyle(
            color: AppColors.brightGold,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField('عنوان العقار', Icons.home, propertyTitleController),
              const SizedBox(height: 16),
              _buildTextField('اسم العميل', Icons.person, clientNameController),
              const SizedBox(height: 16),
              _buildTextField('رقم الهاتف', Icons.phone, clientPhoneController),
              const SizedBox(height: 16),
              _buildTextField('الموقع', Icons.location_on, locationController),
              const SizedBox(height: 16),
              _buildTextField('ملاحظات', Icons.note, notesController),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  final TimeOfDay? time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null) {
                    selectedDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      time.hour,
                      time.minute,
                    );
                  }
                },
                child: Text(
                  'اختيار الوقت',
                  style: TextStyle(color: AppColors.brightGold),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: TextStyle(color: AppColors.brightGold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brightGold,
            ),
            onPressed: () async {
              if (propertyTitleController.text.isEmpty ||
                  clientNameController.text.isEmpty ||
                  clientPhoneController.text.isEmpty ||
                  locationController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'الرجاء تعبئة جميع الحقول المطلوبة',
                      style: TextStyle(color: AppColors.text),
                    ),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              final newInspection = Inspection(
                id: '',
                propertyTitle: propertyTitleController.text,
                clientName: clientNameController.text,
                clientPhone: clientPhoneController.text,
                dateTime: selectedDateTime,
                location: locationController.text,
                notes: notesController.text,
                status: InspectionStatus.scheduled,
              );

              _addInspection(newInspection);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'تمت إضافة المعاينة بنجاح',
                    style: TextStyle(color: AppColors.text),
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String labelText, IconData icon, TextEditingController controller) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.royalPurple.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.brightGold.withOpacity(0.3),
        ),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: AppColors.text),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(color: AppColors.brightGold),
          prefixIcon: Icon(icon, color: AppColors.brightGold),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }
} 