import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:logger/logger.dart';
import '../models/user_type.dart';
import '../models/business_fields.dart';
import '../services/document_verification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/animations/widget_animations.dart' as custom_animations;
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_brand_logo_header.dart';

class RegisterScreen extends StatefulWidget {
  final UserType userType;

  const RegisterScreen({
    required this.userType, super.key,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final PageController _pageController = PageController();
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final DocumentVerificationService _verificationService = DocumentVerificationService();
  final Logger _logger = Logger();
  bool _isLoading = false;
  bool _obscurePassword = true;
  int _currentPage = 0;
  List<List<BusinessField>> _pages = [];
  File? _verificationDocument; // ✅ ملف PDF الوثائق
  String? _documentFileName; // ✅ اسم الملف للعرض

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _organizeFieldsIntoPages();
  }

  void _initializeControllers() {
    // الحقول الأساسية
    _controllers['name'] = TextEditingController();
    _controllers['email'] = TextEditingController();
    _controllers['phone'] = TextEditingController();
    _controllers['password'] = TextEditingController();

    // الحقول الخاصة بنوع المستخدم
    final fields = BusinessFields.getFieldsByType(widget.userType);
    for (var section in fields.values) {
      for (var field in section) {
        if (!_controllers.containsKey(field.key)) {
          _controllers[field.key] = TextEditingController();
        }
      }
    }
  }

  void _organizeFieldsIntoPages() {
    final allFields = <BusinessField>[];
    
    // إضافة الحقول الأساسية
    allFields.addAll([
      const BusinessField(key: 'name', label: 'الاسم', icon: Icons.person),
      const BusinessField(key: 'email', label: 'البريد الإلكتروني', icon: Icons.email),
      const BusinessField(key: 'phone', label: 'رقم الجوال', icon: Icons.phone),
      const BusinessField(key: 'password', label: 'كلمة المرور', icon: Icons.lock),
    ]);

    // إضافة الحقول الخاصة بنوع المستخدم
    final fields = BusinessFields.getFieldsByType(widget.userType);
    for (var section in fields.values) {
      allFields.addAll(section);
    }

    // تقسيم الحقول إلى صفحات (4 حقول لكل صفحة)
    _pages = [];
    for (int i = 0; i < allFields.length; i += 4) {
      _pages.add(allFields.sublist(i, i + 4 > allFields.length ? allFields.length : i + 4));
    }
    
    // ✅ إذا كان نوع الحساب يحتاج تحقق، نضيف صفحة لرفع الوثائق
    if (widget.userType.requiresVerification) {
      _pages.add([]); // صفحة إضافية للوثائق
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _validateCurrentPage() {
    final currentPageFields = _pages[_currentPage];
    for (var field in currentPageFields) {
      if (field.required) {
        final value = _controllers[field.key]?.text ?? '';
        if (value.isEmpty) {
          return false;
        }
      }
    }
    return true;
  }

  void _nextPage() {
    // ✅ التحقق من صفحة الوثائق
    if (_currentPage == _pages.length - 1 && widget.userType.requiresVerification) {
      // إذا كانت الصفحة الأخيرة وتحتاج تحقق، نتحقق من رفع الملف
      if (_verificationDocument == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الرجاء رفع ملف الوثائق المطلوبة (PDF)'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      _register();
      return;
    }
    
    if (!_validateCurrentPage()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إكمال جميع الحقول المطلوبة'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _register();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// ✅ اختيار ملف PDF للوثائق
  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        if (mounted) {
          setState(() {
            _verificationDocument = file;
            _documentFileName = result.files.single.name;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في اختيار الملف: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final auth = FirebaseAuth.instance;
      final userCredential = await auth.createUserWithEmailAndPassword(
        email: _controllers['email']!.text,
        password: _controllers['password']!.text,
      );

      await userCredential.user?.sendEmailVerification();

      final userData = {
        'name': _controllers['name']!.text,
        'email': _controllers['email']!.text,
        'phone': _controllers['phone']!.text,
        'userType': widget.userType.toString(),
        'createdAt': FieldValue.serverTimestamp(),
        'emailVerified': false,
      };

      // إضافة الحقول الخاصة بنوع المستخدم
      final fields = BusinessFields.getFieldsByType(widget.userType);
      for (var section in fields.values) {
        for (var field in section) {
          userData[field.key] = _controllers[field.key]?.text ?? '';
        }
      }

      final userId = userCredential.user?.uid;
      if (userId == null) {
        throw Exception('فشل في إنشاء الحساب');
      }

      await FirebaseFirestore.instance.collection('users').doc(userId).set(userData);

      // ✅ إذا كان نوع الحساب يحتاج تحقق، نرفع ملف الوثائق
      if (widget.userType.requiresVerification && _verificationDocument != null) {
        _logger.d('📤 Uploading verification document for user: $userId');
        
        final uploadResult = await _verificationService.uploadVerificationDocument(
          userId: userId,
          userType: widget.userType,
          documentFile: _verificationDocument!,
        );

        if (!uploadResult.success) {
          // لا نمنع إنشاء الحساب، لكن نعرض تحذير
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('تم إنشاء الحساب لكن فشل رفع الوثائق: ${uploadResult.error ?? "خطأ غير معروف"}\nيمكنك رفعها لاحقاً من الملف الشخصي'),
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 8),
              ),
            );
          }
        } else {
          _logger.d('✅ Verification document uploaded successfully');
        }
      } else if (widget.userType.requiresVerification && _verificationDocument == null) {
        // إذا كان يحتاج تحقق لكن لم يتم رفع الملف، نعرض تحذير
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إنشاء الحساب. يرجى رفع الوثائق المطلوبة لاحقاً من الملف الشخصي'),
              backgroundColor: AppColors.error,
              duration: Duration(seconds: 6),
            ),
          );
        }
      }

      // ✅ إذا كان نوع الحساب يحتاج تحقق، نرفع ملف الوثائق
      if (widget.userType.requiresVerification && _verificationDocument != null) {
        _logger.d('📤 Uploading verification document for user: $userId');
        
        final uploadResult = await _verificationService.uploadVerificationDocument(
          userId: userId,
          userType: widget.userType,
          documentFile: _verificationDocument!,
        );

        if (!uploadResult.success) {
          // لا نمنع إنشاء الحساب، لكن نعرض تحذير
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('تم إنشاء الحساب لكن فشل رفع الوثائق: ${uploadResult.error ?? "خطأ غير معروف"}\nيمكنك رفعها لاحقاً من الملف الشخصي'),
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 8),
              ),
            );
          }
        } else {
          _logger.d('✅ Verification document uploaded successfully');
        }
      } else if (widget.userType.requiresVerification && _verificationDocument == null) {
        // إذا كان يحتاج تحقق لكن لم يتم رفع الملف، نعرض تحذير
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إنشاء الحساب. يرجى رفع الوثائق المطلوبة لاحقاً من الملف الشخصي'),
              backgroundColor: AppColors.error,
              duration: Duration(seconds: 6),
            ),
          );
        }
      }

      if (!mounted) return;
      
      await auth.signOut();

      if (!mounted) return;
      
      final messenger = ScaffoldMessenger.of(context);
      final email = _controllers['email']!.text;
      
      messenger.showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('تم إنشاء الحساب بنجاح'),
              const SizedBox(height: 8),
              Text(
                'تم إرسال رابط التفعيل إلى بريدك الإلكتروني $email',
                style: const TextStyle(fontSize: 12),
              ),
              const Text(
                'يرجى تفعيل حسابك من خلال الرابط المرسل قبل تسجيل الدخول',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'فهمت',
            textColor: AppColors.white,
            onPressed: () {},
          ),
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/');
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء إنشاء الحساب: ${e.toString()}',
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'إنشاء حساب ${widget.userType.arabicName}',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            AppBrandLogoHeader(
              margin: const EdgeInsets.only(bottom: 16),
            ),
            
            // مؤشر الصفحات
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: List.generate(_pages.length, (index) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 4,
                      decoration: BoxDecoration(
                        color: index <= _currentPage
                            ? AppColors.primary
                            : AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // الصفحات
            Expanded(
              child: Form(
                key: _formKey,
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    // ✅ إذا كانت الصفحة الأخيرة وتحتاج تحقق، نعرض صفحة رفع الوثائق
                    if (index == _pages.length - 1 && widget.userType.requiresVerification) {
                      return _buildDocumentUploadPage();
                    }
                    return _buildPage(_pages[index]);
                  },
                ),
              ),
            ),
            
            // أزرار التنقل
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousPage,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'السابق',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _nextPage,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                              ),
                            )
                          : Text(
                              _currentPage < _pages.length - 1 ? 'التالي' : 'إنشاء الحساب',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildPage(List<BusinessField> fields) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'الصفحة ${_currentPage + 1} من ${_pages.length}',
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ...fields.map((field) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildField(field),
          )),
        ],
      ),
    );
  }

  /// ✅ بناء صفحة رفع الوثائق
  Widget _buildDocumentUploadPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'الصفحة ${_currentPage + 1} من ${_pages.length}',
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // ✅ عنوان الصفحة
          Text(
            'رفع الوثائق المطلوبة',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          
          // ✅ الوثائق المطلوبة
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'الوثائق المطلوبة:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.userType.requiredDocuments,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'يرجى رفع ملف PDF واحد يحتوي على جميع الوثائق المطلوبة',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // ✅ زر اختيار الملف
          InkWell(
            onTap: _pickDocument,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _verificationDocument != null 
                      ? AppColors.success 
                      : AppColors.primary,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _verificationDocument != null 
                        ? Icons.check_circle 
                        : Icons.upload_file,
                    color: _verificationDocument != null 
                        ? AppColors.success 
                        : AppColors.primary,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _verificationDocument != null 
                        ? 'تم اختيار الملف' 
                        : 'اضغط لاختيار ملف PDF',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _verificationDocument != null 
                          ? AppColors.success 
                          : AppColors.textPrimary,
                    ),
                  ),
                  if (_documentFileName != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _documentFileName!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // ✅ تحذير
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'ملاحظة: سيتم مراجعة الوثائق من قبل الفريق. سيتم إشعارك عند الانتهاء.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(BusinessField field) {
    final isPassword = field.key == 'password';
    
    return TextFormField(
      controller: _controllers[field.key],
      obscureText: isPassword ? _obscurePassword : false,
      decoration: InputDecoration(
        labelText: field.label,
        hintText: field.label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.primaryLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.primaryLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
        ),
        prefixIcon: Icon(
          field.icon,
          color: AppColors.primary,
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppColors.primary,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
      ),
      validator: (value) {
        if (field.required && (value == null || value.isEmpty)) {
          return 'هذا الحقل مطلوب';
        }
        if (field.key == 'email' && value != null && !value.contains('@')) {
          return 'الرجاء إدخال بريد إلكتروني صحيح';
        }
        if (field.key == 'phone' && value != null && value.length != 10) {
          return 'رقم الجوال يجب أن يكون 10 أرقام';
        }
        if (field.key == 'password' && value != null && value.length < 6) {
          return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
        }
        return null;
      },
      keyboardType: field.isDate
          ? TextInputType.datetime
          : field.key == 'email'
              ? TextInputType.emailAddress
              : field.key == 'phone'
                  ? TextInputType.phone
                  : TextInputType.text,
    );
  }
}
