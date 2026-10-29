import 'package:flutter/material.dart';

import 'confirm_dialog.dart';
import '../l10n/app_strings.dart';

/// Shows a confirmation dialog for bulk deletion of words.
/// Returns true if the user confirms deletion, false otherwise.
Future<bool> showConfirmBulkDeleteDialog(BuildContext context, int count) {
  return showConfirmDialog(
    context,
    title: context.s.deleteWordsTitle(count),
    message: context.s.deleteWordsMessage,
    confirmLabel: context.s.delete,
  );
}
