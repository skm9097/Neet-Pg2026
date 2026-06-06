import '../models/question.dart';

class MarkdownParser {
  static List<Question> parse(String markdown, {String source = ''}) {
    final questions = <Question>[];
    final lines = markdown.split('\n');
    String currentSubject = '';
    StringBuffer? block;

    void flush() {
      if (block == null) return;
      final q = _parseBlock(
        block.toString().trim(),
        source: source,
        subjectHint: currentSubject,
      );
      if (q != null && !q.isImageBased) questions.add(q);
      block = null;
    }

    for (final line in lines) {
      if (line.startsWith('## ') && !line.startsWith('### ')) {
        // Section heading like "## Anatomy" or "## General Medicine"
        flush();
        currentSubject = _headingToSubject(line.substring(3).trim());
      } else if (line.startsWith('### Q')) {
        flush();
        block = StringBuffer()..writeln(line);
      } else if (block != null) {
        block!.writeln(line);
      }
    }
    flush();
    return questions;
  }

  static Question? _parseBlock(String block,
      {String source = '', String subjectHint = ''}) {
    try {
      final lines = block.split('\n');
      if (lines.isEmpty) return null;

      final header = lines[0];
      final headerMatch = RegExp(r'^### (Q\d+)').firstMatch(header);
      if (headerMatch == null) return null;
      final qNum = headerMatch.group(1)!;
      final qNumInt = int.tryParse(qNum.substring(1));

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
            final dashIdx = line.indexOf('—');
            final dashIdx2 = line.indexOf('–');
            final idx = dashIdx >= 0 ? dashIdx : dashIdx2;
            if (idx >= 0 && idx + 1 < line.length) {
              explanation =
                  line.substring(idx + 1).trim().replaceAll('**', '').trim();
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

      // Subject priority: source (subject file) > section heading > fallback
      final subject = _extractSubject(source, subjectHint);

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

  static String _extractSubject(String source, String subjectHint) {
    // If source is a subject file key, that's the subject
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
    // For year files, use the section heading subject if available
    if (subjectHint.isNotEmpty && subjectHint != 'general') return subjectHint;
    return 'general';
  }

  // Map "## Anatomy" / "## General Medicine" → canonical subject key
  static String _headingToSubject(String heading) {
    final lower = heading.toLowerCase().trim();

    const exactMap = {
      'anatomy': 'anatomy',
      'physiology': 'physiology',
      'biochemistry': 'biochemistry',
      'pathology': 'pathology',
      'microbiology': 'microbiology',
      'pharmacology': 'pharmacology',
      'forensic medicine': 'forensic-medicine',
      'forensic medicine & toxicology': 'forensic-medicine',
      'forensic': 'forensic-medicine',
      'community medicine': 'community-medicine',
      'preventive & social medicine': 'community-medicine',
      'social & preventive medicine': 'community-medicine',
      'psm': 'community-medicine',
      'medicine': 'medicine',
      'general medicine': 'medicine',
      'internal medicine': 'medicine',
      'surgery': 'surgery',
      'general surgery': 'surgery',
      'obstetrics & gynaecology': 'obstetrics-gynaecology',
      'obstetrics and gynaecology': 'obstetrics-gynaecology',
      'obg': 'obstetrics-gynaecology',
      'obs & gynae': 'obstetrics-gynaecology',
      'obstetrics': 'obstetrics-gynaecology',
      'gynaecology': 'obstetrics-gynaecology',
      'paediatrics': 'pediatrics',
      'pediatrics': 'pediatrics',
      'orthopaedics': 'orthopaedics',
      'orthopedics': 'orthopaedics',
      'ent': 'ent',
      'ear, nose and throat': 'ent',
      'ophthalmology': 'ophthalmology',
      'dermatology': 'dermatology',
      'psychiatry': 'psychiatry',
      'radiology': 'radiology',
      'anaesthesia': 'anaesthesia',
      'anesthesia': 'anaesthesia',
    };

    if (exactMap.containsKey(lower)) return exactMap[lower]!;

    // Partial match fallback
    for (final entry in exactMap.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return 'general';
  }

  static String? _extractYear(String source) {
    final m = RegExp(r'20\d{2}').firstMatch(source);
    return m?.group(0);
  }
}
