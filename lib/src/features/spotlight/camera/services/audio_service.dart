import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _currentRecordingPath;

  Future<bool> hasPermission() async {
    return await _audioRecorder.hasPermission();
  }

  Future<void> init() async {
    if (await _audioRecorder.hasPermission()) {
      // Initialize
    }
  }

  Future<String?> recordAudio() async {
    if (await _audioRecorder.isRecording()) {
      return null;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      _currentRecordingPath = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          
        ),
        path: _currentRecordingPath!,
      );

      // Record for 3 seconds (adjust as needed)
      await Future.delayed(const Duration(seconds: 3));
      await stopRecording();

      return _currentRecordingPath;
    } catch (e) {
      debugPrint('Error recording audio: $e');
      return null;
    }
  }

  Future<void> stopRecording() async {
    try {
      await _audioRecorder.stop();
    } catch (e) {
      debugPrint('Error stopping audio recording: $e');
    }
  }

  Future<void> deleteRecording() async {
    if (_currentRecordingPath != null) {
      final file = File(_currentRecordingPath!);
      if (await file.exists()) {
        await file.delete();
      }
      _currentRecordingPath = null;
    }
  }

  Future<Duration?> getRecordingDuration() async {
    if (_currentRecordingPath == null) return null;

    final file = File(_currentRecordingPath!);
    if (!await file.exists()) return null;

    // In a real implementation, you would get the actual duration
    // This is just a placeholder
    return const Duration(seconds: 3);
  }

  Future<void> dispose() async {
    await _audioRecorder.dispose();
  }
} 