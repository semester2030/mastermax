/// طبقة التحقق من صحة المدخلات - منفصلة تماماً عن المنطق الحالي
class AuthValidationLayer {
  static final AuthValidationLayer _instance = AuthValidationLayer._internal();
  factory AuthValidationLayer() => _instance;

  AuthValidationLayer._internal();

  // قواعد التحقق - يمكن تعديلها بسهولة
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  static final RegExp _phoneRegex = RegExp(
    r'^\+?[0-9]{10,}$',
  );
  static final RegExp _passwordRegex = RegExp(
    r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,}$',
  );

  /// التحقق من صحة البريد الإلكتروني - لا يؤثر على المنطق الحالي
  ValidationResult validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return ValidationResult(
        isValid: false,
        message: 'البريد الإلكتروني مطلوب',
      );
    }

    if (!_emailRegex.hasMatch(email)) {
      return ValidationResult(
        isValid: false,
        message: 'البريد الإلكتروني غير صالح',
      );
    }

    return ValidationResult(isValid: true);
  }

  /// التحقق من صحة رقم الهاتف - لا يؤثر على المنطق الحالي
  ValidationResult validatePhone(String? phone) {
    if (phone == null || phone.isEmpty) {
      return ValidationResult(
        isValid: false,
        message: 'رقم الهاتف مطلوب',
      );
    }

    if (!_phoneRegex.hasMatch(phone)) {
      return ValidationResult(
        isValid: false,
        message: 'رقم الهاتف غير صالح',
      );
    }

    return ValidationResult(isValid: true);
  }

  /// التحقق من قوة كلمة المرور - يمكن تفعيله تدريجياً
  ValidationResult validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return ValidationResult(
        isValid: false,
        message: 'كلمة المرور مطلوبة',
      );
    }

    if (!_passwordRegex.hasMatch(password)) {
      return ValidationResult(
        isValid: false,
        message: 'كلمة المرور يجب أن تحتوي على 8 أحرف على الأقل، وحرف واحد ورقم واحد',
      );
    }

    return ValidationResult(isValid: true);
  }

  /// التحقق من تطابق كلمتي المرور - آمن للاستخدام
  ValidationResult validatePasswordMatch(String? password, String? confirmPassword) {
    if (confirmPassword == null || confirmPassword.isEmpty) {
      return ValidationResult(
        isValid: false,
        message: 'تأكيد كلمة المرور مطلوب',
      );
    }

    if (password != confirmPassword) {
      return ValidationResult(
        isValid: false,
        message: 'كلمتا المرور غير متطابقتين',
      );
    }

    return ValidationResult(isValid: true);
  }

  /// التحقق من صحة رمز التحقق - يمكن تفعيله لاحقاً
  ValidationResult validateOTP(String? otp) {
    if (otp == null || otp.isEmpty) {
      return ValidationResult(
        isValid: false,
        message: 'رمز التحقق مطلوب',
      );
    }

    if (otp.length != 6 || !RegExp(r'^\d+$').hasMatch(otp)) {
      return ValidationResult(
        isValid: false,
        message: 'رمز التحقق يجب أن يتكون من 6 أرقام',
      );
    }

    return ValidationResult(isValid: true);
  }
}

/// نتيجة التحقق - كائن بسيط لنقل النتائج
class ValidationResult {
  final bool isValid;
  final String? message;

  ValidationResult({
    required this.isValid,
    this.message,
  });
} 