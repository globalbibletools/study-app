import 'package:material_ui/material_ui.dart';
import 'package:gbt/common/book_name.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:gbt/ui/home/reading_plan/day_activity_log_view_model.dart';

class DayActivityLogPanel extends StatefulWidget {
  final int readingPlanId;
  final DateTime date;

  const DayActivityLogPanel({
    super.key,
    required this.readingPlanId,
    required this.date,
  });

  @override
  State<DayActivityLogPanel> createState() => _DayActivityLogPanelState();
}

class _DayActivityLogPanelState extends State<DayActivityLogPanel> {
  late final DayActivityLogViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = DayActivityLogViewModel(
      readingPlanId: widget.readingPlanId,
      date: widget.date,
    );
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Center(
          child: Container(
            width: 340,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: ListenableBuilder(
              listenable: viewModel,
              builder: (context, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    _header(),

                    const SizedBox(height: 10),

                    _readingSection(),

                    const SizedBox(height: 30),

                    _totals(),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          l10n.dismiss,
                          style: TextStyle(letterSpacing: 2),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final l10n = AppLocalizations.of(context)!;
    final sessionsLabel = viewModel.isRefreshing && viewModel.sessions.isEmpty
        ? ''
        : l10n.sessions(viewModel.sessionCount).toUpperCase();
    return Column(
      children: [
        Text(
          _formatDate(viewModel.date),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          sessionsLabel,
          style: const TextStyle(fontSize: 12, letterSpacing: 2),
        ),
      ],
    );
  }

  Widget _readingSection() {
    if (viewModel.loadError != null) {
      final l10n = AppLocalizations.of(context)!;
      return Text(l10n.errorLoadingContent, textAlign: TextAlign.center);
    }

    if (viewModel.isRefreshing && viewModel.sessions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final screenHeight = MediaQuery.of(context).size.height;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.5),
      child: ListView(
        shrinkWrap: true,
        children: viewModel.sessions.map(_sessionCard).toList(),
      ),
    );
  }

  Widget _sessionCard(SessionDetails session) {
    final sessionMinutes = viewModel.minutesFor(session);
    final sessionVerses = session.rsSession.verses;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatTimeRange(session.rsSession),
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.5,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...session.progress.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _sessionRow(
                title: _progressTitle(entry),
                verses: entry.toVerse - entry.fromVerse + 1,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _sessionTotals(sessionMinutes, sessionVerses),
        ],
      ),
    );
  }

  Widget _sessionRow({required String title, required int verses}) {
    final accent = Theme.of(context).colorScheme.primary;
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
        Text(
          "$verses ${l10n.verses}",
          style: TextStyle(
            fontSize: 14,
            color: accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _sessionTotals(int minutes, int verses) {
    final accent = Theme.of(context).colorScheme.primary;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: accent.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          Text(
            l10n.sessionTotal,
            style: TextStyle(letterSpacing: 1.5, fontSize: 11),
          ),
          const Spacer(),
          Text(
            "$minutes ${l10n.minutesShort}",
            style: TextStyle(
              fontSize: 15,
              color: accent,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 10),
          Text("•", style: TextStyle(color: accent)),
          const SizedBox(width: 10),
          Text(
            "$verses ${l10n.verses}",
            style: TextStyle(
              fontSize: 15,
              color: accent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _totals() {
    final accent = Theme.of(context).colorScheme.primary;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Text(
            l10n.total.toUpperCase(),
            style: TextStyle(letterSpacing: 2, fontSize: 12),
          ),
          const SizedBox(width: 16),
          Text(
            "${viewModel.totalMinutes} ${l10n.minutesShort}",
            style: TextStyle(
              fontSize: 18,
              color: accent,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 10),
          Text("•", style: TextStyle(color: accent)),
          const SizedBox(width: 10),
          Text(
            "${viewModel.totalVerses} ${l10n.verses}",
            style: TextStyle(
              fontSize: 18,
              color: accent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
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

  String _formatTimeRange(RsSession log) {
    final l10n = AppLocalizations.of(context)!;
    final start = _formatTime(log.startTime);
    final end = log.endTime != null
        ? _formatTime(log.endTime!)
        : l10n.inProgress;
    return "$start - $end";
  }

  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return "$hour:$minute $period";
  }
}
