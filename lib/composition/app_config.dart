import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Non-UI settings read at startup. Missing values mean local mode for that
/// service; a missing `.env` is not an error.
class AppConfig {
  const AppConfig({this.openAiApiKey = '', this.deeplApiKey = ''});

  final String openAiApiKey;
  final String deeplApiKey;

  static Future<AppConfig> load() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // No or unreadable .env: run without AI and translation.
      return const AppConfig();
    }
    return AppConfig(
      openAiApiKey: dotenv.env['OPENAI_API_KEY'] ?? '',
      deeplApiKey: dotenv.env['DEEPL_API_KEY'] ?? '',
    );
  }
}
