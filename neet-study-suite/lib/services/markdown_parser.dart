import '../models/question.dart';

class MarkdownParser {
  static List<Question> parse(String markdown, {String source = ''}) {
    final questions = <Question>[];
    final blocks = _splitBlocks(markdown);

    for (final block in blocks) {
      final q = _parseBlock(block, source: source);
      if (q != null && !q.isImageBased) questions.add(q);
    }
    return questions;
  }

  static List<String> _splitBlocks(String md) {
    final blocks = <String>[];
    final lines = md.split('\n');
    StringBuffer? current;

    for (final line in lines) {
      if (line.startsWith('### Q')) {
        if (current != null) blocks.add(current.toString().trim());
        current = StringBuffer()..writeln(line);
      } else if (current != null) {
        current.writeln(line);
      }
    }
    if (current != null) blocks.add(current.toString().trim());
    return blocks;
  }

  static Question? _parseBlock(String block, {String source = ''}) {
    try {
      final lines = block.split('\n');
      if (lines.isEmpty) return null;

      // Parse header: "### Q42 — Topic label"
      final header = lines[0];
      final headerMatch = RegExp(r'^### (Q\d+)').firstMatch(header);
      if (headerMatch == null) return null;
      final qNum = headerMatch.group(1)!;
      final qNumInt = int.tryParse(qNum.substring(1));

      // Collect stem lines (before first option)
      final stemLines = <String>[];
      final options = <String, String>{};
      String answer = '';
      String explanation = '';
      bool inDetails = false;

      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty && stemLines.isEmpty) continue;

        if (line.startsWith('- A.') || line.startsWith('- A)')) {
          options['A'] = _cleanOption(line.substring(4).trim());
        } else if (line.startsWith('- B.') || line.startsWith('- B)')) {
          options['B'] = _cleanOption(line.substring(4).trim());
        } else if (line.startsWith('- C.') || line.startsWith('- C)')) {
          options['C'] = _cleanOption(line.substring(4).trim());
        } else if (line.startsWith('- D.') || line.startsWith('- D)')) {
          options['D'] = _cleanOption(line.substring(4).trim());
        } else if (line.startsWith('<details>')) {
          inDetails = true;
        } else if (inDetails && line.startsWith('**')) {
          final answerMatch = RegExp(r'^\*\*([A-D])\.').firstMatch(line);
          if (answerMatch != null) {
            answer = answerMatch.group(1)!;
            // Extract explanation after "—" or "–"
            final dashIdx = line.indexOf('—');
            final dashIdx2 = line.indexOf('–');
            final idx = dashIdx >= 0 ? dashIdx : dashIdx2;
            if (idx >= 0 && idx + 1 < line.length) {
              explanation = line.substring(idx + 1).trim()
                  .replaceAll('**', '').trim();
            }
          }
        } else if (!inDetails && options.isEmpty) {
          if (line.isNotEmpty && !line.startsWith('#')) {
            stemLines.add(line);
          }
        }
      }

      if (options.length < 4 || answer.isEmpty) return null;

      final stem = stemLines.join(' ').trim();
      if (stem.isEmpty) return null;

      // Derive subject from source (e.g., 'anatomy' or 'year_2025')
      final subject = _extractSubject(source, header);

      return Question(
        id: '${source}_$qNum',
        stem: stem,
        optionA: options['A']!,
        optionB: options['B']!,
        optionC: options['C']!,
        optionD: options['D']!,
        correctOption: answer,
        explanation: explanation.isNotEmpty ? explanation : 'See standard reference.',
        subject: subject,
        year: _extractYear(source),
        questionNumber: qNumInt,
      );
    } catch (_) {
      return null;
    }
  }

  static String _cleanOption(String s) => s.replaceAll('**', '').trim();

  static String _extractSubject(String source, String header) {
    // If source is a subject key, use its display name
    const subjectKeys = [
      'anatomy', 'physiology', 'biochemistry', 'pathology', 'microbiology',
      'pharmacology', 'forensic-medicine', 'community-medicine', 'medicine',
      'surgery', 'obstetrics-gynaecology', 'pediatrics', 'orthopaedics',
      'ent', 'ophthalmology', 'dermatology', 'psychiatry', 'radiology',
      'anaesthesia',
    ];
    for (final s in subjectKeys) {
      if (source.contains(s)) return s;
    }
    // For year files, extract from ## Subject header (not perfect without context)
    return 'General';
  }

  static String? _extractYear(String source) {
    final m = RegExp(r'20\d{2}').firstMatch(source);
    return m?.group(0);
  }
}
