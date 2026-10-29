/// A user-made collection of words.
///
/// A word can belong to several collections; the dictionary always contains
/// every word. Members are referenced by word id, so a deleted word simply
/// stops being shown and comes back with Undo.
class Vocabulary {
  final String id;
  final String name;
  final String description;
  final String iconPath;

  /// Member word ids in the order they were added.
  final List<String> wordIds;

  const Vocabulary({
    required this.id,
    required this.name,
    required this.description,
    required this.iconPath,
    this.wordIds = const [],
  });

  bool contains(String wordId) => wordIds.contains(wordId);

  Vocabulary copyWith({
    String? name,
    String? description,
    String? iconPath,
    List<String>? wordIds,
  }) => Vocabulary(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    iconPath: iconPath ?? this.iconPath,
    wordIds: wordIds ?? this.wordIds,
  );
}
