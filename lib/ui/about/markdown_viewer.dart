import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class LocalizedMarkdownViewer extends StatelessWidget {
  final String fileName;

  const LocalizedMarkdownViewer({super.key, required this.fileName});

  Future<String> _loadMarkdown(BuildContext context) async {
    final locale = Localizations.localeOf(context);
    final languageCode = locale.languageCode;

    // 1. Try to load the localized file (e.g., credits_es.md)
    try {
      return await rootBundle.loadString(
        'assets/l10n/${fileName}_$languageCode.md',
      );
    } catch (_) {
      // 2. Fallback to English if specific locale not found (e.g., credits_en.md)
      try {
        return await rootBundle.loadString('assets/l10n/${fileName}_en.md');
      } catch (e) {
        return "Error loading credits: $e";
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _loadMarkdown(context),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return MarkdownBody(
            data: snapshot.data!,
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                .copyWith(
                  p: Theme.of(context).textTheme.bodyMedium,
                  h2: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  a: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
            onTapLink: (text, href, title) async {
              if (href == null) return;

              // CASE 1: Specific "Copy Email" action
              if (href.startsWith('copy-email:')) {
                final email = href.replaceFirst('copy-email:', '');

                await Clipboard.setData(ClipboardData(text: email));

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      // Use the exact localized string you wanted
                      content: Text(AppLocalizations.of(context)!.emailCopied),
                    ),
                  );
                }
              }
              // CASE 2: Standard Links (Web, etc)
              else {
                final Uri url = Uri.parse(href);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              }
            },
          );
        } else if (snapshot.hasError) {
          return Text('Error loading content.');
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}
