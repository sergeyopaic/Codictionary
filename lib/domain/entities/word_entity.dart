class WordEntity {
  final String id;
  final String source;
  final String target;
  final String? note;

  const WordEntity({
    required this.id,
    required this.source,
    required this.target,
    this.note,
  });
}
