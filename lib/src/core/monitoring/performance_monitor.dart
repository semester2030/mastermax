import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  bool _isInitialized = false;
  final List<Performance> _performances = [];
  Timer? _cleanupTimer;
  int _totalRequests = 0;

  void initialize() {
    if (_isInitialized) return;
    _startCleanupTimer();
    _isInitialized = true;
  }

  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _cleanOldPerformances();
    });
  }

  void _cleanOldPerformances() {
    final now = DateTime.now();
    _performances.removeWhere((performance) {
      return now.difference(performance.timestamp) > const Duration(days: 1);
    });
  }

  void startMeasurement(String tag) {
    if (!_isInitialized) initialize();
    _performances.add(Performance(tag));
    _totalRequests++;
  }

  void endMeasurement(String tag) {
    if (!_isInitialized) return;
    
    final performance = _performances.lastWhere(
      (p) => p.tag == tag && !p.isCompleted,
      orElse: () => Performance(''),
    );

    if (performance.tag.isNotEmpty) {
      performance.end();
      _logPerformance(performance);
    }
  }

  void _logPerformance(Performance performance) {
    if (kDebugMode) {
      debugPrint(
        'Performance: ${performance.tag} took ${performance.duration.inMilliseconds}ms'
      );
    }
  }

  double getAverageResponseTime() {
    if (_performances.isEmpty) return 0.0;
    
    final completedPerformances = _performances.where((p) => p.isCompleted);
    if (completedPerformances.isEmpty) return 0.0;
    
    final totalTime = completedPerformances
        .map((p) => p.duration.inMilliseconds)
        .reduce((a, b) => a + b);
        
    return totalTime / completedPerformances.length;
  }

  int getTotalRequests() {
    return _totalRequests;
  }

  void dispose() {
    _cleanupTimer?.cancel();
    _performances.clear();
    _totalRequests = 0;
    _isInitialized = false;
  }

  void monitorBuildTime(String tag, VoidCallback callback) {
    startMeasurement('build_$tag');
    callback();
    endMeasurement('build_$tag');
  }

  void monitorAsyncOperation(String tag, Future<void> Function() operation) async {
    startMeasurement('async_$tag');
    await operation();
    endMeasurement('async_$tag');
  }

  void startFrameMonitoring() {
    if (!_isInitialized) initialize();
    
    SchedulerBinding.instance.addTimingsCallback((List<FrameTiming> timings) {
      for (final timing in timings) {
        final buildTime = timing.buildDuration.inMilliseconds;
        final rasterTime = timing.rasterDuration.inMilliseconds;
        final totalTime = buildTime + rasterTime;

        if (kDebugMode) {
          debugPrint('Frame Performance:');
          debugPrint('  Build time: ${buildTime}ms');
          debugPrint('  Raster time: ${rasterTime}ms');
          debugPrint('  Total time: ${totalTime}ms');
        }

        if (totalTime > 16) { // Frame dropped (60 FPS = 16.67ms per frame)
          debugPrint('WARNING: Frame took longer than 16ms to render!');
        }
      }
    });
  }

  List<PerformanceMetrics> getMetrics() {
    if (!_isInitialized) return [];

    final metrics = <PerformanceMetrics>[];
    final groupedPerformances = <String, List<Performance>>{};

    for (final performance in _performances.where((p) => p.isCompleted)) {
      groupedPerformances.putIfAbsent(performance.tag, () => []).add(performance);
    }

    for (final entry in groupedPerformances.entries) {
      final durations = entry.value.map((p) => p.duration.inMilliseconds).toList();
      metrics.add(PerformanceMetrics(
        tag: entry.key,
        averageTime: durations.reduce((a, b) => a + b) / durations.length,
        minTime: durations.reduce(min),
        maxTime: durations.reduce(max),
        count: durations.length,
      ));
    }

    return metrics;
  }
}

class Performance {
  final String tag;
  final DateTime timestamp;
  DateTime? _endTime;
  bool get isCompleted => _endTime != null;

  Performance(this.tag) : timestamp = DateTime.now();

  void end() {
    _endTime = DateTime.now();
  }

  Duration get duration {
    if (!isCompleted) return Duration.zero;
    return _endTime!.difference(timestamp);
  }
}

class PerformanceMetrics {
  final String tag;
  final double averageTime;
  final int minTime;
  final int maxTime;
  final int count;

  PerformanceMetrics({
    required this.tag,
    required this.averageTime,
    required this.minTime,
    required this.maxTime,
    required this.count,
  });
}

int min(int a, int b) => a < b ? a : b;
int max(int a, int b) => a > b ? a : b; 