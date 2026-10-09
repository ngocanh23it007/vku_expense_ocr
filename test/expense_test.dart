import 'package:flutter_test/flutter_test.dart';
import 'package:vku_expense_ocr/models/expense.dart';

void main() {
  group('Expense Model Tests', () {
    test('Tạo Expense với thông tin chính xác', () {
      final expense = Expense(
        id: 1,
        merchant: 'Viettel',
        amount: 228762,
        date: DateTime(2023, 1, 15),
        category: 'Hóa đơn',
        imagePath: '/receipt/viettel.jpg',
      );

      expect(expense.id, 1);
      expect(expense.merchant, 'Viettel');
      expect(expense.amount, 228762);
      expect(expense.date, DateTime(2023, 1, 15));
      expect(expense.category, 'Hóa đơn');
      expect(expense.imagePath, '/receipt/viettel.jpg');
    });

    test('Chuyển Expense sang Map và đọc lại', () {
      final original = Expense(
        id: 2,
        merchant: 'Circle K',
        amount: 50000,
        date: DateTime(2026, 10, 9),
        category: 'Ăn uống',
      );

      final restored = Expense.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.merchant, original.merchant);
      expect(restored.amount, original.amount);
      expect(restored.date, original.date);
      expect(restored.category, original.category);
    });

    test('copyWith chỉ cập nhật trường được chọn', () {
      final original = Expense(
        id: 3,
        merchant: 'Mini Mart',
        amount: 100000,
        date: DateTime(2026, 10, 9),
        category: 'Mua sắm',
        imagePath: '/receipt/shop.jpg',
      );

      final updated = original.copyWith(
        merchant: 'Super Mart',
        amount: 120000,
      );

      expect(updated.merchant, 'Super Mart');
      expect(updated.amount, 120000);
      expect(updated.id, original.id);
      expect(updated.date, original.date);
      expect(updated.category, original.category);
      expect(updated.imagePath, original.imagePath);
    });
  });
}
