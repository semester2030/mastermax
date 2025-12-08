import 'package:flutter/material.dart';
import '../../../utils/firebase_data_transfer.dart';

class DataTransferScreen extends StatefulWidget {
  const DataTransferScreen({super.key});

  @override
  State<DataTransferScreen> createState() => _DataTransferScreenState();
}

class _DataTransferScreenState extends State<DataTransferScreen> {
  bool _isTransferring = false;
  String _status = '';

  Future<void> _startTransfer() async {
    if (_isTransferring) return;

    setState(() {
      _isTransferring = true;
      _status = 'جاري بدء عملية النقل...';
    });

    try {
      await FirebaseDataTransfer.startTransfer();
      setState(() {
        _status = 'تم نقل البيانات بنجاح! 🎉';
      });
    } catch (e) {
      setState(() {
        _status = 'حدث خطأ أثناء النقل: $e';
      });
    } finally {
      setState(() {
        _isTransferring = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نقل البيانات'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _isTransferring ? null : _startTransfer,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 15,
                  ),
                ),
                child: _isTransferring
                    ? const CircularProgressIndicator()
                    : Text(
                        'بدء نقل البيانات',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
              ),
              const SizedBox(height: 20),
              if (_status.isNotEmpty)
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
            ],
          ),
        ),
      ),
    );
  }
} 