class Flashcard {
  final String id;
  final String front;
  final String back;
  final String subject;
  final String? sourceQuestionId;
  // SM-2 fields
  final double easeFactor;
  final int interval;     // days until next review
  final int repetitions;
  final DateTime? nextReviewDate;
  final DateTime createdAt;

  const Flashcard({
    required this.id,
    required this.front,
    required this.back,
    required this.subject,
    this.sourceQuestionId,
    this.easeFactor = 2.5,
    this.interval = 1,
    this.repetitions = 0,
    this.nextReviewDate,
    required this.createdAt,
  });

  bool get isDue {
    if (nextReviewDate == null) return true;
    return DateTime.now().isAfter(nextReviewDate!);
  }

  // SM-2: quality 0-5 (0-2 = fail, 3-5 = pass)
  Flashcard withSm2Update(int quality) {
    double ef = easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    if (ef < 1.3) ef = 1.3;

    int reps = quality >= 3 ? repetitions + 1 : 0;
    int newInterval;
    if (reps <= 1) {
      newInterval = 1;
    } else if (reps == 2) {
      newInterval = 6;
    } else {
      newInterval = (interval * ef).round();
    }

    return Flashcard(
      id: id,
      front: front,
      back: back,
      subject: subject,
      sourceQuestionId: sourceQuestionId,
      easeFactor: ef,
      interval: newInterval,
      repetitions: reps,
      nextReviewDate: DateTime.now().add(Duration(days: newInterval)),
      createdAt: createdAt,
    );
  }

  Flashcard copyWith({
    String? id, String? front, String? back, String? subject,
    String? sourceQuestionId, double? easeFactor, int? interval,
    int? repetitions, DateTime? nextReviewDate, DateTime? createdAt,
  }) => Flashcard(
    id: id ?? this.id,
    front: front ?? this.front,
    back: back ?? this.back,
    subject: subject ?? this.subject,
    sourceQuestionId: sourceQuestionId ?? this.sourceQuestionId,
    easeFactor: easeFactor ?? this.easeFactor,
    interval: interval ?? this.interval,
    repetitions: repetitions ?? this.repetitions,
    nextReviewDate: nextReviewDate ?? this.nextReviewDate,
    createdAt: createdAt ?? this.createdAt,
  );
}
