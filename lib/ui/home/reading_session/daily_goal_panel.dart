import 'package:flutter/material.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/services/reading_session/rs_manager.dart';
import 'package:studyapp/ui/home/keypad/numeric_keypad.dart';

class SetDailyGoalView extends StatefulWidget {
  final GoalType? initialGoalType;
  final int? initialValue;

  const SetDailyGoalView({
    super.key,
    required this.initialGoalType,
    required this.initialValue,
  });

  @override
  State<SetDailyGoalView> createState() => _SetDailyGoalViewState();
}

class _SetDailyGoalViewState extends State<SetDailyGoalView> {
  static const _allDigits = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9};
  static const _firstDigits = {1, 2, 3, 4, 5, 6, 7, 8, 9};

  late GoalType _goalType;
  late int _value;
  bool _isEditingValue = false;
  String _valueInput = '';

  @override
  void initState() {
    super.initState();
    _goalType = widget.initialGoalType ?? GoalType.minutes;
    _value = widget.initialValue ?? 10;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final container = Container(
      width: 340,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 5),

          Text(
            l10n.dailyGoal.toUpperCase(),
            style: const TextStyle(
              fontSize: 20,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          Align(
            alignment: Alignment.center,
            child: Text(
              l10n.goalType.toUpperCase(),
              style: const TextStyle(fontSize: 12, letterSpacing: 1.5),
            ),
          ),

          const SizedBox(height: 10),

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

          const SizedBox(height: 20),

          Align(
            alignment: Alignment.center,
            child: Text(
              l10n.target.toUpperCase(),
              style: const TextStyle(fontSize: 12, letterSpacing: 1.5),
            ),
          ),

          const SizedBox(height: 15),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _circleButton(
                icon: Icons.remove,
                onTap: () {
                  if (_value > 1) {
                    setState(() {
                      _isEditingValue = false;
                      _valueInput = '';
                      _value--;
                    });
                  }
                },
              ),
              const SizedBox(width: 30),
              _buildEditableValue(),
              const SizedBox(width: 30),
              _circleButton(
                icon: Icons.add,
                onTap: () {
                  setState(() {
                    _isEditingValue = false;
                    _valueInput = '';
                    _value++;
                  });
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

          const SizedBox(height: 20),

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
    );

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              container,
              if (_isEditingValue)
                Material(
                  elevation: 16,
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: NumericKeypad(
                    isLastInput: true,
                    enabledDigits: _valueInput.isEmpty
                        ? _firstDigits
                        : _allDigits,
                    onDigit: _handleDigit,
                    onBackspace: _handleBackspace,
                    onSubmit: _finishEditingValue,
                  ),
                ),
            ],
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

  Widget _buildEditableValue() {
    final colorScheme = Theme.of(context).colorScheme;
    final displayValue = _valueInput.isEmpty ? _value.toString() : _valueInput;

    return GestureDetector(
      onTap: _startEditingValue,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 110,
        height: 84,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: _isEditingValue
              ? Border.all(color: colorScheme.primary, width: 2)
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            displayValue,
            style: TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w300,
              color: _isEditingValue ? colorScheme.primary : null,
            ),
          ),
        ),
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

  void _startEditingValue() {
    if (_isEditingValue) return;

    setState(() {
      _isEditingValue = true;
      _valueInput = '';
    });
  }

  void _finishEditingValue() {
    setState(() {
      _isEditingValue = false;
      _valueInput = '';
    });
  }

  void _handleDigit(int digit) {
    if (_valueInput.isEmpty && digit == 0) return;

    final nextInput = _valueInput + digit.toString();
    final nextValue = int.tryParse(nextInput);
    if (nextValue == null || nextValue < 1) return;

    setState(() {
      _valueInput = nextInput;
      _value = nextValue;
    });
  }

  void _handleBackspace() {
    if (_valueInput.isEmpty) {
      _finishEditingValue();
      return;
    }

    final nextInput = _valueInput.substring(0, _valueInput.length - 1);
    final nextValue = int.tryParse(nextInput);

    setState(() {
      _valueInput = nextInput;
      if (nextValue != null && nextValue > 0) {
        _value = nextValue;
      }
    });
  }
}
