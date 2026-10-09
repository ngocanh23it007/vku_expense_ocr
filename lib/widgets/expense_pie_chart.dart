import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/expense.dart';

class ExpensePieChart extends StatefulWidget {
final List<Expense> expenses;

const ExpensePieChart({
super.key,
required this.expenses,
});

@override
State<ExpensePieChart> createState() =>
_ExpensePieChartState();
}

class _ExpensePieChartState
extends State<ExpensePieChart>
with SingleTickerProviderStateMixin {
late AnimationController _controller;
late Animation<double> _animation;

@override
void initState() {
super.initState();

_controller = AnimationController(
  vsync: this,
  duration: const Duration(seconds: 2),
);

_animation = CurvedAnimation(
  parent: _controller,
  curve: Curves.easeOutCubic,
);

_controller.forward();


}

@override
void didUpdateWidget(
covariant ExpensePieChart oldWidget,
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

Map<String, double> _groupByCategory() {
final result = <String, double>{};

for (final expense in widget.expenses) {
  result[expense.category] =
      (result[expense.category] ?? 0) + expense.amount;
}

return result;


}

@override
Widget build(BuildContext context) {
final data = _groupByCategory();

if (data.isEmpty) {
  return const SizedBox(
    height: 250,
    child: Center(
      child: Text(
        'Chưa có dữ liệu chi tiêu',
      ),
    ),
  );
}

final total = data.values.fold<double>(
  0,
  (sum, value) => sum + value,
);

return SizedBox(
  height: 300,
  child: Column(
    children: [
      Expanded(
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return CustomPaint(
              painter: _ExpensePiePainter(
                data: data,
                total: total,
                progress: _animation.value,
                primaryColor:
                    Theme.of(context)
                        .colorScheme
                        .primary,
                backgroundColor:
                    Theme.of(context)
                        .colorScheme
                        .surface,
                textColor:
                    Theme.of(context)
                        .colorScheme
                        .onSurface,
              ),
              size: Size.infinite,
            );
          },
        ),
      ),

      const SizedBox(height: 8),

      Wrap(
        spacing: 16,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: data.entries.map((entry) {
          return _LegendItem(
            label: entry.key,
            value: entry.value,
          );
        }).toList(),
      ),

      const SizedBox(height: 8),
    ],
  ),
);

}
}

class _LegendItem extends StatelessWidget {
final String label;
final double value;

const _LegendItem({
required this.label,
required this.value,
});

Color _getColor(String category) {
switch (category) {
case 'Ăn uống':
return Colors.orange;
case 'Mua sắm':
return Colors.blue;
case 'Di chuyển':
return Colors.green;
case 'Hóa đơn':
return Colors.purple;
default:
return Colors.grey;
}
}

@override
Widget build(BuildContext context) {
return Row(
mainAxisSize: MainAxisSize.min,
children: [
Container(
width: 12,
height: 12,
decoration: BoxDecoration(
shape: BoxShape.circle,
color: _getColor(label),
),
),
const SizedBox(width: 6),
Text(label),
],
);
}
}

class _ExpensePiePainter extends CustomPainter {
final Map<String, double> data;
final double total;
final double progress;
final Color primaryColor;
final Color backgroundColor;
final Color textColor;

_ExpensePiePainter({
required this.data,
required this.total,
required this.progress,
required this.primaryColor,
required this.backgroundColor,
required this.textColor,
});

Color _getColor(String category) {
switch (category) {
case 'Ăn uống':
return Colors.orange;
case 'Mua sắm':
return Colors.blue;
case 'Di chuyển':
return Colors.green;
case 'Hóa đơn':
return Colors.purple;
default:
return Colors.grey;
}
}

@override
void paint(Canvas canvas, Size size) {
final center = Offset(
size.width / 2,
size.height / 2,
);

final radius =
    math.min(size.width, size.height) / 2.5;

final innerRadius = radius * 0.55;

final paint = Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = radius - innerRadius
  ..strokeCap = StrokeCap.butt;

double startAngle = -math.pi / 2;

for (final entry in data.entries) {
  final fullSweepAngle =
      (entry.value / total) * 2 * math.pi;

  final sweepAngle =
      fullSweepAngle * progress;

  paint.color = _getColor(entry.key);

  canvas.drawArc(
    Rect.fromCircle(
      center: center,
      radius: (radius + innerRadius) / 2,
    ),
    startAngle,
    sweepAngle,
    false,
    paint,
  );

  startAngle += fullSweepAngle;
}

// Vòng tròn bên trong donut.
final centerPaint = Paint()
  ..color = backgroundColor
  ..style = PaintingStyle.fill;

canvas.drawCircle(
  center,
  innerRadius / 2,
  centerPaint,
);

final textPainter = TextPainter(
  text: TextSpan(
    text: 'Chi tiêu',
    style: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: primaryColor,
    ),
  ),
  textDirection: TextDirection.ltr,
);

textPainter.layout();

textPainter.paint(
  canvas,
  Offset(
    center.dx - textPainter.width / 2,
    center.dy - textPainter.height / 2,
  ),
);

}

@override
bool shouldRepaint(
covariant _ExpensePiePainter oldDelegate,
) {
return oldDelegate.data != data ||
oldDelegate.total != total ||
oldDelegate.progress != progress ||
oldDelegate.primaryColor != primaryColor ||
oldDelegate.backgroundColor != backgroundColor ||
oldDelegate.textColor != textColor;
}
}
