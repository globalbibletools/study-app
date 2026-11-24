import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

class NumberStepper extends StatefulWidget {
  const NumberStepper({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.minValue = 1,
    this.maxValue,
    this.step = 1,
    this.allowDecimal = false,
    this.keyPrefix = 'number-stepper',
  });

  final num initialValue;
  final ValueChanged<num> onChanged;
  final num minValue;
  final num? maxValue;
  final num step;
  final bool allowDecimal;
  final String keyPrefix;

  @override
  State<NumberStepper> createState() => _NumberStepperState();
}

class _NumberStepperState extends State<NumberStepper> {
  late num _value;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _value = _clamp(widget.initialValue);
    _controller = TextEditingController(text: _format(_value));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  num _clamp(num value) {
    final max = widget.maxValue;
    if (max != null && value > max) return max;
    return value;
  }

  void _setValue(num value) {
    if (value < widget.minValue) return;
    final next = _clamp(value);
    if (next == _value) return;

    setState(() => _value = next);
    _syncController();
    widget.onChanged(next);
  }

  void _onTextChanged(String text) {
    final parsed = _parse(text);
    if (parsed == null || parsed < widget.minValue) return;

    final next = _clamp(parsed);
    if (next == _value) return;

    setState(() => _value = next);
    widget.onChanged(next);
  }

  num? _parse(String text) {
    final normalized = text.replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    if (widget.allowDecimal) return double.tryParse(normalized);
    return int.tryParse(normalized);
  }

  String _format(num value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  void _syncController() {
    final text = _format(_value);
    if (_controller.text == text) return;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  Widget _circleButton({
    required Key key,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final color = Theme.of(context).colorScheme.primary;
    return IconButton(
      key: key,
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      style: IconButton.styleFrom(
        fixedSize: const Size(34, 34),
        minimumSize: const Size(34, 34),
        padding: EdgeInsets.zero,
        foregroundColor: color,
        side: BorderSide(color: color),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        _circleButton(
          key: Key('${widget.keyPrefix}-decrease'),
          icon: Icons.remove,
          onTap: () => _setValue(_value - widget.step),
        ),
        _NumberStepperField(
          controller: _controller,
          allowDecimal: widget.allowDecimal,
          allowZero: widget.minValue <= 0,
          onChanged: _onTextChanged,
        ),
        _circleButton(
          key: Key('${widget.keyPrefix}-increase'),
          icon: Icons.add,
          onTap: () => _setValue(_value + widget.step),
        ),
      ],
    );
  }
}

class _NumberStepperField extends StatelessWidget {
  const _NumberStepperField({
    required this.controller,
    required this.allowDecimal,
    required this.allowZero,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool allowDecimal;
  final bool allowZero;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 52,
      height: 34,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final fontSize = switch (value.text.length) {
            <= 3 => 26.0,
            4 => 22.0,
            _ => 18.0,
          };
          return Center(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.numberWithOptions(
                decimal: allowDecimal,
              ),
              textAlign: TextAlign.center,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                _NumberInputFormatter(
                  allowDecimal: allowDecimal,
                  allowZero: allowZero,
                ),
              ],
              onChanged: onChanged,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w300,
                color: colorScheme.primary,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
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

class _NumberInputFormatter extends TextInputFormatter {
  const _NumberInputFormatter({
    required this.allowDecimal,
    required this.allowZero,
  });

  final bool allowDecimal;
  final bool allowZero;

  static final _decimalInput = RegExp(r'^\d*[.,]?\d*$');
  static final _positiveIntegerInput = RegExp(r'^[1-9][0-9]*$');
  static final _nonNegativeIntegerInput = RegExp(r'^[0-9]+$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final valid = allowDecimal
        ? _decimalInput.hasMatch(newValue.text)
        : (allowZero ? _nonNegativeIntegerInput : _positiveIntegerInput)
              .hasMatch(newValue.text);
    return valid ? newValue : oldValue;
  }
}
