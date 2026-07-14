import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/soft_panel.dart';
import '../category_summary.dart';

class CategoryBreakdownCard extends StatelessWidget {
  const CategoryBreakdownCard({
    super.key,
    required this.summaries,
    required this.total,
    required this.formatCurrency,
  });

  final List<CategorySummary> summaries;
  final double total;
  final String Function(double value) formatCurrency;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SoftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Gastos por categoria',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                'Ver todas',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (summaries.isEmpty)
            Text(
              'Sem saídas registradas para montar o gráfico deste mês.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.62),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 520;
                final chart = Center(
                  child: RepaintBoundary(
                    child: _DonutChart(
                      summaries: summaries,
                      totalLabel: formatCurrency(total),
                    ),
                  ),
                );
                final list = Column(
                  children: [
                    for (final summary in summaries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 11),
                        child: _CategoryLegendRow(
                          summary: summary,
                          formatCurrency: formatCurrency,
                        ),
                      ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    children: [chart, const SizedBox(height: 18), list],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(width: 220, child: chart),
                    const SizedBox(width: 18),
                    Expanded(child: list),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _CategoryLegendRow extends StatelessWidget {
  const _CategoryLegendRow({
    required this.summary,
    required this.formatCurrency,
  });

  final CategorySummary summary;
  final String Function(double value) formatCurrency;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: summary.color.withValues(alpha: 0.88),
            shape: BoxShape.circle,
          ),
          child: Icon(summary.icon, size: 14, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            summary.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          formatCurrency(summary.amount),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.58),
            fontWeight: FontWeight.w700,
            fontFeatures: tabularFigures,
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 42,
          child: Text(
            '${(summary.percent * 100).round()}%',
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.58),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _DonutChart extends StatelessWidget {
  const _DonutChart({required this.summaries, required this.totalLabel});

  final List<CategorySummary> summaries;
  final String totalLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 174,
      height: 174,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(174),
            painter: _DonutChartPainter(summaries),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.52),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                totalLabel,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  const _DonutChartPainter(this.summaries);

  final List<CategorySummary> summaries;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 13;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const strokeWidth = 31.0;
    var startAngle = -math.pi / 2;

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = const Color(0xFFE7E2F4);
    canvas.drawCircle(center, radius, basePaint);

    for (final summary in summaries) {
      final sweep = math.max(summary.percent * math.pi * 2, 0.02);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = summary.color;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.summaries != summaries;
  }
}
