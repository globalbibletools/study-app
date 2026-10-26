import 'package:flutter/material.dart';
import 'package:gbt/ui/home/home_manager.dart';
import 'package:gbt/ui/home/reading_plan/reading_plan_panel.dart';

class ReadingSheet extends StatelessWidget {
  const ReadingSheet({super.key, required this.homeManager});

  final HomeManager homeManager;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (innerContext) => ReadingPlanPanel(
          homeManager: homeManager,
          onClose: () =>
              Navigator.of(context).pop(), // outer context, captured here
        ),
      ),
    );
  }
}
