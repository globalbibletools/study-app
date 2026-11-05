# Keypad

## Overview
Provides an on-screen numerical keypad layer that slides into the home screen when entering Scripture chapter and verse numbers, supporting selective digit enabling and focus exclusion.

## Interface
- `keypad_layer.dart:KeypadLayer`: Animated layer sliding the numeric keypad in and out based on `HomeManager.inputModeNotifier`.
- `numeric_keypad.dart:NumericKeypad`: Virtual keypad widget rendering digit keys 0–9, backspace, and forward/submit buttons with dynamic disable states.

## Invariants
- `NumericKeypad` sets `ExcludeFocus(excluding: true)` so tapping keypad buttons does not unfocus the text field in the app bar.
- Individual digit keys are disabled and visually subdued when omitted from the `enabledDigits` set.
- `KeypadLayer` slides out of view when `ReferenceInputMode` is not `chapter` or `verse`.

## Side Effects
- Dispatches digit, backspace, and submit input events to `HomeManager`.
- Runs slide transition animations between keypad states.

## Verification
- Run: `flutter test`
