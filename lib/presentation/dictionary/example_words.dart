/// Sample entries a new user can add with one tap from the empty dictionary.
/// They ship with ready-made explanations, so adding them needs no AI call.
/// Never added automatically.
const List<({String source, String target, String explanation})>
exampleWords = [
  (
    source: 'serendipity',
    target: 'счастливая случайность',
    explanation:
        'Удачное открытие, сделанное случайно, когда искал что-то другое. '
        'Пример: Meeting my best friend was pure serendipity.',
  ),
  (
    source: 'resilient',
    target: 'стойкий',
    explanation:
        'Способный быстро восстанавливаться после трудностей. Говорят о людях, '
        'системах, материалах. Пример: Kids are surprisingly resilient.',
  ),
  (
    source: 'to break the ice',
    target: 'растопить лёд',
    explanation:
        'Снять неловкость в начале общения. Пример: He told a joke to break '
        'the ice at the meeting.',
  ),
];
