import 'package:uuid/uuid.dart';

class Word {
  final String id;
  final String eng;
  final String rus;
  final String? desc;

  const Word({
    required this.id,
    required this.eng,
    required this.rus,
    this.desc,
  });

  Word copyWith({String? eng, String? rus, String? desc}) => Word(
    id: id,
    eng: eng ?? this.eng,
    rus: rus ?? this.rus,
    desc: desc ?? this.desc,
  );

  factory Word.fromMap(Map<String, dynamic> m) {
    final rawId = m['id'];
    final id = (rawId is String && rawId.isNotEmpty)
        ? rawId
        : const Uuid().v4();
    final eng = (m['eng'] ?? '') as String;
    final rus = (m['rus'] ?? '') as String;
    final desc = m['desc'] as String?;
    return Word(id: id, eng: eng, rus: rus, desc: desc);
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'eng': eng,
    'rus': rus,
    if (desc != null) 'desc': desc,
  };
}
