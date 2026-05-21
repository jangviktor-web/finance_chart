import 'package:flutter/material.dart';
import '../../../app/theme.dart';

/// 统一错误展示组件
class AppErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AppErrorWidget({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppColors.down, size: 48),
            const SizedBox(height: 16),
            Text('加载失败',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              message.length > 200 ? '${message.substring(0, 200)}...' : message,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('重试'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
