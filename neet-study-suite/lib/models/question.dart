class Question {
  final String id;
  final String stem;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String correctOption; // 'A', 'B', 'C', or 'D'
  final String explanation;
  final String subject;
  final String? year;
  final int? questionNumber;

  const Question({
    required this.id,
    required this.stem,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctOption,
    required this.explanation,
    required this.subject,
    this.year,
    this.questionNumber,
  });

  static final RegExp _imagePattern = RegExp(
    r'shown in (the )?(picture|image|figure|diagram)|'
    r'photograph shows|the image (shown|below)|'
    r'given image|given diagram|'
    r'identify.*(shown|image|below|based on)|'
    r'spot (radiograph|diagnosis)|blood smear image|'
    r'image-based|\*\(image',
    caseSensitive: false,
  );

  bool get isImageBased => _imagePattern.hasMatch(stem);

  String get correctText {
    switch (correctOption) {
      case 'A': return optionA;
      case 'B': return optionB;
      case 'C': return optionC;
      case 'D': return optionD;
      default: return '';
    }
  }

  String optionText(String opt) {
    switch (opt) {
      case 'A': return optionA;
      case 'B': return optionB;
      case 'C': return optionC;
      case 'D': return optionD;
      default: return '';
    }
  }

  Question copyWith({
    String? id, String? stem, String? optionA, String? optionB,
    String? optionC, String? optionD, String? correctOption,
    String? explanation, String? subject, String? year, int? questionNumber,
  }) => Question(
    id: id ?? this.id,
    stem: stem ?? this.stem,
    optionA: optionA ?? this.optionA,
    optionB: optionB ?? this.optionB,
    optionC: optionC ?? this.optionC,
    optionD: optionD ?? this.optionD,
    correctOption: correctOption ?? this.correctOption,
    explanation: explanation ?? this.explanation,
    subject: subject ?? this.subject,
    year: year ?? this.year,
    questionNumber: questionNumber ?? this.questionNumber,
  );
}
