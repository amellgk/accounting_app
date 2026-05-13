import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';
import '../services/local_db_service.dart';

class TransactionProvider extends ChangeNotifier {
  final ApiService _api;
  final LocalDbService _localDb;

  List<Transaction> _transactions = [];
  List<Category> _categories = [];
  Map<String, dynamic>? _monthlyStats;
  bool _loading = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = true;

  List<Transaction> get transactions => _transactions;
  List<Category> get categories => _categories;
  List<Category> get expenseCategories =>
      _categories.where((c) => c.type == 'expense').toList();
  List<Category> get incomeCategories =>
      _categories.where((c) => c.type == 'income').toList();
  Map<String, dynamic>? get monthlyStats => _monthlyStats;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasMore => _hasMore;

  TransactionProvider(this._api, this._localDb);

  Future<void> loadCategories() async {
    try {
      final data = await _api.getCategories();
      _categories = data.map((j) => Category.fromJson(j)).cast<Category>().toList();
      // 缓存到本地
      await _localDb.cacheCategories(data.cast<Map<String, dynamic>>());
      notifyListeners();
    } catch (e) {
      // 离线时使用本地缓存
      final cached = await _localDb.getCachedCategories();
      _categories = cached.map((j) => Category.fromJson(j)).cast<Category>().toList();
      notifyListeners();
    }
  }

  Future<void> loadTransactions({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
    }
    if (_loading || !_hasMore) return;
    _loading = true;
    notifyListeners();

    try {
      final data = await _api.getTransactions(page: _currentPage);
      final list = (data['transactions'] as List)
          .map((j) => Transaction.fromJson(j))
          .toList();

      if (refresh) {
        _transactions = list;
      } else {
        _transactions.addAll(list);
      }

      final pagination = data['pagination'];
      _hasMore = _currentPage < (pagination['totalPages'] ?? 1);
      _currentPage++;
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _loading = false;
    notifyListeners();
  }

  Future<bool> addTransaction({
    required String categoryId,
    required String type,
    required double amount,
    String note = '',
    String? transactionDate,
  }) async {
    try {
      final data = await _api.createTransaction(
        categoryId: categoryId,
        type: type,
        amount: amount,
        note: note,
        transactionDate: transactionDate,
      );
      final tx = Transaction.fromJson(data['transaction']);
      _transactions.insert(0, tx);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTransaction(String id) async {
    try {
      await _api.deleteTransaction(id);
      _transactions.removeWhere((t) => t.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> loadMonthlyStats({int? year, int? month}) async {
    try {
      _monthlyStats = await _api.getMonthlyStats(year: year, month: month);
      notifyListeners();
    } catch (e) {
      // 离线时用本地数据
      final now = DateTime.now();
      final local = await _localDb.getLocalMonthlyStats(
        year ?? now.year,
        month ?? now.month,
      );
      _monthlyStats = {
        'income': local['income'],
        'expense': local['expense'],
        'balance': local['income']! - local['expense']!,
        'categoryStats': [],
      };
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
