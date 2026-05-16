enum ModuleType { byYear, bySubject, mixed }

class QuizConfig {
  final ModuleType moduleType;
  final String? year;
  final String? subject;
  final int questionCount;

  const QuizConfig({
    required this.moduleType,
    this.year,
    this.subject,
    required this.questionCount,
  });

  String get displayTitle {
    switch (moduleType) {
      case ModuleType.byYear:
        return 'NEET-PG $year';
      case ModuleType.bySubject:
        return subject ?? 'Subject';
      case ModuleType.mixed:
        return 'Mixed ($questionCount Qs)';
    }
  }
}
