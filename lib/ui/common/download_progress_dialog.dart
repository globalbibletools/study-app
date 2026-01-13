import 'package:flutter/material.dart';
import 'package:studyapp/services/download/cancel_token.dart';

class DownloadProgressDialog extends StatelessWidget {
  final ValueNotifier<double> progressNotifier;
  final VoidCallback onCancel;

  const DownloadProgressDialog({
    super.key,
    required this.progressNotifier,
    required this.onCancel,
  });

  static Future<void> show({
    required BuildContext context,
    required Future<void> Function(
      ValueNotifier<double> progress,
      CancelToken cancelToken,
    )
    task,
  }) async {
    final progressNotifier = ValueNotifier<double>(0.0);
    final cancelToken = CancelToken();

    // 1. Start the task
    final taskFuture = task(progressNotifier, cancelToken);

    // 2. Set up auto-close listener
    // We attach .catchError((_) {}) here to prevent "Unhandled Exception"
    // on this specific chain. The error will still propagate to 'taskFuture'
    // which we await below.
    taskFuture
        .whenComplete(() {
          if (context.mounted && !cancelToken.isCancelled) {
            Navigator.of(context).pop();
          }
        })
        .catchError((_) {
          // Swallow error here to prevent runtime crash.
          // The error is handled by the await taskFuture below.
        });

    // 3. Show the Dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return DownloadProgressDialog(
          progressNotifier: progressNotifier,
          onCancel: () {
            cancelToken.cancel();
            Navigator.of(context).pop();
          },
        );
      },
    );

    // 4. Wait for the task result
    // This will throw if the task failed or was canceled, passing the error to the caller.
    await taskFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ValueListenableBuilder<double>(
              valueListenable: progressNotifier,
              builder: (context, value, child) {
                final percentage = (value * 100).toStringAsFixed(0);
                return Text(
                  "$percentage%",
                  style: Theme.of(context).textTheme.bodyMedium,
                );
              },
            ),
            const SizedBox(width: 16),
            // Progress Bar and Percent
            Expanded(
              child: ValueListenableBuilder<double>(
                valueListenable: progressNotifier,
                builder: (context, value, child) {
                  return LinearProgressIndicator(
                    backgroundColor: Colors.white,
                    // valueColor: Theme.of(context).colorScheme.primary,
                    value: value,
                    borderRadius: BorderRadius.circular(4),
                    // minHeight: 8,
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            // Cancel Button (X)
            IconButton(onPressed: onCancel, icon: const Icon(Icons.close)),
          ],
        ),
      ),
    );
  }
}
