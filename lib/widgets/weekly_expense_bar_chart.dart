import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/expense.dart';

class WeeklyExpenseBarChart extends StatefulWidget {
final List<Expense> expenses;

const WeeklyExpenseBarChart({
super.key,
required this.expenses,
});

@override
State<WeeklyExpenseBarChart> createState() =>
_WeeklyExpenseBarChartState();
}

class _WeeklyExpenseBarChartState
extends State<WeeklyExpenseBarChart>
with SingleTickerProviderStateMixin {
late AnimationController _controller;
late Animation<double> _animation;

@override
void initState() {
super.initState();

_controller = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 1500),
);

_animation = CurvedAnimation(
  parent: _controller,
  curve: Curves.easeOutCubic,
);

_controller.forward();

}

@override
void didUpdateWidget(
covariant WeeklyExpenseBarChart oldWidget,
) {
super.didUpdateWidget(oldWidget);

if (oldWidget.expenses != widget.expenses) {
  _controller
    ..reset()
    ..forward();
}

}

@override
void dispose() {
_controller.dispose();
super.dispose();
}

Map<int, double> _getWeeklyData() {
final now = DateTime.now();

// Tìm thứ 2 của tuần hiện tại.
final monday = now.subtract(
  Duration(days: now.weekday - DateTime.monday),
);

final result = <int, double>{
  1: 0,
  2: 0,
  3: 0,
  4: 0,
  5: 0,
  6: 0,
  7: 0,
};

for (final expense in widget.expenses) {
  final expenseDate = expense.date;

  final difference = DateTime(
    expenseDate.year,
    expenseDate.month,
    expenseDate.day,
  ).difference(
    DateTime(
      monday.year,
      monday.month,
      monday.day,
    ),
  ).inDays;

  if (difference >= 0 && difference < 7) {
    final weekday = difference + 1;

    result[weekday] =
        (result[weekday] ?? 0) + expense.amount;
  }
}

return result;

}

@override
Widget build(BuildContext context) {
final weeklyData = _getWeeklyData();

final maxValue = weeklyData.values.fold<double>(
  0.0,
  (sum, value) => math.max(sum, value).toDouble(),
);

if (maxValue == 0) {
  return const SizedBox(
    height: 300,
    child: Center(
      child: Text(
        'Chưa có dữ liệu chi tiêu trong tuần này',
      ),
    ),
  );
}

return SizedBox(
  height: 300,
  child: AnimatedBuilder(
    animation: _animation,
    builder: (context, child) {
      return CustomPaint(
        painter: _WeeklyExpenseBarPainter(
          data: weeklyData,
          maxValue: maxValue,
          progress: _animation.value,
          primaryColor:
              Theme.of(context).colorScheme.primary,
          textColor:
              Theme.of(context).colorScheme.onSurface,
        ),
        size: Size.infinite,
      );
    },
  ),
);

}
}

class _WeeklyExpenseBarPainter extends CustomPainter {
final Map<int, double> data;
final double maxValue;
final double progress;
final Color primaryColor;
final Color textColor;

_WeeklyExpenseBarPainter({
required this.data,
required this.maxValue,
required this.progress,
required this.primaryColor,
required this.textColor,
});

final List<String> _dayLabels = const [
'T2',
'T3',
'T4',
'T5',
'T6',
'T7',
'CN',
];

String _formatAmount(double amount) {
if (amount >= 1000000) {
return '${(amount / 1000000).toStringAsFixed(1)}M';
}

if (amount >= 1000) {
  return '${(amount / 1000).toStringAsFixed(0)}K';
}

return amount.toStringAsFixed(0);

}

@override
void paint(Canvas canvas, Size size) {
const leftPadding = 48.0;
const rightPadding = 16.0;
const topPadding = 20.0;
const bottomPadding = 42.0;

final chartWidth =
    size.width - leftPadding - rightPadding;

final chartHeight =
    size.height - topPadding - bottomPadding;

final chartLeft = leftPadding;
final chartTop = topPadding;
final chartBottom = chartTop + chartHeight;

final gridPaint = Paint()
  ..color = textColor.withValues(alpha: 0.12)
  ..strokeWidth = 1;

final axisPaint = Paint()
  ..color = textColor.withValues(alpha: 0.35)
  ..strokeWidth = 1;

// Trục Y.
canvas.drawLine(
  Offset(chartLeft, chartTop),
  Offset(chartLeft, chartBottom),
  axisPaint,
);

// Trục X.
canvas.drawLine(
  Offset(chartLeft, chartBottom),
  Offset(
    chartLeft + chartWidth,
    chartBottom,
  ),
  axisPaint,
);

// Các đường ngang.
const gridCount = 4;

for (int i = 0; i <= gridCount; i++) {
  final y = chartBottom -
      (chartHeight * i / gridCount);

  canvas.drawLine(
    Offset(chartLeft, y),
    Offset(
      chartLeft + chartWidth,
      y,
    ),
    gridPaint,
  );

  final value =
      maxValue * i / gridCount;

  final textPainter = TextPainter(
    text: TextSpan(
      text: _formatAmount(value),
      style: TextStyle(
        fontSize: 10,
        color: textColor.withValues(alpha: 0.7),
      ),
    ),
    textDirection: TextDirection.ltr,
  );

  textPainter.layout();

  textPainter.paint(
    canvas,
    Offset(
      chartLeft - textPainter.width - 6,
      y - textPainter.height / 2,
    ),
  );
}

final barWidth = chartWidth / 7 * 0.55;
final spaceWidth = chartWidth / 7;

for (int i = 0; i < 7; i++) {
  final weekday = i + 1;
  final amount = data[weekday] ?? 0.0;

  // Animation: chiều cao cột tăng từ 0 -> chiều cao thật.
  final fullBarHeight = maxValue == 0
      ? 0.0
      : (amount / maxValue) * chartHeight;

  final barHeight =
      fullBarHeight * progress;

  final centerX =
      chartLeft + spaceWidth * i + spaceWidth / 2;

  final barLeft =
      centerX - barWidth / 2;

  final barTop =
      chartBottom - barHeight;

  final barRect = RRect.fromRectAndRadius(
    Rect.fromLTWH(
      barLeft,
      barTop,
      barWidth,
      barHeight,
    ),
    const Radius.circular(6),
  );

  final barPaint = Paint()
    ..color = primaryColor
    ..style = PaintingStyle.fill;

  canvas.drawRRect(
    barRect,
    barPaint,
  );

  // Số tiền phía trên cột.
  // Chỉ hiển thị khi animation đã gần hoàn thành.
  if (amount > 0 && progress > 0.85) {
    final amountPainter = TextPainter(
      text: TextSpan(
        text: _formatAmount(amount),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    amountPainter.layout();

    final amountY = math.max(
      chartTop,
      barTop - amountPainter.height - 4,
    ).toDouble();

    amountPainter.paint(
      canvas,
      Offset(
        centerX - amountPainter.width / 2,
        amountY,
      ),
    );
  }

  // Nhãn ngày.
  final dayPainter = TextPainter(
    text: TextSpan(
      text: _dayLabels[i],
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
    ),
    textDirection: TextDirection.ltr,
  );

  dayPainter.layout();

  dayPainter.paint(
    canvas,
    Offset(
      centerX - dayPainter.width / 2,
      chartBottom + 10,
    ),
  );
}
}

@override
bool shouldRepaint(
covariant _WeeklyExpenseBarPainter oldDelegate,
) {
return oldDelegate.data != data ||
oldDelegate.maxValue != maxValue ||
oldDelegate.progress != progress ||
oldDelegate.primaryColor != primaryColor ||
oldDelegate.textColor != textColor;
}
}
