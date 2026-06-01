import 'package:http/http.dart' as http;

class GithubService {
  static const String _owner = 'skm9097';
  static const String _repo = 'neet-pg2026';
  static const String _branch = 'main';
  static const String _base =
      'https://raw.githubusercontent.com/$_owner/$_repo/$_branch/question-bank';

  static const List<String> availableYears = [
    '2025', '2024', '2023', '2022', '2021',
    '2020', '2019', '2018', '2017', '2016', '2015',
  ];

  static const List<String> availableSubjects = [
    'anatomy', 'physiology', 'biochemistry', 'pathology', 'microbiology',
    'pharmacology', 'forensic-medicine', 'community-medicine', 'medicine',
    'surgery', 'obstetrics-gynaecology', 'pediatrics', 'orthopaedics',
    'ent', 'ophthalmology', 'dermatology', 'psychiatry', 'radiology',
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
    'obstetrics-gynaecology': 'OBG',
    'pediatrics': 'Paediatrics',
    'orthopaedics': 'Orthopaedics',
    'ent': 'ENT',
    'ophthalmology': 'Ophthalmology',
    'dermatology': 'Dermatology',
    'psychiatry': 'Psychiatry',
    'radiology': 'Radiology',
    'anaesthesia': 'Anaesthesia',
  };

  Future<String> fetchYearMarkdown(String year) async {
    final url = '$_base/$year/questions.md';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) return response.body;
    throw Exception('Failed to load $year questions (HTTP ${response.statusCode})');
  }

  Future<String> fetchSubjectMarkdown(String subject) async {
    final url = '$_base/subject-wise/$subject.md';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) return response.body;
    throw Exception('Failed to load $subject questions (HTTP ${response.statusCode})');
  }
}
