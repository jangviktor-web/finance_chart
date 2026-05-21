import 'package:flutter/material.dart';
import '../../../data/models/realtime_quote.dart';
import '../../../app/theme.dart';

class ChartHeader extends StatelessWidget {
  final RealtimeQuote quote;

  const ChartHeader({super.key, required this.quote});

  @override
  Widget build(BuildContext context) {
    final changeColor = quote.isUp ? AppColors.up : AppColors.down;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 股票名称和代码
          Row(
            children: [
              Text(
                quote.name,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                quote.code,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 当前价格和涨跌幅
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                quote.now.toStringAsFixed(2),
                style: TextStyle(
                  color: changeColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${quote.change >= 0 ? '+' : ''}${quote.change.toStringAsFixed(2)}',
                    style: TextStyle(color: changeColor, fontSize: 14),
                  ),
                  Text(
                    '${quote.changePercent >= 0 ? '+' : ''}${quote.changePercent.toStringAsFixed(2)}%',
                    style: TextStyle(color: changeColor, fontSize: 14),
                  ),
                ],
              ),
              const Spacer(),
              // 最高最低
              _buildPriceInfo('最高', quote.high, AppColors.up),
              const SizedBox(width: 16),
              _buildPriceInfo('最低', quote.low, AppColors.down),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceInfo(String label, double price, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
        ),
        Text(
          price.toStringAsFixed(2),
          style: TextStyle(color: color, fontSize: 12),
        ),
      ],
    );
  }
}
