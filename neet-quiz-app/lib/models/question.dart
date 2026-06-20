class Question {
  final int number;
  final String topic;
  final String stem;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String correctOption;
  final String explanation;
  final String subject;
  final String? year;

  const Question({
    required this.number,
    required this.topic,
    required this.stem,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctOption,
    required this.explanation,
    required this.subject,
    this.year,
  });

  String optionText(String option) {
    switch (option) {
      case 'A':
        return optionA;
      case 'B':
        return optionB;
      case 'C':
        return optionC;
      case 'D':
        return optionD;
      default:
        return '';
    }
  }

  String get correctText => optionText(correctOption);

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
}
