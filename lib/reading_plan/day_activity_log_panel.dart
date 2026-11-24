import 'package:material_ui/material_ui.dart';
import 'package:gbt/common/book_name.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:gbt/reading_plan/day_activity_log_view_model.dart';
import 'package:gbt/reading_plan/number_stepper.dart';

typedef NavigateToDayActivityLogRoute =
    Future<void> Function(
      BuildContext context,
      DateTime date, {
      required int readingPlanId,
    });

class DayActivityLogPanel extends StatefulWidget {
  final DayActivityLogViewModel viewModel;

  const DayActivityLogPanel({super.key, required this.viewModel});

  static Future<void> navigateTo(
    BuildContext context,
    DateTime date, {
    required int readingPlanId,
  }) async {
    DayActivityLogViewModel viewModel;
    try {
      viewModel = await DayActivityLogViewModel.create(
        readingPlanId: readingPlanId,
        date: date,
      );

      if (!context.mounted) {
        viewModel.dispose();
        return;
      }
    } catch (_) {
      if (!context.mounted) return;

      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errorLoadingContent)));
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
        Align(
          alignment: Alignment.centerRight,
          child: Transform.translate(
            offset: const Offset(iconInset, 0),
            child: IconButton(
              key: const ValueKey('addManualSessionButton'),
              style: iconStyle,
              icon: const Icon(Icons.add),
              tooltip: AppLocalizations.of(context)!.addManualSession,
              onPressed: _showAddManualSessionDialog,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddManualSessionDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final input = await showDialog<_ManualSessionInput>(
      context: context,
      builder: (context) => const _AddManualSessionDialog(),
    );
    if (input == null || !mounted) return;

    try {
      await viewModel.addManualSession(
        minutes: input.minutes,
        verses: input.verses,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorMessage(error.toString()))),
      );
    }
  }

  Future<void> _deleteManualSession(SessionDetails session) async {
    final sessionId = session.rsSession.id;
    if (sessionId == null) return;

    try {
      await viewModel.deleteManualSession(sessionId);
    } catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorMessage(error.toString()))),
      );
    }
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
    final description = session.rsSession.isManual
        ? l10n.manuallyAdded
        : references.isEmpty
        ? l10n.noVersesRead
        : references;

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
            children: [
              Expanded(child: _sessionLabel(session, style)),
              const SizedBox(width: 8),
              Text(
                "${_formatMinutes(viewModel.minutesFor(session))} "
                "${l10n.minutesShort} • "
                "${session.rsSession.verses} ${l10n.verses}",
                style: style,
                textAlign: TextAlign.end,
              ),
            ],
          ),
          Text(description),
        ],
      ),
    );
  }

  Widget _sessionLabel(SessionDetails session, TextStyle style) {
    final rsSession = session.rsSession;
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            _formatTime(session.rsSession.startTime),
            style: style,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (rsSession.isManual) ...[
          const SizedBox(width: 4),
          SizedBox(
            width: 18,
            height: 18,
            child: IconButton(
              key: ValueKey('deleteManualSession-${rsSession.id}'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 18, height: 18),
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              iconSize: 16,
              color: colorScheme.error,
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.delete,
              onPressed: () => _deleteManualSession(session),
            ),
          ),
        ],
      ],
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
    final references = <String>[];
    int? previousBookId;

    for (final entry in progress) {
      final includeBook = entry.bookId != previousBookId;
      references.add(_progressTitle(entry, includeBook: includeBook));
      previousBookId = entry.bookId;
    }

    return references.join(', ');
  }

  String _progressTitle(DetailedProgess entry, {required bool includeBook}) {
    final reference = entry.fromVerse == entry.toVerse
        ? "${entry.chapter}:${entry.fromVerse}"
        : "${entry.chapter}:${entry.fromVerse}-${entry.toVerse}";

    if (!includeBook) return reference;
    return "${bookNameForId(context, entry.bookId)} $reference";
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

class _ManualSessionInput {
  const _ManualSessionInput({required this.minutes, required this.verses});

  final double minutes;
  final int verses;
}

class _AddManualSessionDialog extends StatefulWidget {
  const _AddManualSessionDialog();

  @override
  State<_AddManualSessionDialog> createState() =>
      _AddManualSessionDialogState();
}

class _AddManualSessionDialogState extends State<_AddManualSessionDialog> {
  num _minutes = 0;
  num _verses = 0;
  String? _error;

  void _setMinutes(num value) {
    setState(() {
      _minutes = value;
      _error = null;
    });
  }

  void _setVerses(num value) {
    setState(() {
      _verses = value;
      _error = null;
    });
  }

  void _submit() {
    final l10n = AppLocalizations.of(context)!;
    final minutes = _minutes.toDouble();
    final verses = _verses.toInt();

    final isValid =
        minutes.isFinite &&
        minutes >= 0 &&
        verses >= 0 &&
        !((minutes * 60).round() == 0 && verses == 0);

    if (!isValid) {
      setState(() {
        _error = l10n.invalidManualSession;
      });
      return;
    }

    Navigator.of(
      context,
    ).pop(_ManualSessionInput(minutes: minutes, verses: verses));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    const labelStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w500);
    const actionStyle = TextStyle(fontWeight: FontWeight.bold);

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
      contentPadding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
      actionsPadding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
      title: Text(
        l10n.addSession,
        key: const ValueKey('manualSessionTitle'),
        textAlign: TextAlign.center,
      ),
      content: Center(
        heightFactor: 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                NumberStepper(
                  key: const ValueKey('manualMinutesStepper'),
                  keyPrefix: 'manual-minutes',
                  initialValue: _minutes,
                  minValue: 0,
                  allowDecimal: true,
                  onChanged: _setMinutes,
                ),
                Text(l10n.minutes, style: labelStyle),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                NumberStepper(
                  key: const ValueKey('manualVersesStepper'),
                  keyPrefix: 'manual-verses',
                  initialValue: _verses,
                  minValue: 0,
                  onChanged: _setVerses,
                ),
                Text(l10n.verses, style: labelStyle),
              ],
            ),
            if (_error != null)
              Text(_error!, style: TextStyle(color: colorScheme.error)),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('manualSessionCancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel, style: actionStyle),
        ),
        FilledButton(
          key: const ValueKey('manualSessionSubmit'),
          onPressed: _submit,
          child: Text(l10n.addSession, style: actionStyle),
        ),
      ],
    );
  }
}
