import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

class GoalValueEditor extends StatefulWidget {
  const GoalValueEditor({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  final int initialValue;
  final ValueChanged<int> onChanged;

  @override
  State<GoalValueEditor> createState() => _GoalValueEditorState();
}

class _GoalValueEditorState extends State<GoalValueEditor> {
  late int _value;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
    _controller = TextEditingController(text: _value.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setValue(int value) {
    if (value < 1 || value == _value) return;
    setState(() => _value = value);
    _syncController();
    widget.onChanged(value);
  }

  void _syncController() {
    final text = _value.toString();
    if (_controller.text == text) return;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
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

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _circleButton(
          icon: Icons.remove,
          onTap: () {
            if (_value <= 1) return;
            _setValue(_value - 1);
          },
        ),
        const SizedBox(width: 30),
        _GoalValueField(controller: _controller, onChanged: _setValue),
        const SizedBox(width: 30),
        _circleButton(icon: Icons.add, onTap: () => _setValue(_value + 1)),
      ],
    );
  }
}

class _GoalValueField extends StatelessWidget {
  const _GoalValueField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 110,
      height: 84,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final fontSize = switch (value.text.length) {
            <= 3 => 64.0,
            4 => 50.0,
            5 => 40.0,
            _ => 32.0,
          };
          return Center(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              textInputAction: TextInputAction.done,
              inputFormatters: const [_GoalValueInputFormatter()],
              onChanged: (text) {
                final parsed = int.tryParse(text);
                if (parsed != null) onChanged(parsed);
              },
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w300,
                color: colorScheme.primary,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GoalValueInputFormatter extends TextInputFormatter {
  const _GoalValueInputFormatter();

  static final _validInput = RegExp(r'^[1-9][0-9]*$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    return _validInput.hasMatch(newValue.text) ? newValue : oldValue;
  }
}
