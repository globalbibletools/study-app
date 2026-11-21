import 'package:material_ui/material_ui.dart';
import 'package:gbt/reading_plan/reading_plan_panel.dart';

class ReadingSheet extends StatelessWidget {
  const ReadingSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute(
            builder: (innerContext) => ReadingPlanPanel(
              onClose: () =>
                  Navigator.of(context).pop(), // outer context, captured here
            ),
          ),
        ),
      ),
    );
  }
}
