import 'package:flutter/material.dart';

import 'confirm_dialog.dart';

/// Shows a confirmation dialog for bulk deletion of words.
/// Returns true if the user confirms deletion, false otherwise.
Future<bool> showConfirmBulkDeleteDialog(BuildContext context, int count) {
  return showConfirmDialog(
    context,
    title: count == 1 ? 'Delete 1 word?' : 'Delete $count words?',
    message: 'The selected words will be removed from your dictionary.',
  );
}
