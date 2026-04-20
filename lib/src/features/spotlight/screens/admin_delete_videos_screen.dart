import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/admin_video_delete_service.dart';
import '../../../core/theme/app_colors.dart';

/// شاشة إدارية لحذف الفيديوهات
class AdminDeleteVideosScreen extends StatefulWidget {
  const AdminDeleteVideosScreen({super.key});

  @override
  State<AdminDeleteVideosScreen> createState() => _AdminDeleteVideosScreenState();
}

class _AdminDeleteVideosScreenState extends State<AdminDeleteVideosScreen> {
  final AdminVideoDeleteService _deleteService = AdminVideoDeleteService();
  List<VideoInfo> _videos = [];
  List<VideoInfo> _filteredVideos = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String? _selectedType; // 'car' or 'realEstate'
  final Set<String> _selectedVideoIds = {};

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final videos = await _deleteService.getAllVideos();
      setState(() {
        _videos = videos;
        _filteredVideos = videos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'فشل في تحميل الفيديوهات: $e';
        _isLoading = false;
      });
    }
  }

  void _filterVideos() {
    setState(() {
      _filteredVideos = _videos.where((video) {
        // تصفية حسب النوع
        if (_selectedType != null && video.type != _selectedType) {
          return false;
        }
        
        // تصفية حسب البحث
        if (_searchQuery.isNotEmpty) {
          return video.title.toLowerCase().contains(_searchQuery.toLowerCase());
        }
        
        return true;
      }).toList();
    });
  }

  Future<void> _deleteVideo(VideoInfo video) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف الفيديو:\n"${video.title}"؟\n\nلا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // عرض loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final result = await _deleteService.forceDeleteVideo(video.id);

    if (!mounted) return;
    Navigator.pop(context); // إغلاق loading

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حذف الفيديو بنجاح من: ${result.deletedFrom?.join(', ') ?? 'Firestore'}'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadVideos(); // إعادة تحميل القائمة
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في حذف الفيديو: ${result.error ?? 'خطأ غير معروف'}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _deleteSelectedVideos() async {
    if (_selectedVideoIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار فيديوهات للحذف'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف الجماعي'),
        content: Text('هل أنت متأكد من حذف ${_selectedVideoIds.length} فيديو؟\n\nلا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('حذف الكل'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // عرض loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final result = await _deleteService.deleteMultipleVideos(_selectedVideoIds.toList());

    if (!mounted) return;
    Navigator.pop(context); // إغلاق loading

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم حذف ${result.successful} من ${result.total} فيديو'),
        backgroundColor: result.failed == 0 ? AppColors.success : AppColors.error,
      ),
    );

    _selectedVideoIds.clear();
    _loadVideos(); // إعادة تحميل القائمة
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حذف الفيديوهات (إداري)'),
        actions: [
          if (_selectedVideoIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _deleteSelectedVideos,
              tooltip: 'حذف المحدد (${_selectedVideoIds.length})',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVideos,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث والتصفية
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'بحث',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                    _filterVideos();
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'النوع',
                          border: OutlineInputBorder(),
                        ),
                        value: _selectedType,
                        items: const [
                          DropdownMenuItem(value: null, child: Text('الكل')),
                          DropdownMenuItem(value: 'car', child: Text('سيارات')),
                          DropdownMenuItem(value: 'realEstate', child: Text('عقارات')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value;
                          });
                          _filterVideos();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text('${_filteredVideos.length} فيديو'),
                  ],
                ),
              ],
            ),
          ),

          // قائمة الفيديوهات
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _error!,
                              style: const TextStyle(color: AppColors.error),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadVideos,
                              child: const Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      )
                    : _filteredVideos.isEmpty
                        ? const Center(
                            child: Text('لا توجد فيديوهات'),
                          )
                        : ListView.builder(
                            itemCount: _filteredVideos.length,
                            itemBuilder: (context, index) {
                              final video = _filteredVideos[index];
                              final isSelected = _selectedVideoIds.contains(video.id);

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: ListTile(
                                  leading: Checkbox(
                                    value: isSelected,
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedVideoIds.add(video.id);
                                        } else {
                                          _selectedVideoIds.remove(video.id);
                                        }
                                      });
                                    },
                                  ),
                                  title: Text(
                                    video.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('النوع: ${video.typeDisplay}'),
                                      Text('المصدر: ${video.isCloudflare ? 'Cloudflare' : 'Firebase'}'),
                                      Text('التاريخ: ${video.createdAt.toString().substring(0, 10)}'),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: AppColors.error),
                                    onPressed: () => _deleteVideo(video),
                                    tooltip: 'حذف',
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
