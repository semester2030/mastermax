import 'package:flutter/foundation.dart';
import '../errors/error_handler.dart';
import 'analytics_tracker.dart';

class ChangeAnalyticsService {
  static final ChangeAnalyticsService _instance = ChangeAnalyticsService._internal();
  factory ChangeAnalyticsService() => _instance;
  ChangeAnalyticsService._internal();

  final Map<String, List<ChangeRecord>> _changeHistory = {};
  final Map<String, PerformanceMetrics> _performanceMetrics = {};
  
  void trackChange({
    required String feature,
    required String action,
    required String entityType,
    String? entityId,
    Map<String, dynamic>? metadata,
    Duration? executionTime,
  }) {
    try {
      final timestamp = DateTime.now();
      final change = ChangeRecord(
        feature: feature,
        action: action,
        entityType: entityType,
        entityId: entityId,
        metadata: metadata,
        timestamp: timestamp,
        executionTime: executionTime,
      );
      
      // Add to history
      _changeHistory[feature] = _changeHistory[feature] ?? [];
      _changeHistory[feature]!.add(change);
      
      // Update performance metrics
      _updatePerformanceMetrics(feature, change);
      
      // Log to analytics
      _logToAnalytics(change);
      
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to track change',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Map<String, dynamic> getChangeAnalytics({String? feature}) {
    try {
      if (feature != null) {
        return _getFeatureAnalytics(feature);
      }
      
      return {
        'overallMetrics': _getOverallMetrics(),
        'featureMetrics': _getAllFeatureMetrics(),
        'recentChanges': _getRecentChanges(),
        'performanceInsights': _getPerformanceInsights(),
      };
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to get change analytics',
        error: e,
        stackTrace: stackTrace,
      );
      return {'error': 'Failed to get analytics'};
    }
  }

  Map<String, dynamic> _getFeatureAnalytics(String feature) {
    final changes = _changeHistory[feature] ?? [];
    final metrics = _performanceMetrics[feature];
    
    return {
      'totalChanges': changes.length,
      'lastChange': changes.isNotEmpty ? changes.last.toMap() : null,
      'changesByType': _groupChangesByType(changes),
      'performanceMetrics': metrics?.toMap(),
      'recentChanges': changes.take(10).map((c) => c.toMap()).toList(),
    };
  }

  Map<String, dynamic> _getOverallMetrics() {
    int totalChanges = 0;
    final changesByFeature = <String, int>{};
    final changesByType = <String, int>{};
    
    _changeHistory.forEach((feature, changes) {
      totalChanges += changes.length;
      changesByFeature[feature] = changes.length;
      
      for (final change in changes) {
        changesByType[change.entityType] = 
            (changesByType[change.entityType] ?? 0) + 1;
      }
    });
    
    return {
      'totalChanges': totalChanges,
      'changesByFeature': changesByFeature,
      'changesByType': changesByType,
      'activeFeatures': _changeHistory.keys.length,
    };
  }

  Map<String, List<Map<String, dynamic>>> _getAllFeatureMetrics() {
    final metrics = <String, List<Map<String, dynamic>>>{};
    
    _changeHistory.forEach((feature, changes) {
      metrics[feature] = _analyzeFeatureChanges(changes);
    });
    
    return metrics;
  }

  List<Map<String, dynamic>> _analyzeFeatureChanges(List<ChangeRecord> changes) {
    final hourlyChanges = <String, int>{};
    final dailyChanges = <String, int>{};
    
    for (final change in changes) {
      final hour = change.timestamp.hour.toString().padLeft(2, '0');
      final day = change.timestamp.day.toString().padLeft(2, '0');
      
      hourlyChanges[hour] = (hourlyChanges[hour] ?? 0) + 1;
      dailyChanges[day] = (dailyChanges[day] ?? 0) + 1;
    }
    
    return [
      {'type': 'hourly', 'data': hourlyChanges},
      {'type': 'daily', 'data': dailyChanges},
    ];
  }

  List<Map<String, dynamic>> _getRecentChanges() {
    final allChanges = <ChangeRecord>[];
    
    _changeHistory.forEach((_, changes) {
      allChanges.addAll(changes);
    });
    
    allChanges.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    return allChanges.take(20).map((c) => c.toMap()).toList();
  }

  Map<String, dynamic> _getPerformanceInsights() {
    if (_performanceMetrics.isEmpty) {
      return {'noData': true};
    }
    
    final insights = <String, dynamic>{};
    
    _performanceMetrics.forEach((feature, metrics) {
      insights[feature] = {
        'averageExecutionTime': metrics.averageExecutionTime,
        'successRate': metrics.successRate,
        'errorRate': metrics.errorRate,
        'totalOperations': metrics.totalOperations,
      };
    });
    
    return insights;
  }

  Map<String, int> _groupChangesByType(List<ChangeRecord> changes) {
    final grouped = <String, int>{};
    
    for (final change in changes) {
      grouped[change.entityType] = (grouped[change.entityType] ?? 0) + 1;
    }
    
    return grouped;
  }

  void _updatePerformanceMetrics(String feature, ChangeRecord change) {
    _performanceMetrics[feature] = _performanceMetrics[feature] ?? PerformanceMetrics();
    final metrics = _performanceMetrics[feature]!;
    
    metrics.totalOperations++;
    
    if (change.executionTime != null) {
      metrics.addExecutionTime(change.executionTime!);
    }
    
    if (change.metadata?['error'] != null) {
      metrics.errors++;
    } else {
      metrics.successes++;
    }
  }

  void _logToAnalytics(ChangeRecord change) {
    if (!kDebugMode) {
      AnalyticsTracker().trackEvent(
        'feature_change',
        parameters: change.toMap(),
      );
    }
  }

  void clearHistory([String? feature]) {
    if (feature != null) {
      _changeHistory.remove(feature);
      _performanceMetrics.remove(feature);
    } else {
      _changeHistory.clear();
      _performanceMetrics.clear();
    }
  }
}

class ChangeRecord {
  final String feature;
  final String action;
  final String entityType;
  final String? entityId;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;
  final Duration? executionTime;

  ChangeRecord({
    required this.feature,
    required this.action,
    required this.entityType,
    required this.timestamp, this.entityId,
    this.metadata,
    this.executionTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'feature': feature,
      'action': action,
      'entityType': entityType,
      'entityId': entityId,
      'metadata': metadata,
      'timestamp': timestamp.toIso8601String(),
      'executionTime': executionTime?.inMilliseconds,
    };
  }
}

class PerformanceMetrics {
  int totalOperations = 0;
  int successes = 0;
  int errors = 0;
  final List<Duration> _executionTimes = [];

  void addExecutionTime(Duration time) {
    _executionTimes.add(time);
  }

  double get averageExecutionTime {
    if (_executionTimes.isEmpty) return 0;
    final total = _executionTimes.fold<int>(
      0, (sum, time) => sum + time.inMilliseconds);
    return total / _executionTimes.length;
  }

  double get successRate => 
      totalOperations > 0 ? successes / totalOperations : 0;

  double get errorRate => 
      totalOperations > 0 ? errors / totalOperations : 0;

  Map<String, dynamic> toMap() {
    return {
      'totalOperations': totalOperations,
      'successes': successes,
      'errors': errors,
      'averageExecutionTime': averageExecutionTime,
      'successRate': successRate,
      'errorRate': errorRate,
    };
  }
} 