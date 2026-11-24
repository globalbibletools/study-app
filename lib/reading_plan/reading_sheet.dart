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
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            top: false,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    _handle(context),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Navigator(
                        onGenerateRoute: (_) => MaterialPageRoute(
                          builder: (_) => PopScope(
                            canPop: false,
                            onPopInvokedWithResult: (didPop, result) {
                              Navigator.of(context).pop();
                            },
                            child: const ReadingPlanPanel(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _handle(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}
