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

  factory Word.fromMap(Map<String, dynamic> m) => Word(
    id: (m['id'] ?? '') as String,
    eng: (m['eng'] ?? '') as String,
    rus: (m['rus'] ?? '') as String,
    desc: m['desc'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'eng': eng,
    'rus': rus,
    if (desc != null) 'desc': desc,
  };
}
