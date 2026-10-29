import 'package:flutter/material.dart';

import 'confirm_dialog.dart';
import '../l10n/app_strings.dart';

/// Shows a confirmation dialog for deleting a single word.
/// Returns true if the user confirms deletion, false otherwise.
Future<bool> showConfirmDeleteDialog(BuildContext context, String wordEng) {
  return showConfirmDialog(
    context,
    title: context.s.deleteWordTitle,
    message: context.s.deleteWordMessage(wordEng),
    confirmLabel: context.s.delete,
  );
}
