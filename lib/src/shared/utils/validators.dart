
class Validators {
  static String? required(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return 'يرجى إدخال $fieldName';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'يرجى إدخال البريد الإلكتروني';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'يرجى إدخال بريد إلكتروني صحيح';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.isEmpty) {
      return 'يرجى إدخال رقم الجوال';
    }
    if (!RegExp(r'^(05)[0-9]{8}$').hasMatch(value)) {
      return 'يرجى إدخال رقم جوال صحيح';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'يرجى إدخال كلمة المرور';
    }
    if (value.length < 6) {
      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'يرجى تأكيد كلمة المرور';
    }
    if (value != password) {
      return 'كلمة المرور غير متطابقة';
    }
    return null;
  }

  static String? number(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return 'يرجى إدخال $fieldName';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'يرجى إدخال أرقام فقط';
    }
    return null;
  }

  static String? decimal(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return 'يرجى إدخال $fieldName';
    }
    if (!RegExp(r'^\d*\.?\d+$').hasMatch(value)) {
      return 'يرجى إدخال رقم صحيح';
    }
    return null;
  }

  static String? minLength(String? value, String fieldName, int minLength) {
    if (value == null || value.isEmpty) {
      return 'يرجى إدخال $fieldName';
    }
    if (value.length < minLength) {
      return '$fieldName يجب أن يكون $minLength أحرف على الأقل';
    }
    return null;
  }

  static String? maxLength(String? value, String fieldName, int maxLength) {
    if (value == null || value.isEmpty) {
      return 'يرجى إدخال $fieldName';
    }
    if (value.length > maxLength) {
      return '$fieldName يجب أن لا يتجاوز $maxLength حرف';
    }
    return null;
  }

  static String? url(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    if (!Uri.parse(value).isAbsolute) {
      return 'يرجى إدخال رابط صحيح';
    }
    return null;
  }
} 