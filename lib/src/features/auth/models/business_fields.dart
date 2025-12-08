import 'package:flutter/material.dart';
import 'user_type.dart';

class BusinessFields {
  static Map<String, List<BusinessField>> getFieldsByType(UserType type) {
    switch (type) {
      case UserType.realEstateCompany:
        return const {
          'معلومات الشركة': [
            BusinessField(
              key: 'commercialRegister',
              label: 'رقم السجل التجاري',
              icon: Icons.numbers,
            ),
            BusinessField(
              key: 'commercialRegisterExpiry',
              label: 'تاريخ انتهاء السجل التجاري',
              icon: Icons.calendar_today,
              isDate: true,
            ),
            BusinessField(
              key: 'companyName',
              label: 'اسم الشركة',
              icon: Icons.business,
            ),
            BusinessField(
              key: 'licenseNumber',
              label: 'رقم الترخيص العقاري',
              icon: Icons.badge,
            ),
            BusinessField(
              key: 'licenseExpiry',
              label: 'تاريخ انتهاء الترخيص',
              icon: Icons.calendar_today,
              isDate: true,
            ),
          ],
          'معلومات التواصل': [
            BusinessField(
              key: 'officePhone',
              label: 'رقم الهاتف المكتبي',
              icon: Icons.phone,
            ),
            BusinessField(
              key: 'address',
              label: 'عنوان المكتب',
              icon: Icons.location_on,
            ),
            BusinessField(
              key: 'website',
              label: 'الموقع الإلكتروني',
              icon: Icons.web,
              required: false,
            ),
          ],
        };

      case UserType.carDealer:
        return const {
          'معلومات المعرض': [
            BusinessField(
              key: 'commercialRegister',
              label: 'رقم السجل التجاري',
              icon: Icons.numbers,
            ),
            BusinessField(
              key: 'commercialRegisterExpiry',
              label: 'تاريخ انتهاء السجل التجاري',
              icon: Icons.calendar_today,
              isDate: true,
            ),
            BusinessField(
              key: 'dealershipName',
              label: 'اسم المعرض',
              icon: Icons.store,
            ),
            BusinessField(
              key: 'municipalLicense',
              label: 'رقم رخصة البلدية',
              icon: Icons.badge,
            ),
            BusinessField(
              key: 'municipalLicenseExpiry',
              label: 'تاريخ انتهاء رخصة البلدية',
              icon: Icons.calendar_today,
              isDate: true,
            ),
          ],
          'معلومات التواصل': [
            BusinessField(
              key: 'showroomPhone',
              label: 'رقم هاتف المعرض',
              icon: Icons.phone,
            ),
            BusinessField(
              key: 'showroomAddress',
              label: 'عنوان المعرض',
              icon: Icons.location_on,
            ),
            BusinessField(
              key: 'website',
              label: 'الموقع الإلكتروني',
              icon: Icons.web,
              required: false,
            ),
          ],
        };

      case UserType.realEstateAgent:
        return const {
          'معلومات الوسيط': [
            BusinessField(
              key: 'agentLicense',
              label: 'رقم رخصة الوساطة العقارية',
              icon: Icons.badge,
            ),
            BusinessField(
              key: 'agentLicenseExpiry',
              label: 'تاريخ انتهاء الرخصة',
              icon: Icons.calendar_today,
              isDate: true,
            ),
            BusinessField(
              key: 'nationalId',
              label: 'رقم الهوية/الإقامة',
              icon: Icons.credit_card,
            ),
          ],
          'معلومات التواصل': [
            BusinessField(
              key: 'officeAddress',
              label: 'عنوان المكتب (إن وجد)',
              icon: Icons.location_on,
              required: false,
            ),
            BusinessField(
              key: 'website',
              label: 'الموقع الإلكتروني',
              icon: Icons.web,
              required: false,
            ),
          ],
        };

      case UserType.carTrader:
        return const {
          'معلومات التاجر': [
            BusinessField(
              key: 'tradeLicense',
              label: 'رقم رخصة تجارة السيارات',
              icon: Icons.badge,
            ),
            BusinessField(
              key: 'tradeLicenseExpiry',
              label: 'تاريخ انتهاء الرخصة',
              icon: Icons.calendar_today,
              isDate: true,
            ),
            BusinessField(
              key: 'nationalId',
              label: 'رقم الهوية/الإقامة',
              icon: Icons.credit_card,
            ),
          ],
          'معلومات التواصل': [
            BusinessField(
              key: 'officeAddress',
              label: 'عنوان المعرض (إن وجد)',
              icon: Icons.location_on,
              required: false,
            ),
            BusinessField(
              key: 'website',
              label: 'الموقع الإلكتروني',
              icon: Icons.web,
              required: false,
            ),
          ],
        };

      default:
        return const {};
    }
  }
}

class BusinessField {
  final String key;
  final String label;
  final IconData icon;
  final bool required;
  final bool isDate;

  const BusinessField({
    required this.key,
    required this.label,
    required this.icon,
    this.required = true,
    this.isDate = false,
  });
} 