import 'package:flutter/material.dart';
import '../../../app/theme.dart';

class ChartPeriodSelector extends StatelessWidget {
  final String selectedPeriod;
  final ValueChanged<String> onPeriodChanged;

  const ChartPeriodSelector({
    super.key,
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  static const periods = [
    ('1m', '1分'),
    ('5m', '5分'),
    ('15m', '15分'),
    ('30m', '30分'),
    ('60m', '60分'),
    ('day', '日K'),
    ('week', '周K'),
    ('month', '月K'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: periods.length,
        itemBuilder: (context, index) {
          final period = periods[index];
          final isSelected = period.$1 == selectedPeriod;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => onPeriodChanged(period.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.up.withOpacity(0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isSelected ? AppColors.up : AppColors.textSecondary.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  period.$2,
                  style: TextStyle(
                    color: isSelected ? AppColors.up : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
