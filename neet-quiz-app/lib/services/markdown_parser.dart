import '../models/question.dart';

class MarkdownParser {
  static List<Question> parse(
    String markdown, {
    String subject = '',
    String? year,
  }) {
    final questions = <Question>[];
    String currentSubject = subject;

    final blocks = _splitBlocks(markdown);

    for (final block in blocks) {
      if (block.startsWith('## ') && !block.startsWith('### ')) {
        currentSubject = block.substring(3).trim();
        continue;
      }
      final q = _parseBlock(block, subject: currentSubject, year: year);
      if (q != null) questions.add(q);
    }

    return questions;
  }

  static List<String> _splitBlocks(String markdown) {
    final lines = markdown.split('\n');
    final blocks = <String>[];
    final current = StringBuffer();

    for (final line in lines) {
      if (line.startsWith('## ') && !line.startsWith('### ')) {
        if (current.isNotEmpty) {
          blocks.add(current.toString().trim());
          current.clear();
        }
        blocks.add(line);
      } else if (RegExp(r'^### Q\d+').hasMatch(line)) {
        if (current.isNotEmpty) {
          blocks.add(current.toString().trim());
          current.clear();
        }
        current.writeln(line);
      } else {
        current.writeln(line);
      }
    }
    if (current.isNotEmpty) blocks.add(current.toString().trim());

    return blocks;
  }

  static Question? _parseBlock(
    String block, {
    required String subject,
    String? year,
  }) {
    if (!RegExp(r'^### Q\d+').hasMatch(block)) return null;

    final lines = block.split('\n');
    final header = lines[0];

    final headerMatch =
        RegExp(r'### Q(\d+)\s*[—–-]\s*(.+)').firstMatch(header);
    if (headerMatch == null) return null;

    final number = int.tryParse(headerMatch.group(1)!) ?? 0;
    final topic = headerMatch.group(2)!.trim();

    String? optionA, optionB, optionC, optionD;
    String correctOption = '';
    String explanation = '';
    final stemLines = <String>[];
    bool inDetails = false;
    bool optionsStarted = false;

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i];

      if (line.contains('<details>')) {
        inDetails = true;
        continue;
      }
      if (line.contains('</details>')) {
        inDetails = false;
        continue;
      }
      if (line.contains('<summary>')) continue;

      if (inDetails) {
        final answerMatch = RegExp(r'\*\*([A-D])[\.\s]').firstMatch(line);
        if (answerMatch != null) {
          correctOption = answerMatch.group(1)!;
          final expMatch =
              RegExp(r'\*\*[A-D][\.\s][^*]*\*\*\s*[—–-]\s*(.+)').firstMatch(line);
          if (expMatch != null) {
            explanation = expMatch.group(1)!.trim();
          }
        } else if (correctOption.isNotEmpty &&
            line.trim().isNotEmpty &&
            !line.contains('Answer')) {
          explanation = explanation.isEmpty
              ? line.trim()
              : '$explanation ${line.trim()}';
        }
        continue;
      }

      if (line.startsWith('- A.') || line.startsWith('- A ')) {
        optionA = line.replaceFirst(RegExp(r'^- A[\.\s]\s*'), '').trim();
        optionsStarted = true;
      } else if (line.startsWith('- B.') || line.startsWith('- B ')) {
        optionB = line.replaceFirst(RegExp(r'^- B[\.\s]\s*'), '').trim();
      } else if (line.startsWith('- C.') || line.startsWith('- C ')) {
        optionC = line.replaceFirst(RegExp(r'^- C[\.\s]\s*'), '').trim();
      } else if (line.startsWith('- D.') || line.startsWith('- D ')) {
        optionD = line.replaceFirst(RegExp(r'^- D[\.\s]\s*'), '').trim();
      } else if (!optionsStarted && line.trim().isNotEmpty) {
        stemLines.add(line.trim());
      }
    }

    if (optionA == null ||
        optionB == null ||
        optionC == null ||
        optionD == null ||
        correctOption.isEmpty) {
      return null;
    }

    return Question(
      number: number,
      topic: topic,
      stem: stemLines.join(' '),
      optionA: optionA,
      optionB: optionB,
      optionC: optionC,
      optionD: optionD,
      correctOption: correctOption,
      explanation: explanation,
      subject: subject,
      year: year,
    );
  }
}
