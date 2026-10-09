class Expense {
  final int? id;
  final String merchant;
  final double amount;
  final DateTime date;
  final String category;
  final String? imagePath;

  const Expense({
    this.id,
    required this.merchant,
    required this.amount,
    required this.date,
    required this.category,
    this.imagePath,
  });

  // ============================================================
  // CHUYỂN EXPENSE → MAP
  // Dùng khi lưu vào SQLite
  // ============================================================
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'merchant': merchant,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
      'imagePath': imagePath,
    };
  }

  // ============================================================
  // CHUYỂN MAP → EXPENSE
  // Dùng khi đọc dữ liệu từ SQLite
  // ============================================================
  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      merchant: map['merchant'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      category: map['category'] as String,
      imagePath: map['imagePath'] as String?,
    );
  }

  // ============================================================
  // COPY
  // Dùng khi cần chỉnh sửa Expense
  // ============================================================
  Expense copyWith({
    int? id,
    String? merchant,
    double? amount,
    DateTime? date,
    String? category,
    String? imagePath,
  }) {
    return Expense(
      id: id ?? this.id,
      merchant: merchant ?? this.merchant,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}
