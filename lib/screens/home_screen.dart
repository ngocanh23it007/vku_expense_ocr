import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../widgets/expense_pie_chart.dart';
import '../widgets/weekly_expense_bar_chart.dart';
import 'scan_screen.dart';

class HomeScreen extends ConsumerWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const HomeScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  String _formatAmount(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => '.',
        )} đ';
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Ăn uống':
        return Icons.restaurant_outlined;

      case 'Mua sắm':
        return Icons.shopping_bag_outlined;

      case 'Di chuyển':
        return Icons.directions_car_outlined;

      case 'Hóa đơn':
        return Icons.receipt_long_outlined;

      default:
        return Icons.category_outlined;
    }
  }

  // =========================
  // CHI TIẾT KHOẢN CHI
  // =========================

  void _showExpenseDetail(
    BuildContext context,
    WidgetRef ref,
    Expense expense,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.85,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                20,
                8,
                20,
                24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chi tiết khoản chi',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Center(
                    child: CircleAvatar(
                      radius: 35,
                      backgroundColor:
                          Theme.of(context)
                              .colorScheme
                              .primaryContainer,
                      child: Icon(
                        _getCategoryIcon(
                          expense.category,
                        ),
                        size: 36,
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  _detailRow(
                    context,
                    'Cửa hàng',
                    expense.merchant,
                    Icons.store_outlined,
                  ),

                  const SizedBox(height: 14),

                  _detailRow(
                    context,
                    'Số tiền',
                    _formatAmount(
                      expense.amount,
                    ),
                    Icons.payments_outlined,
                  ),

                  const SizedBox(height: 14),

                  _detailRow(
                    context,
                    'Ngày',
                    _formatDate(
                      expense.date,
                    ),
                    Icons.calendar_today_outlined,
                  ),

                  const SizedBox(height: 14),

                  _detailRow(
                    context,
                    'Danh mục',
                    expense.category,
                    _getCategoryIcon(
                      expense.category,
                    ),
                  ),

                  // Ảnh hóa đơn
                  if (expense.imagePath != null &&
                      expense.imagePath!.isNotEmpty) ...[
                    const SizedBox(height: 20),

                    const Text(
                      'Ảnh hóa đơn',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(12),
                      child: Image.file(
                        File(expense.imagePath!),
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (
                              context,
                              error,
                              stackTrace,
                            ) {
                          return Container(
                            height: 120,
                            width: double.infinity,
                            alignment: Alignment.center,
                            decoration:
                                BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(12),
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                            ),
                            child: const Text(
                              'Không thể hiển thị ảnh',
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // NÚT SỬA
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);

                        _showEditExpenseDialog(
                          context,
                          ref,
                          expense,
                        );
                      },
                      icon: const Icon(
                        Icons.edit_outlined,
                      ),
                      label: const Text(
                        'Sửa khoản chi',
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // NÚT XÓA
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);

                        _showDeleteConfirmation(
                          context,
                          ref,
                          expense,
                        );
                      },
                      icon: const Icon(
                        Icons.delete_outline,
                      ),
                      label: const Text(
                        'Xóa khoản chi',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            Theme.of(context)
                                .colorScheme
                                .error,
                        side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .error,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // NÚT ĐÓNG
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Đóng',
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // =========================
  // DÒNG CHI TIẾT
  // =========================

  Widget _detailRow(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: Theme.of(context)
              .colorScheme
              .primary,
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================
  // SỬA KHOẢN CHI
  // =========================

  void _showEditExpenseDialog(
    BuildContext context,
    WidgetRef ref,
    Expense expense,
  ) {
    final merchantController =
        TextEditingController(
      text: expense.merchant,
    );

    final amountController =
        TextEditingController(
      text: expense.amount
          .toStringAsFixed(0),
    );

    DateTime selectedDate = expense.date;

    String selectedCategory =
        expense.category;

    final categories = [
      'Ăn uống',
      'Mua sắm',
      'Di chuyển',
      'Hóa đơn',
      'Khác',
    ];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setState,
          ) {
            return AlertDialog(
              title: const Text(
                'Sửa khoản chi',
              ),

              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    // CỬA HÀNG
                    TextField(
                      controller:
                          merchantController,
                      decoration:
                          const InputDecoration(
                        labelText: 'Cửa hàng',
                        prefixIcon: Icon(
                          Icons.store_outlined,
                        ),
                        border:
                            OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // SỐ TIỀN
                    TextField(
                      controller:
                          amountController,
                      keyboardType:
                          TextInputType.number,
                      decoration:
                          const InputDecoration(
                        labelText: 'Số tiền',
                        suffixText: 'đ',
                        prefixIcon: Icon(
                          Icons.payments_outlined,
                        ),
                        border:
                            OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // NGÀY
                    InkWell(
                      onTap: () async {
                        final pickedDate =
                            await showDatePicker(
                          context: context,
                          initialDate:
                              selectedDate,
                          firstDate:
                              DateTime(2000),
                          lastDate:
                              DateTime(2100),
                        );

                        if (pickedDate !=
                            null) {
                          setState(() {
                            selectedDate =
                                pickedDate;
                          });
                        }
                      },
                      borderRadius:
                          BorderRadius.circular(
                        4,
                      ),
                      child: InputDecorator(
                        decoration:
                            const InputDecoration(
                          labelText: 'Ngày',
                          prefixIcon: Icon(
                            Icons
                                .calendar_today_outlined,
                          ),
                          border:
                              OutlineInputBorder(),
                        ),
                        child: Text(
                          _formatDate(
                            selectedDate,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // DANH MỤC
                    DropdownButtonFormField<
                        String>(
                      initialValue:
                          categories.contains(
                        selectedCategory,
                      )
                              ? selectedCategory
                              : 'Khác',
                      decoration:
                          const InputDecoration(
                        labelText: 'Danh mục',
                        prefixIcon: Icon(
                          Icons.category_outlined,
                        ),
                        border:
                            OutlineInputBorder(),
                      ),
                      items: categories
                          .map(
                            (category) {
                              return DropdownMenuItem<
                                  String>(
                                value: category,
                                child:
                                    Text(category),
                              );
                            },
                          )
                          .toList(),
                      onChanged:
                          (value) {
                        if (value != null) {
                          setState(() {
                            selectedCategory =
                                value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child: const Text(
                    'Hủy',
                  ),
                ),

                FilledButton(
                  onPressed: () async {
                    final merchant =
                        merchantController
                            .text
                            .trim();

                    final amountText =
                        amountController
                            .text
                            .trim()
                            .replaceAll(
                              '.',
                              '',
                            )
                            .replaceAll(
                              ',',
                              '',
                            );

                    final amount =
                        double.tryParse(
                      amountText,
                    );

                    // Kiểm tra dữ liệu
                    if (merchant.isEmpty) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Vui lòng nhập tên cửa hàng',
                          ),
                        ),
                      );
                      return;
                    }

                    if (amount == null ||
                        amount <= 0) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Số tiền không hợp lệ',
                          ),
                        ),
                      );
                      return;
                    }

                    final updatedExpense =
                        expense.copyWith(
                      merchant: merchant,
                      amount: amount,
                      date: selectedDate,
                      category:
                          selectedCategory,
                    );

                    await ref
                        .read(
                          expenseProvider
                              .notifier,
                        )
                        .updateExpense(
                          updatedExpense,
                        );

                    if (!context.mounted) {
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                    );

                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Đã cập nhật khoản chi',
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    'Lưu',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================
  // XÁC NHẬN XÓA
  // =========================

    void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    Expense expense,
    ) {
    showDialog(
        context: context,
        builder: (dialogContext) {
        return AlertDialog(
            title: const Text(
            'Xóa khoản chi?',
            ),

            content: Text(
            'Bạn có chắc muốn xóa khoản chi '
            '"${expense.merchant}" '
            'với số tiền '
            '${_formatAmount(expense.amount)} không?',
            ),

            actions: [
            // NÚT HỦY
            TextButton(
                onPressed: () {
                Navigator.of(dialogContext).pop();
                },
                child: const Text(
                'Hủy',
                ),
            ),

            // NÚT XÓA
            FilledButton(
                onPressed: () async {
                if (expense.id == null) {
                    return;
                }

                // ĐÓNG POPUP NGAY LẬP TỨC
                Navigator.of(dialogContext).pop();

                // Sau khi popup đóng mới thực hiện xóa
                await ref
                    .read(
                        expenseProvider.notifier,
                    )
                    .deleteExpense(
                        expense.id!,
                    );

                // Hiển thị thông báo
                if (!context.mounted) {
                    return;
                }

                ScaffoldMessenger.of(context)
                    .showSnackBar(
                    const SnackBar(
                    content: Text(
                        'Đã xóa khoản chi',
                    ),
                    ),
                );
                },

                style: FilledButton.styleFrom(
                backgroundColor:
                    Theme.of(context)
                        .colorScheme
                        .error,
                foregroundColor:
                    Theme.of(context)
                        .colorScheme
                        .onError,
                ),

                child: const Text(
                'Xóa',
                ),
            ),
            ],
        );
        },
    );
    }


  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final expenses = ref.watch(
      expenseProvider,
    );

    final now = DateTime.now();

    // Chỉ lấy khoản chi trong tháng hiện tại
    final monthlyExpenses =
        expenses.where((expense) {
      return expense.date.year == now.year &&
          expense.date.month == now.month;
    }).toList();

    final totalThisMonth =
        monthlyExpenses.fold<double>(
      0,
      (sum, expense) =>
          sum + expense.amount,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Expense Tracker',
        ),
        actions: [
          IconButton(
            onPressed: onToggleTheme,
            tooltip: isDarkMode
                ? 'Chuyển sang Light Mode'
                : 'Chuyển sang Dark Mode',
            icon: Icon(
                isDarkMode
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
            ),
            ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: () async {
          await ref
              .read(
                expenseProvider.notifier,
              )
              .refresh();
        },

        child: SingleChildScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(),

          padding:
              const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              const Text(
                'Tổng chi tiêu tháng này',
                style: TextStyle(
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                _formatAmount(
                  totalThisMonth,
                ),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(height: 24),

              // Spending Chart
              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chi tiêu theo danh mục',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      ExpensePieChart(
                        expenses:
                            monthlyExpenses,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Weekly Expense Chart
              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chi tiêu trong tuần',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        'Thống kê chi tiêu từ thứ 2 đến chủ nhật',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(
                            context,
                          )
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(height: 12),

                      WeeklyExpenseBarChart(
                        expenses: expenses,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Chi tiêu gần đây',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              if (expenses.isEmpty)
                const Center(
                  child: Padding(
                    padding:
                        EdgeInsets.all(32),
                    child: Text(
                      'Chưa có khoản chi tiêu nào',
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics:
                      const NeverScrollableScrollPhysics(),
                  itemCount:
                      expenses.length,
                  separatorBuilder:
                      (context, index) {
                    return const SizedBox(
                      height: 8,
                    );
                  },
                  itemBuilder:
                      (context, index) {
                    final expense =
                        expenses[index];

                    return Card(
                      child: ListTile(
                        onTap: () {
                          _showExpenseDetail(
                            context,
                            ref,
                            expense,
                          );
                        },

                        leading:
                            CircleAvatar(
                          backgroundColor:
                              Theme.of(
                                context,
                              )
                                  .colorScheme
                                  .primaryContainer,

                          child: Icon(
                            _getCategoryIcon(
                              expense.category,
                            ),
                            color: Theme.of(
                              context,
                            )
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),

                        title: Text(
                          expense.merchant,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        subtitle: Text(
                          '${expense.category} • '
                          '${_formatDate(expense.date)}',
                        ),

                        trailing: Text(
                          _formatAmount(
                            expense.amount,
                          ),
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                            color: Theme.of(
                              context,
                            )
                                .colorScheme
                                .primary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),

      floatingActionButton:
          FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const ScanScreen(),
            ),
          );
        },
        child: const Icon(
          Icons.add,
        ),
      ),
    );
  }
}
