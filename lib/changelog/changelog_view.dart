import 'dart:async';
import 'dart:ui' show SemanticsRole;

import 'package:gbt/changelog/changelog_entry.dart';
import 'package:gbt/changelog/changelog_service.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/messaging/messenger_view_model.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

class ChangelogView extends StatefulWidget {
  ChangelogView({super.key, required this.entries});

  final List<ChangelogEntry> entries;
  final _service = getIt<ChangelogService>();

  static Future<void> navigateTo(BuildContext context) async {
    final changelogService = getIt<ChangelogService>();
    final messengerViewModel = getIt<MessengerViewModel>();
    final locale = Localizations.localeOf(context);

    List<ChangelogEntry> entries;
    try {
      entries = await changelogService.loadEntries(locale);
    } catch (_) {
      if (!context.mounted) return;

      final l10n = AppLocalizations.of(context)!;
      messengerViewModel.showError(l10n.errorLoadingContent);
      return;
    }

    if (!context.mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ChangelogView(entries: entries)),
    );
  }

  @override
  State<ChangelogView> createState() => _ChangelogViewState();
}

class _ChangelogViewState extends State<ChangelogView> {
  late final List<ChangelogEntry> _entries = List.unmodifiable(
    widget.entries.reversed,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(widget._service.markLatestSeen());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.changelog)),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _entries.length,
        itemBuilder: (context, index) {
          return _ChangelogCard(entry: _entries[index], locale: locale);
        },
      ),
    );
  }
}

class _ChangelogCard extends StatelessWidget {
  const _ChangelogCard({required this.entry, required this.locale});

  final ChangelogEntry entry;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final date = DateFormat.yMMMMd(locale.languageCode).format(entry.date);

    return Card(
      key: ValueKey('changelog-${entry.version}'),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Semantics(
              header: true,
              label: '${entry.version}, $date',
              excludeSemantics: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                spacing: 8,
                children: [
                  Text(entry.version, style: textTheme.titleMedium),
                  Text(date, style: textTheme.bodySmall),
                ],
              ),
            ),
            if (entry.summary != null)
              Semantics(
                container: true,
                label: entry.summary,
                excludeSemantics: true,
                child: Text(entry.summary!, style: textTheme.bodyMedium),
              ),
            Semantics(
              role: SemanticsRole.list,
              container: true,
              explicitChildNodes: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final change in entry.changes)
                    Semantics(
                      role: SemanticsRole.listItem,
                      label: change,
                      excludeSemantics: true,
                      child: _ChangelogBullet(text: change),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangelogBullet extends StatelessWidget {
  const _ChangelogBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          ExcludeSemantics(child: Text('•', style: style)),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}
