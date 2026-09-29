import 'package:flutter/material.dart';

import 'confirm_dialog.dart';

/// Shows a confirmation dialog for deleting a single word.
/// Returns true if the user confirms deletion, false otherwise.
Future<bool> showConfirmDeleteDialog(BuildContext context, String wordEng) {
  return showConfirmDialog(
    context,
    title: 'Delete this word?',
    message: '"$wordEng" will be removed from your dictionary.',
  );
}
