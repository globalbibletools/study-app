import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/l10n/book_names.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:gbt/ui/home/home_manager.dart';
import 'package:gbt/ui/home/reading_plan/add_reading_plan_panel.dart';
import 'package:gbt/ui/home/reading_plan/reading_plan_detail_panel.dart';
import 'package:gbt/ui/home/reading_plan/reading_plan_panel_manager.dart';

class ReadingPlanPanel extends StatefulWidget {
  final HomeManager homeManager;
  final Function onClose;

  const ReadingPlanPanel({
    super.key,
    required this.homeManager,
    required this.onClose,
  });

  @override
  State<ReadingPlanPanel> createState() => ReadingPlanPanelState();
}

class ReadingPlanPanelState extends State<ReadingPlanPanel> {
  late final ReadingPlanPanelManager manager;

  bool _editMode = false;

  @override
  void initState() {
    super.initState();
    manager = ReadingPlanPanelManager();
  }

  /// Re-reads the font scale from persisted settings into the notifier.
  void refreshFromSettings() {}

  @override
  void didUpdateWidget(covariant ReadingPlanPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return SafeArea(
      top: false,
      child: Container(
        height: screenHeight * 0.85,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _handle(),
            const SizedBox(height: 16),
            _topTitle(),
            const SizedBox(height: 12),
            Flexible(child: _content()),
          ],
        ),
      ),
    );
  }

  Widget _handle() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _topTitle() {
    final l10n = AppLocalizations.of(context)!;
    // Centered, larger serif-style title per mockup.
    return Center(
      child: Text(
        l10n.readingPlans,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _content() {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder(
      valueListenable: manager.readingPlansNotifier,
      builder: (context, value, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
              child: Row(
                children: [
                  Text(
                    l10n.yourReadingPlans,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(40, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      setState(() {
                        _editMode = !_editMode;
                      });
                    },
                    child: Text(
                      l10n.edit,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Stack(
                children: [
                  // Scrollable list, padded at the bottom so the last
                  // card isn't hidden behind the floating button.
                  ListView(
                    padding: const EdgeInsets.only(bottom: 76),
                    children: value.map((plan) {
                      return _readingPlan(plan);
                    }).toList(),
                  ),
                  // Floating "Create New Plan" button.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _createNewPlanButton(),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _createNewPlanButton() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => AddReadingPlanPanel()));

            manager.init();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.createNewPlan,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _readingPlan(ReadingPlanDetails planDet) {
    final l10n = AppLocalizations.of(context)!;

    final plan = planDet.readingPlan;

    final action = planDet.versesRead == 0 ? l10n.start : l10n.resume;

    int versesCount = planDet.totalVerses;

    if (versesCount == 0) {
      versesCount = 1;
    }

    return _readingPlanGeneric(
      planDet,
      plan.planName,
      planDet.versesRead / versesCount,
      "${planDet.versesRead}/$versesCount",
      " ${l10n.verses}",
      action,
    );
  }

  Widget _readingPlanGeneric(
    ReadingPlanDetails planDet,
    String title,
    double progress,
    String progressLabel,
    String progressSuffix,
    String action,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            if (_editMode) {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AddReadingPlanPanel(planDetails: planDet),
                ),
              );
              _editMode = false;
            } else {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReadingPlanDetailPanel(
                    readingPlanDetails: planDet,
                    homeManager: widget.homeManager,
                    onClose: widget.onClose,
                  ),
                ),
              );
            }

            manager.init();
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      "${(progress * 100).toInt()}%",
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: colorScheme.surfaceContainerLowest,
                    valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      "$progressLabel$progressSuffix",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodyMedium,
                        children: [
                          if (planDet.latestBookProgress != null) ...[
                            TextSpan(
                              text:
                                  "${AppLocalizations.of(context)!.current}: ",
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text: bookNameFromId(
                                context,
                                planDet.latestBookProgress!.bookId,
                              ), // Placeholder, replace as needed
                              style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (!_editMode)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          log("starting reading session");

                          await manager.startReadingSession(planDet);

                          if (!mounted) return;

                          int bookId, chapter, verse;

                          if (planDet.latestBookProgress != null) {
                            bookId = planDet.latestBookProgress!.bookId;
                            chapter = planDet.latestBookProgress!.chapter;
                            verse = planDet.latestBookProgress!.verse;
                          } else {
                            bookId = planDet.books[0].bookId;
                            chapter = 1;
                            verse = 1;
                          }

                          widget.homeManager.onBookSelected(context, bookId);

                          widget.homeManager.onChapterSelected(chapter);

                          widget.homeManager.syncController.jumpToVerse(
                            bookId,
                            chapter,
                            verse,
                          );

                          widget.onClose();
                        },
                        child: Row(
                          children: [
                            Text(
                              action,
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.chevron_right,
                              color: colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
