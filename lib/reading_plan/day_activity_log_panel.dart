import 'package:material_ui/material_ui.dart';
import 'package:gbt/common/book_name.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:gbt/reading_plan/day_activity_log_view_model.dart';

typedef DayActivityLogNavigator =
    Future<void> Function(BuildContext context, DateTime date);

class DayActivityLogPanel extends StatefulWidget {
  final DayActivityLogViewModel viewModel;

  const DayActivityLogPanel({super.key, required this.viewModel});

  static Future<void> navigateTo(
    BuildContext context,
    DateTime date, {
    required int readingPlanId,
  }) async {
    final viewModel = DayActivityLogViewModel(
      readingPlanId: readingPlanId,
      date: date,
    );

    try {
      await viewModel.initialize();
    } catch (_) {
      viewModel.dispose();
      if (!context.mounted) return;

      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errorLoadingContent)));
      return;
    }

    if (!context.mounted) {
      viewModel.dispose();
      return;
    }

    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (context) => DayActivityLogPanel(viewModel: viewModel),
        ),
      );
    } catch (_) {
      viewModel.dispose();
      rethrow;
    }
  }

  @override
  State<DayActivityLogPanel> createState() => _DayActivityLogPanelState();
}

class _DayActivityLogPanelState extends State<DayActivityLogPanel> {
  late final DayActivityLogViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = widget.viewModel;
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          return Column(
            spacing: 16,
            children: [
              _header(),
              _totals(),
              Expanded(child: _readingSection()),
            ],
          );
        },
      ),
    );
  }

  Widget _header() {
    const iconInset = 6.0;
    final iconStyle = IconButton.styleFrom(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            _formatDate(viewModel.date),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Transform.translate(
            offset: const Offset(-iconInset, 0),
            child: IconButton(
              style: iconStyle,
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _readingSection() {
    return ListView(children: viewModel.sessions.map(_sessionCard).toList());
  }

  Widget _sessionCard(SessionDetails session) {
    final l10n = AppLocalizations.of(context)!;
    final style = TextStyle(
      fontSize: 15,
      color: Theme.of(context).colorScheme.onSurface,
      fontWeight: FontWeight.bold,
    );
    final references = _references(viewModel.referencesFor(session));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatTime(session.rsSession.startTime), style: style),
              Text(
                "${_formatMinutes(viewModel.minutesFor(session))} "
                "${l10n.minutesShort} • "
                "${session.rsSession.verses} ${l10n.verses}",
                style: style,
              ),
            ],
          ),
          if (references.isNotEmpty) Text(references),
        ],
      ),
    );
  }

  Widget _totals() {
    final l10n = AppLocalizations.of(context)!;
    final style = TextStyle(
      fontSize: 18,
      color: Theme.of(context).colorScheme.onSurface,
      fontWeight: FontWeight.bold,
    );

    return Text(
      "${_formatMinutes(viewModel.totalMinutes)} ${l10n.minutesShort} • "
      "${viewModel.totalVerses} ${l10n.verses}",
      style: style,
    );
  }

  String _references(List<DetailedProgess> progress) {
    return progress.map(_progressTitle).join(', ');
  }

  String _progressTitle(DetailedProgess entry) {
    final book = bookNameForId(context, entry.bookId);
    if (entry.fromVerse == entry.toVerse) {
      return "$book ${entry.chapter}:${entry.fromVerse}";
    }
    return "$book ${entry.chapter}:${entry.fromVerse}-${entry.toVerse}";
  }

  String _formatDate(DateTime date) {
    final l10n = AppLocalizations.of(context)!;
    final month = l10n.months(date.month.toString());
    return "$month ${date.day}, ${date.year}";
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  String _formatMinutes(double minutes) {
    return minutes == minutes.roundToDouble()
        ? minutes.toStringAsFixed(0)
        : minutes.toStringAsFixed(1);
  }
}
