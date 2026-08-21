/// 互动易投资者问答（巨潮源，A3）
class InteractiveQA {
  final String question;
  final String answer;
  final String company;
  final DateTime date;
  final DateTime? answerDate;

  const InteractiveQA({
    required this.question,
    required this.answer,
    this.company = '',
    required this.date,
    this.answerDate,
  });
}
