import 'package:uuid/uuid.dart';

class Word {
  final String id;
  final String eng;
  final String rus;
  final String? desc;
  final DateTime addedAt;

  Word({
    required this.id,
    required this.eng,
    required this.rus,
    this.desc,
    required this.addedAt,
  });

  Word copyWith({String? eng, String? rus, String? desc, DateTime? addedAt}) => Word(
        id: id,
        eng: eng ?? this.eng,
        rus: rus ?? this.rus,
        desc: desc ?? this.desc,
        addedAt: addedAt ?? this.addedAt,
      );

  factory Word.fromMap(Map<String, dynamic> m) {
    final rawId = m['id'];
    final id = (rawId is String && rawId.isNotEmpty) ? rawId : const Uuid().v4();
    final eng = (m['eng'] ?? '') as String;
    final rus = (m['rus'] ?? '') as String;
    final desc = m['desc'] as String?;

    DateTime addedAt;
    final rawAddedAt = m['addedAt'];
    if (rawAddedAt is String && rawAddedAt.isNotEmpty) {
      try {
        addedAt = DateTime.parse(rawAddedAt);
      } catch (_) {
        addedAt = DateTime.now();
      }
    } else {
      // Preexisting entries without timestamp: use current time
      addedAt = DateTime.now();
    }

    return Word(id: id, eng: eng, rus: rus, desc: desc, addedAt: addedAt);
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'eng': eng,
        'rus': rus,
        if (desc != null) 'desc': desc,
        'addedAt': addedAt.toUtc().toIso8601String(),
      };
}
