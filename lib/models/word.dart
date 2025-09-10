import 'package:uuid/uuid.dart';

class Word {
  final String id;
  final String eng;
  final String rus;
  final String? desc;
  final String? descLong;
  final DateTime addedAt;

  Word({
    required this.id,
    required this.eng,
    required this.rus,
    this.desc,
    this.descLong,
    required this.addedAt,
  });

  Word copyWith({String? eng, String? rus, String? desc, String? descLong, DateTime? addedAt}) =>
      Word(
        id: id,
        eng: eng ?? this.eng,
        rus: rus ?? this.rus,
        desc: desc ?? this.desc,
        descLong: descLong ?? this.descLong,
        addedAt: addedAt ?? this.addedAt,
      );

  factory Word.fromMap(Map<String, dynamic> m) {
    final rawId = m['id'];
    final id = (rawId is String && rawId.isNotEmpty)
        ? rawId
        : const Uuid().v4();
    final eng = (m['eng'] ?? '') as String;
    final rus = (m['rus'] ?? '') as String;
    // Backward compatibility: original field was 'desc' (short). New optional 'descLong'.
    final desc = (m['descShort'] as String?) ?? (m['desc'] as String?);
    final descLong = m['descLong'] as String?;

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

    return Word(id: id, eng: eng, rus: rus, desc: desc, descLong: descLong, addedAt: addedAt);
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'eng': eng,
    'rus': rus,
    // Persist both: keep legacy 'desc' for short, and explicit 'descShort' + 'descLong'.
    if (desc != null) 'desc': desc,
    if (desc != null) 'descShort': desc,
    if (descLong != null) 'descLong': descLong,
    'addedAt': addedAt.toUtc().toIso8601String(),
  };
}
