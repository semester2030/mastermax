import 'package:flutter/foundation.dart';

class LazyLoader<T> {
  final Future<List<T>> Function(int page, int limit) loadData;
  final int limit;
  final bool Function(List<T>)? hasMoreData;

  LazyLoader({
    required this.loadData,
    this.limit = 20,
    this.hasMoreData,
  });

  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final List<T> _items = [];

  List<T> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  Future<void> refresh() async {
    _isLoading = true;
    _hasMore = true;
    _currentPage = 1;
    _items.clear();

    try {
      final newItems = await loadData(_currentPage, limit);
      _items.addAll(newItems);
      _hasMore = hasMoreData?.call(newItems) ?? newItems.length >= limit;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error refreshing data: $e');
      }
      rethrow;
    } finally {
      _isLoading = false;
    }
  }

  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    try {
      final newItems = await loadData(_currentPage + 1, limit);
      _items.addAll(newItems);
      _currentPage++;
      _hasMore = hasMoreData?.call(newItems) ?? newItems.length >= limit;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading more data: $e');
      }
      rethrow;
    } finally {
      _isLoading = false;
    }
  }

  void addItem(T item) {
    _items.insert(0, item);
  }

  void updateItem(bool Function(T item) finder, T newItem) {
    final index = _items.indexWhere(finder);
    if (index != -1) {
      _items[index] = newItem;
    }
  }

  void removeItem(bool Function(T item) finder) {
    _items.removeWhere(finder);
  }

  void clear() {
    _items.clear();
    _currentPage = 1;
    _hasMore = true;
    _isLoading = false;
  }
} 