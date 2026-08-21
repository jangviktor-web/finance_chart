/// 个股研究报告（东财源，A2）
class ResearchReport {
  final String title;
  final String org; // 机构
  final DateTime date;
  final String rating; // 评级
  final String author;
  final String industry;

  const ResearchReport({
    required this.title,
    this.org = '',
    required this.date,
    this.rating = '',
    this.author = '',
    this.industry = '',
  });
}
