import 'package:flutter/services.dart';

/// Reusable formatter that limits input to [max] characters.
/// Delegates to Flutter's built-in [LengthLimitingTextInputFormatter].
class LetterLimitFormatter extends LengthLimitingTextInputFormatter {
  LetterLimitFormatter(super.max);
}
