import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Russian for the Material texts the app actually shows (back and close
/// tooltips, text selection menu, dialog labels), without the
/// `flutter_localizations` package (dependencies cannot be changed here).
/// Anything not overridden falls back to English. With `flutter_localizations`
/// added by maintainers this file can be replaced by
/// `GlobalMaterialLocalizations.delegate`.
class RuMaterialLocalizations extends DefaultMaterialLocalizations {
  const RuMaterialLocalizations();

  static const LocalizationsDelegate<MaterialLocalizations> delegate =
      _RuMaterialDelegate();

  @override
  String get backButtonTooltip => 'Назад';
  @override
  String get closeButtonTooltip => 'Закрыть';
  @override
  String get closeButtonLabel => 'Закрыть';
  @override
  String get deleteButtonTooltip => 'Удалить';
  @override
  String get clearButtonTooltip => 'Очистить';
  @override
  String get moreButtonTooltip => 'Ещё';
  @override
  String get showMenuTooltip => 'Показать меню';
  @override
  String get cancelButtonLabel => 'Отмена';
  @override
  String get okButtonLabel => 'ОК';
  @override
  String get copyButtonLabel => 'Копировать';
  @override
  String get cutButtonLabel => 'Вырезать';
  @override
  String get pasteButtonLabel => 'Вставить';
  @override
  String get selectAllButtonLabel => 'Выбрать все';
  @override
  String get lookUpButtonLabel => 'Найти';
  @override
  String get searchWebButtonLabel => 'Искать в интернете';
  @override
  String get shareButtonLabel => 'Поделиться';
  @override
  String get searchFieldLabel => 'Поиск';
  @override
  String get modalBarrierDismissLabel => 'Закрыть';
  @override
  String get menuDismissLabel => 'Закрыть меню';
  @override
  String get dialogLabel => 'Диалог';
  @override
  String get alertDialogLabel => 'Предупреждение';
  @override
  String get bottomSheetLabel => 'Нижняя панель';
  @override
  String get scrimLabel => 'Затемнение';
  @override
  String scrimOnTapHint(String modalRouteContentName) =>
      'Закрыть: $modalRouteContentName';
}

class _RuMaterialDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _RuMaterialDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ru';

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture(const RuMaterialLocalizations());

  @override
  bool shouldReload(_RuMaterialDelegate old) => false;
}

/// Cupertino texts (used by the iOS text selection menu) stay English for
/// every locale instead of failing for Russian.
class AnyLocaleCupertinoDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const AnyLocaleCupertinoDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      DefaultCupertinoLocalizations.load(locale);

  @override
  bool shouldReload(AnyLocaleCupertinoDelegate old) => false;
}
