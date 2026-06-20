class Bookmark {
  final String id;
  final String questionId;
  final String questionStem;
  final String subject;
  final String? note;
  final DateTime createdAt;

  const Bookmark({
    required this.id,
    required this.questionId,
    required this.questionStem,
    required this.subject,
    this.note,
    required this.createdAt,
  });

  Bookmark copyWith({String? note}) => Bookmark(
    id: id,
    questionId: questionId,
    questionStem: questionStem,
    subject: subject,
    note: note ?? this.note,
    createdAt: createdAt,
  );
}
