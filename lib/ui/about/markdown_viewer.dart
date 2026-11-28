import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/messaging/messenger_view_model.dart';
import 'package:url_launcher/url_launcher.dart';

class LocalizedMarkdownViewer extends StatelessWidget {
  LocalizedMarkdownViewer({
    super.key,
    required this.fileName,
    this.splitMarker,
    this.insertion,
  });

  final String fileName;
  final String? splitMarker;
  final Widget? insertion;
  final _messenger = getIt<MessengerViewModel>();

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
        return AppLocalizations.of(context)!.errorMessage(e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _loadMarkdown(context),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final data = snapshot.data!;
          final marker = splitMarker;
          if (marker == null || !data.contains(marker)) {
            return _buildMarkdown(context, data);
          }

          final parts = data.split(marker);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMarkdown(context, parts.first.trimRight()),
              ?insertion,
              _buildMarkdown(context, parts.skip(1).join(marker).trimLeft()),
            ],
          );
        } else if (snapshot.hasError) {
          return Text(AppLocalizations.of(context)!.errorLoadingContent);
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  Widget _buildMarkdown(BuildContext context, String data) {
    final theme = Theme.of(context);
    final bodyMedium = theme.textTheme.bodyMedium;
    return MarkdownBody(
      data: data,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: bodyMedium,
        code: bodyMedium?.copyWith(
          backgroundColor: theme.cardTheme.color,
          fontFamily: 'monospace',
          fontSize: (bodyMedium.fontSize ?? 14) * 0.85,
        ),
        h1: theme.textTheme.headlineSmall,
        h2: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        h3: theme.textTheme.titleMedium,
        h4: theme.textTheme.bodyLarge,
        h5: theme.textTheme.bodyLarge,
        h6: theme.textTheme.bodyLarge,
        a: bodyMedium?.copyWith(color: theme.colorScheme.primary),
        blockquote: bodyMedium,
        img: bodyMedium,
        listBullet: bodyMedium,
        tableBody: bodyMedium,
        tableHead: bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        tableBorder: TableBorder.all(color: theme.dividerColor),
      ),
      onTapLink: (text, href, title) async {
        if (href == null) return;

        final l10n = AppLocalizations.of(context)!;

        // CASE 1: Specific "Copy Email" action
        if (href.startsWith('copy-email:')) {
          final email = href.replaceFirst('copy-email:', '');

          await Clipboard.setData(ClipboardData(text: email));

          _messenger.showSuccess(l10n.emailCopied);
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
  }
}
