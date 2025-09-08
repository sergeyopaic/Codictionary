import 'package:flutter/material.dart';
import '../../services/gpt_service.dart';

Future<void> showGPTTestDialog(BuildContext context, GptService gpt) async {
  final TextEditingController promptController = TextEditingController();
  String gptAnswer = 'Waiting for response...';
  await showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> sendPrompt() async {
            final prompt = promptController.text.trim();
            if (prompt.isEmpty) return;
            setState(() => gptAnswer = 'Loading...');
            try {
              final answer = await gpt.explainWord(prompt);
              if (!context.mounted) return;
              setState(() => gptAnswer = answer);
            } catch (e) {
              if (!context.mounted) return;
              setState(() => gptAnswer = 'Error: $e');
            }
          }

          return AlertDialog(
            title: const Text('GPT Test'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: promptController,
                  decoration: const InputDecoration(labelText: 'Enter prompt'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 420,
                  child: SingleChildScrollView(child: Text(gptAnswer)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              ElevatedButton(onPressed: sendPrompt, child: const Text('Send')),
            ],
          );
        },
      );
    },
  );
}
