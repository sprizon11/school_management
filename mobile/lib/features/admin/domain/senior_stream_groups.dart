const seniorStreamGroups = [
  'Accounts',
  'Business Maths',
  'Commerce',
  'Computer Science',
  'B.Sc Computer Science',
  'Biology (Science)',
  'Pure Science',
  'Arts',
  'Vocational',
];

bool isSeniorGrade(int grade) => grade == 11 || grade == 12;

String classDropdownLabel(Map<String, dynamic> c) {
  final grade = c['grade'];
  final section = '${c['section'] ?? ''}';
  final name = '${c['name'] ?? 'Class $grade-$section'}';
  if (grade == 11 || grade == 12) {
    final group = (c['streamGroup'] ?? c['category'] ?? '').toString().trim();
    if (group.isNotEmpty) {
      return '$name ($grade-$section · $group)';
    }
  }
  return '$name ($grade-$section)';
}
