import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../auth/providers/auth_state.dart';
import '../../auth/models/user_type.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/animations/widget_animations.dart' as custom_animations;
import '../../../core/utils/color_utils.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  File? _profileImage;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  Map<String, dynamic> _userBusinessData = {}; // ✅ بيانات الحساب التجاري من Firestore

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final authState = Provider.of<AuthState>(context, listen: false);
    final user = authState.user;
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (user != null) {
      _nameController.text = user.name;
      _emailController.text = user.email;
    }

    if (firebaseUser != null) {
      // ✅ جلب جميع بيانات المستخدم من Firestore (بما فيها بيانات الحساب التجاري)
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .get();
        
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          _phoneController.text = data['phone'] ?? '';
          
          // ✅ حفظ بيانات الحساب التجاري في state للاستخدام في _buildBusinessProfileSection
          setState(() {
            _userBusinessData = Map<String, dynamic>.from(data);
          });
        }
      } catch (e) {
        debugPrint('Error loading user data: $e');
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000, // ✅ رفع من 800 إلى 2000 للحفاظ على الدقة
        maxHeight: 2000, // ✅ رفع من 800 إلى 2000
        imageQuality: 95, // ✅ رفع الجودة من 85 إلى 95
      );

      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في اختيار الصورة: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2000, // ✅ رفع من 800 إلى 2000
        maxHeight: 2000, // ✅ رفع من 800 إلى 2000
        imageQuality: 95, // ✅ رفع الجودة من 85 إلى 95
      );

      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في التقاط الصورة: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showImageSourceDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر مصدر الصورة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('من المعرض'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('التقاط صورة'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authState = Provider.of<AuthState>(context, listen: false);
      final firebaseUser = FirebaseAuth.instance.currentUser;

      if (firebaseUser == null) {
        throw Exception('المستخدم غير مسجل دخول');
      }

      // تحديث البريد الإلكتروني في Firebase Auth
      if (_emailController.text.trim() != firebaseUser.email) {
        await firebaseUser.updateEmail(_emailController.text.trim());
        await firebaseUser.sendEmailVerification();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحديث البريد الإلكتروني. يرجى التحقق من بريدك الإلكتروني'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }

      // تحديث بيانات المستخدم في Firestore
      final userData = <String, dynamic>{
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_phoneController.text.trim().isNotEmpty) {
        userData['phone'] = _phoneController.text.trim();
      }

      // TODO: رفع الصورة الشخصية إلى Firebase Storage
      // if (_profileImage != null) {
      //   final imageUrl = await _uploadProfileImage(_profileImage!);
      //   userData['profileImage'] = imageUrl;
      // }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .update(userData);

      // تحديث AuthState
      final updatedUser = authState.user?.copyWith(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
      );
      
      if (updatedUser != null) {
        authState.setAuthenticated(updatedUser);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث الملف الشخصي بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحديث الملف الشخصي: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _changePassword() async {
    if (_oldPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى ملء جميع الحقول'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('كلمة المرور الجديدة غير متطابقة'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_newPasswordController.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('كلمة المرور يجب أن تكون 8 أحرف على الأقل'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        throw Exception('المستخدم غير مسجل دخول');
      }

      // إعادة المصادقة قبل تغيير كلمة المرور
      final credential = EmailAuthProvider.credential(
        email: firebaseUser.email!,
        password: _oldPasswordController.text,
      );

      await firebaseUser.reauthenticateWithCredential(credential);
      await firebaseUser.updatePassword(_newPasswordController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تغيير كلمة المرور بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
        
        // مسح الحقول
        _oldPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
    } catch (e) {
      String errorMessage = 'خطأ في تغيير كلمة المرور';
      
      if (e.toString().contains('wrong-password')) {
        errorMessage = 'كلمة المرور الحالية غير صحيحة';
      } else if (e.toString().contains('weak-password')) {
        errorMessage = 'كلمة المرور ضعيفة جداً';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// ✅ تحديد ما إذا كان المستخدم حسابًا تجاريًا (شركة عقارية / معرض سيارات / وسيط عقاري / تاجر سيارات)
  bool _isBusinessUser(UserType type) {
    return type == UserType.realEstateCompany ||
        type == UserType.carDealer ||
        type == UserType.realEstateAgent ||
        type == UserType.carTrader;
  }

  /// ✅ قسم يعرض معلومات الحساب التجاري بشكل منظم - يقرأ من Firestore مباشرة
  Widget _buildBusinessProfileSection(UserType userType, dynamic user) {
    // ✅ استخدام البيانات المحملة من Firestore مباشرة
    final data = _userBusinessData;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColorUtils.withOpacity(AppColors.primary, 0.03),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: ColorUtils.withOpacity(AppColors.primary, 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'بيانات الحساب التجاري',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'نوع الحساب: ${userType.arabicName}',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          // ✅ معارض السيارات (carDealer)
          if (userType == UserType.carDealer) ...[
            if (data['dealershipName'] != null && (data['dealershipName'] as String).isNotEmpty)
              _buildBusinessInfoRow('اسم المعرض', data['dealershipName'] as String),
            if (data['commercialRegister'] != null && (data['commercialRegister'] as String).isNotEmpty)
              _buildBusinessInfoRow('رقم السجل التجاري', data['commercialRegister'] as String),
            if (data['commercialRegisterExpiry'] != null && (data['commercialRegisterExpiry'] as String).isNotEmpty)
              _buildBusinessInfoRow('تاريخ انتهاء السجل التجاري', data['commercialRegisterExpiry'] as String),
            if (data['municipalLicense'] != null && (data['municipalLicense'] as String).isNotEmpty)
              _buildBusinessInfoRow('رقم رخصة البلدية', data['municipalLicense'] as String),
            if (data['municipalLicenseExpiry'] != null && (data['municipalLicenseExpiry'] as String).isNotEmpty)
              _buildBusinessInfoRow('تاريخ انتهاء رخصة البلدية', data['municipalLicenseExpiry'] as String),
            if (data['showroomPhone'] != null && (data['showroomPhone'] as String).isNotEmpty)
              _buildBusinessInfoRow('رقم هاتف المعرض', data['showroomPhone'] as String),
            if (data['showroomAddress'] != null && (data['showroomAddress'] as String).isNotEmpty)
              _buildBusinessInfoRow('عنوان المعرض', data['showroomAddress'] as String),
            if (data['website'] != null && (data['website'] as String).isNotEmpty)
              _buildBusinessInfoRow('الموقع الإلكتروني', data['website'] as String),
          ]
          // ✅ تجار السيارات (carTrader)
          else if (userType == UserType.carTrader) ...[
            if (data['tradeLicense'] != null && (data['tradeLicense'] as String).isNotEmpty)
              _buildBusinessInfoRow('رقم رخصة تجارة السيارات', data['tradeLicense'] as String),
            if (data['tradeLicenseExpiry'] != null && (data['tradeLicenseExpiry'] as String).isNotEmpty)
              _buildBusinessInfoRow('تاريخ انتهاء الرخصة', data['tradeLicenseExpiry'] as String),
            if (data['nationalId'] != null && (data['nationalId'] as String).isNotEmpty)
              _buildBusinessInfoRow('رقم الهوية/الإقامة', data['nationalId'] as String),
            if (data['officeAddress'] != null && (data['officeAddress'] as String).isNotEmpty)
              _buildBusinessInfoRow('عنوان المعرض', data['officeAddress'] as String),
            if (data['website'] != null && (data['website'] as String).isNotEmpty)
              _buildBusinessInfoRow('الموقع الإلكتروني', data['website'] as String),
          ]
          // ✅ الشركات العقارية (realEstateCompany)
          else if (userType == UserType.realEstateCompany) ...[
            if (data['companyName'] != null && (data['companyName'] as String).isNotEmpty)
              _buildBusinessInfoRow('اسم الشركة', data['companyName'] as String),
            if (data['commercialRegister'] != null && (data['commercialRegister'] as String).isNotEmpty)
              _buildBusinessInfoRow('رقم السجل التجاري', data['commercialRegister'] as String),
            if (data['commercialRegisterExpiry'] != null && (data['commercialRegisterExpiry'] as String).isNotEmpty)
              _buildBusinessInfoRow('تاريخ انتهاء السجل التجاري', data['commercialRegisterExpiry'] as String),
            if (data['licenseNumber'] != null && (data['licenseNumber'] as String).isNotEmpty)
              _buildBusinessInfoRow('رقم الترخيص العقاري', data['licenseNumber'] as String),
            if (data['licenseExpiry'] != null && (data['licenseExpiry'] as String).isNotEmpty)
              _buildBusinessInfoRow('تاريخ انتهاء الترخيص', data['licenseExpiry'] as String),
            if (data['officePhone'] != null && (data['officePhone'] as String).isNotEmpty)
              _buildBusinessInfoRow('رقم الهاتف المكتبي', data['officePhone'] as String),
            if (data['address'] != null && (data['address'] as String).isNotEmpty)
              _buildBusinessInfoRow('عنوان المكتب', data['address'] as String),
            if (data['website'] != null && (data['website'] as String).isNotEmpty)
              _buildBusinessInfoRow('الموقع الإلكتروني', data['website'] as String),
          ]
          // ✅ الوسطاء العقاريين (realEstateAgent)
          else if (userType == UserType.realEstateAgent) ...[
            if (data['agentLicense'] != null && (data['agentLicense'] as String).isNotEmpty)
              _buildBusinessInfoRow('رقم رخصة الوساطة العقارية', data['agentLicense'] as String),
            if (data['agentLicenseExpiry'] != null && (data['agentLicenseExpiry'] as String).isNotEmpty)
              _buildBusinessInfoRow('تاريخ انتهاء الرخصة', data['agentLicenseExpiry'] as String),
            if (data['nationalId'] != null && (data['nationalId'] as String).isNotEmpty)
              _buildBusinessInfoRow('رقم الهوية/الإقامة', data['nationalId'] as String),
            if (data['officeAddress'] != null && (data['officeAddress'] as String).isNotEmpty)
              _buildBusinessInfoRow('عنوان المكتب', data['officeAddress'] as String),
            if (data['website'] != null && (data['website'] as String).isNotEmpty)
              _buildBusinessInfoRow('الموقع الإلكتروني', data['website'] as String),
          ],
          const SizedBox(height: 8),
          const Text(
            'في حال وجود خطأ في بيانات السجل التجاري أو الترخيص، يرجى التواصل مع فريق الدعم لتحديثها حفاظًا على موثوقية الحساب.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textLight,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = Provider.of<AuthState>(context);
    final user = authState.user;
    final userType = user?.type ?? authState.userType;
    final firebaseUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
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
          'تعديل الملف الشخصي',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // الصورة الشخصية
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: ColorUtils.withOpacity(AppColors.primary, 0.1),
                      backgroundImage: _profileImage != null
                          ? FileImage(_profileImage!)
                          : (user?.extraData?['profileImage'] != null
                              ? NetworkImage(user!.extraData!['profileImage'] as String)
                              : null) as ImageProvider?,
                      child: _profileImage == null &&
                              (user?.extraData?['profileImage'] == null)
                          ? const Icon(
                              Icons.person,
                              size: 60,
                              color: AppColors.primary,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.white,
                            width: 2,
                          ),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, color: AppColors.white, size: 20),
                          onPressed: _showImageSourceDialog,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // الاسم
              _buildTextField(
                controller: _nameController,
                label: 'الاسم',
                icon: Icons.person,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال الاسم';
                  }
                  if (value.length < 3) {
                    return 'الاسم يجب أن يكون 3 أحرف على الأقل';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // البريد الإلكتروني
              _buildTextField(
                controller: _emailController,
                label: 'البريد الإلكتروني',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال البريد الإلكتروني';
                  }
                  if (!value.contains('@')) {
                    return 'البريد الإلكتروني غير صالح';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // رقم الهاتف
              _buildTextField(
                controller: _phoneController,
                label: 'رقم الهاتف (اختياري)',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),

              // ✅ قسم معلومات الحساب التجاري (للشركات والمعارض والوسطاء فقط)
              if (_isBusinessUser(userType)) ...[
                _buildBusinessProfileSection(userType, user),
                const SizedBox(height: 24),
              ],

              // زر حفظ التغييرات
              custom_animations.AnimatedScale(
                onTap: _isLoading ? null : _updateProfile,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: _isLoading
                        ? const CircularProgressIndicator(color: AppColors.white)
                        : const Text(
                            'حفظ التغييرات',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // قسم تغيير كلمة المرور
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ColorUtils.withOpacity(AppColors.primary, 0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: ColorUtils.withOpacity(AppColors.primary, 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تغيير كلمة المرور',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildPasswordField(
                      controller: _oldPasswordController,
                      label: 'كلمة المرور الحالية',
                      icon: Icons.lock,
                      isVisible: _isPasswordVisible,
                      onToggleVisibility: () {
                        setState(() => _isPasswordVisible = !_isPasswordVisible);
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildPasswordField(
                      controller: _newPasswordController,
                      label: 'كلمة المرور الجديدة',
                      icon: Icons.lock_outline,
                      isVisible: _isNewPasswordVisible,
                      onToggleVisibility: () {
                        setState(() => _isNewPasswordVisible = !_isNewPasswordVisible);
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildPasswordField(
                      controller: _confirmPasswordController,
                      label: 'تأكيد كلمة المرور الجديدة',
                      icon: Icons.lock_outline,
                      isVisible: _isConfirmPasswordVisible,
                      onToggleVisibility: () {
                        setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible);
                      },
                    ),
                    const SizedBox(height: 16),
                    custom_animations.AnimatedScale(
                      onTap: _isLoading ? null : _changePassword,
                      child: Container(
                        height: 45,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: _isLoading
                              ? const CircularProgressIndicator(color: AppColors.white)
                              : const Text(
                                  'تغيير كلمة المرور',
                                  style: TextStyle(
                                    color: AppColors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: ColorUtils.withOpacity(AppColors.primary, 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: ColorUtils.withOpacity(AppColors.primary, 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !isVisible,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        suffixIcon: IconButton(
          icon: Icon(
            isVisible ? Icons.visibility : Icons.visibility_off,
            color: AppColors.primary,
          ),
          onPressed: onToggleVisibility,
        ),
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: ColorUtils.withOpacity(AppColors.primary, 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: ColorUtils.withOpacity(AppColors.primary, 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}

