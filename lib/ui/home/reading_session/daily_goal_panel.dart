import 'package:flutter/material.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/services/reading_session/rs_manager.dart';

class SetDailyGoalView extends StatefulWidget {
  final GoalType initialGoalType;
  final int initialValue;

  const SetDailyGoalView({
    super.key,
    required this.initialGoalType,
    required this.initialValue,
  });

  @override
  State<SetDailyGoalView> createState() => _SetDailyGoalViewState();
}

class _SetDailyGoalViewState extends State<SetDailyGoalView> {
  late GoalType _goalType;
  late int _value;

  @override
  void initState() {
    super.initState();
    _goalType = widget.initialGoalType;
    _value = widget.initialValue;
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),

                Text(
                  l10n.dailyGoal.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 20,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 30),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.goalType.toUpperCase(),
                    style: const TextStyle(fontSize: 12, letterSpacing: 1.5),
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildToggleButton(
                        title: l10n.minutes,
                        selected: _goalType == GoalType.minutes,
                        onTap: () {
                          setState(() => _goalType = GoalType.minutes);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildToggleButton(
                        title: l10n.verses,
                        selected: _goalType == GoalType.verses,
                        onTap: () {
                          setState(() => _goalType = GoalType.verses);
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.target.toUpperCase(),
                    style: const TextStyle(fontSize: 12, letterSpacing: 1.5),
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _circleButton(
                      icon: Icons.remove,
                      onTap: () {
                        if (_value > 1) {
                          setState(() => _value--);
                        }
                      },
                    ),
                    const SizedBox(width: 30),
                    Text(
                      "$_value",
                      style: const TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(width: 30),
                    _circleButton(
                      icon: Icons.add,
                      onTap: () {
                        setState(() => _value++);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Text(
                  _goalType == GoalType.minutes
                      ? l10n.minutesPerDay.toUpperCase()
                      : l10n.versesPerDay.toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    letterSpacing: 2,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 30),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        child: Text(
                          l10n.cancel.toUpperCase(),
                          style: const TextStyle(
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, (_goalType, _value));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          l10n.save.toUpperCase(),
                          style: const TextStyle(
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: Text(title)),
      ),
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.primary),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
