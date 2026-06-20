import 'package:http/http.dart' as http;

class GitHubService {
  static const String _branch = 'main';
  static const String _baseUrl =
      'https://raw.githubusercontent.com/skm9097/neet-pg2026/$_branch';

  static const List<String> years = [
    '2018', '2019', '2020', '2021', '2022', '2023', '2024', '2025'
  ];

  static const List<String> subjects = [
    'anatomy',
    'physiology',
    'biochemistry',
    'pathology',
    'microbiology',
    'pharmacology',
    'forensic-medicine',
    'community-medicine',
    'medicine',
    'surgery',
    'obstetrics-gynaecology',
    'pediatrics',
    'orthopaedics',
    'ent',
    'ophthalmology',
    'dermatology',
    'psychiatry',
    'radiology',
    'anaesthesia',
  ];

  static const Map<String, String> subjectDisplayNames = {
    'anatomy': 'Anatomy',
    'physiology': 'Physiology',
    'biochemistry': 'Biochemistry',
    'pathology': 'Pathology',
    'microbiology': 'Microbiology',
    'pharmacology': 'Pharmacology',
    'forensic-medicine': 'Forensic Medicine',
    'community-medicine': 'Community Medicine',
    'medicine': 'Medicine',
    'surgery': 'Surgery',
    'obstetrics-gynaecology': 'Obs & Gynae',
    'pediatrics': 'Paediatrics',
    'orthopaedics': 'Orthopaedics',
    'ent': 'ENT',
    'ophthalmology': 'Ophthalmology',
    'dermatology': 'Dermatology',
    'psychiatry': 'Psychiatry',
    'radiology': 'Radiology',
    'anaesthesia': 'Anaesthesia',
  };

  Future<String> fetchYearQuestions(String year) =>
      _fetch('$_baseUrl/question-bank/$year/questions.md');

  Future<String> fetchSubjectQuestions(String subject) =>
      _fetch('$_baseUrl/question-bank/subject-wise/$subject.md');

  Future<String> _fetch(String url) async {
    final response = await http.get(Uri.parse(url)).timeout(
      const Duration(seconds: 15),
    );
    if (response.statusCode == 200) return response.body;
    throw Exception('HTTP ${response.statusCode}: $url');
  }
}
