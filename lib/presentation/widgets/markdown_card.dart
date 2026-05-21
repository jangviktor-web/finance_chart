import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../app/theme.dart';

/// 深色主题 Markdown 渲染卡片
class MarkdownCard extends StatelessWidget {
  final String markdown;
  final EdgeInsets padding;

  const MarkdownCard({
    super.key,
    required this.markdown,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: MarkdownBody(
        data: markdown,
        selectable: true,
        styleSheet: MarkdownStyleSheet(
          p: TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.6),
          h1: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
          h2: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          h3: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
          strong: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
          em: TextStyle(color: AppColors.ma5, fontStyle: FontStyle.italic),
          code: TextStyle(
            color: AppColors.ma10,
            backgroundColor: AppColors.surface,
            fontSize: 13,
          ),
          codeblockDecoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          blockquote: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          listBullet: TextStyle(color: AppColors.primary),
          tableHead: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          tableBody: TextStyle(color: AppColors.textPrimary, fontSize: 13),
          tableHeadAlign: TextAlign.center,
          tableBorder: TableBorder.all(
            color: AppColors.divider,
            width: 0.5,
          ),
          tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          tableCellsDecoration: BoxDecoration(
            color: AppColors.cardBackground,
          ),
        ),
      ),
    );
  }
}

/// 带标题和操作按钮的 Markdown 报告卡片
class MarkdownReportCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String markdown;
  final List<Widget>? actions;

  const MarkdownReportCard({
    super.key,
    required this.title,
    required this.icon,
    required this.markdown,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    )),
                ),
                if (actions != null) ...actions!,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: MarkdownBody(
              data: markdown,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.6),
                h2: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                h3: TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.bold),
                strong: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                tableHead: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                tableBody: TextStyle(color: AppColors.textPrimary, fontSize: 12),
                tableHeadAlign: TextAlign.center,
                tableBorder: TableBorder.all(color: AppColors.divider, width: 0.5),
                tableCellsPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                listBullet: TextStyle(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
