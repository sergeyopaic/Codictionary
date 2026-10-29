/// Light, dark, or follow the system.
enum ThemePreference { system, light, dark }

/// User preferences kept between launches.
class AppSettings {
  const AppSettings({this.theme = ThemePreference.system});

  final ThemePreference theme;

  AppSettings copyWith({ThemePreference? theme}) =>
      AppSettings(theme: theme ?? this.theme);
}
