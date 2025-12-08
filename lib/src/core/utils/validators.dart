/// التحقق من صحة البريد الإلكتروني
String? validateEmail(String? value) {
  if (value == null || value.isEmpty) {
    return 'الرجاء إدخال البريد الإلكتروني';
  }
  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  if (!emailRegex.hasMatch(value)) {
    return 'الرجاء إدخال بريد إلكتروني صحيح';
  }
  return null;
}

/// التحقق من صحة رقم الهاتف
String? validatePhone(String? value) {
  if (value == null || value.isEmpty) {
    return 'الرجاء إدخال رقم الهاتف';
  }
  final phoneRegex = RegExp(r'^(05|5)(5|0|3|6|4|9|1|8|7)([0-9]{7})$');
  if (!phoneRegex.hasMatch(value)) {
    return 'الرجاء إدخال رقم هاتف سعودي صحيح';
  }
  return null;
}

/// التحقق من صحة كلمة المرور
String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'الرجاء إدخال كلمة المرور';
  }
  if (value.length < 8) {
    return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
  }
  if (!value.contains(RegExp(r'[A-Z]'))) {
    return 'كلمة المرور يجب أن تحتوي على حرف كبير واحد على الأقل';
  }
  if (!value.contains(RegExp(r'[a-z]'))) {
    return 'كلمة المرور يجب أن تحتوي على حرف صغير واحد على الأقل';
  }
  if (!value.contains(RegExp(r'[0-9]'))) {
    return 'كلمة المرور يجب أن تحتوي على رقم واحد على الأقل';
  }
  return null;
}

/// التحقق من صحة الاسم
String? validateName(String? value) {
  if (value == null || value.isEmpty) {
    return 'الرجاء إدخال الاسم';
  }
  if (value.length < 3) {
    return 'الاسم يجب أن يكون 3 أحرف على الأقل';
  }
  return null;
}

/// التحقق من صحة السعر
String? validatePrice(String? value) {
  if (value == null || value.isEmpty) {
    return 'الرجاء إدخال السعر';
  }
  final price = double.tryParse(value);
  if (price == null || price <= 0) {
    return 'الرجاء إدخال سعر صحيح';
  }
  return null;
}

/// التحقق من صحة العنوان
String? validateAddress(String? value) {
  if (value == null || value.isEmpty) {
    return 'الرجاء إدخال العنوان';
  }
  if (value.length < 10) {
    return 'العنوان يجب أن يكون 10 أحرف على الأقل';
  }
  return null;
}

/// التحقق من صحة الوصف
String? validateDescription(String? value) {
  if (value == null || value.isEmpty) {
    return 'الرجاء إدخال الوصف';
  }
  if (value.length < 20) {
    return 'الوصف يجب أن يكون 20 حرف على الأقل';
  }
  return null;
} 