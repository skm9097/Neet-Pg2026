class QuizAttempt {
  final String questionId;
  final String? selectedOption;
  final bool isCorrect;
  final String subject;

  const QuizAttempt({
    required this.questionId,
    required this.selectedOption,
    required this.isCorrect,
    required this.subject,
  });
}

class MockTestResult {
  final String id;
  final List<QuizAttempt> attempts;
  final DateTime completedAt;
  final Duration timeTaken;
  final String mode; // 'year_2025', 'subject_medicine', 'mixed', 'mock_full'

  const MockTestResult({
    required this.id,
    required this.attempts,
    required this.completedAt,
    required this.timeTaken,
    required this.mode,
  });

  int get total => attempts.length;
  int get correct => attempts.where((a) => a.isCorrect).length;
  int get incorrect => attempts.where((a) => !a.isCorrect && a.selectedOption != null).length;
  int get unattempted => attempts.where((a) => a.selectedOption == null).length;
  double get accuracy => total > 0 ? correct / total * 100 : 0;
  int get neetScore => correct * 4 - incorrect;

  Map<String, double> get subjectAccuracy {
    final Map<String, List<bool>> bySubject = {};
    for (final a in attempts) {
      bySubject.putIfAbsent(a.subject, () => []).add(a.isCorrect);
    }
    return {
      for (final entry in bySubject.entries)
        entry.key: entry.value.where((v) => v).length / entry.value.length * 100,
    };
  }

  List<String> get weakSubjects {
    return subjectAccuracy.entries
        .where((e) => e.value < 50)
        .map((e) => e.key)
        .toList();
  }
}
