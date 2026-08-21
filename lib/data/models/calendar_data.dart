/// 财经日历事件（华尔街见闻源，A4）
class CalendarEvent {
  final String title;
  final String country;
  final DateTime time;
  final int importance; // 0-3
  final String actual;
  final String forecast;
  final String previous;
  final String period;

  const CalendarEvent({
    required this.title,
    this.country = '',
    required this.time,
    this.importance = 0,
    this.actual = '',
    this.forecast = '',
    this.previous = '',
    this.period = '',
  });

  String get importanceLabel => switch (importance) {
        3 => '★★★',
        2 => '★★',
        1 => '★',
        _ => '',
      };
}
