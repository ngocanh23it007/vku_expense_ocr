import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../models/expense.dart';

final expenseProvider =
    NotifierProvider<ExpenseNotifier, List<Expense>>(
  ExpenseNotifier.new,
);

class ExpenseNotifier extends Notifier<List<Expense>> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  @override
  List<Expense> build() {
    _loadExpenses();
    return [];
  }

  Future<void> _loadExpenses() async {
    final expenses = await _databaseHelper.getExpenses();
    state = expenses;
  }

  // Thêm khoản chi
  Future<void> addExpense(Expense expense) async {
    final id = await _databaseHelper.insertExpense(expense);

    final newExpense = expense.copyWith(id: id);

    state = [
      newExpense,
      ...state,
    ];
  }

  // Cập nhật khoản chi
  Future<void> updateExpense(Expense expense) async {
    await _databaseHelper.updateExpense(expense);

    state = [
      for (final item in state)
        if (item.id == expense.id) expense else item,
    ];
  }

  // Xóa khoản chi
  Future<void> deleteExpense(int id) async {
    await _databaseHelper.deleteExpense(id);

    state = state
        .where((expense) => expense.id != id)
        .toList();
  }

  // Tải lại dữ liệu từ SQLite
  Future<void> refresh() async {
    await _loadExpenses();
  }
}
