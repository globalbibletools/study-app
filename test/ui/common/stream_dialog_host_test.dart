import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/ui/common/stream_dialog_host.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('shows the latest event and hides when dismissed', (
    tester,
  ) async {
    final events = StreamController<int>.broadcast();
    addTearDown(events.close);

    await tester.pumpWidget(
      MaterialApp(
        home: StreamDialogHost<int>(
          stream: events.stream,
          builder: (context, event, dismiss) {
            return GestureDetector(onTap: dismiss, child: Text('event $event'));
          },
        ),
      ),
    );

    expect(find.text('event 1'), findsNothing);

    events.add(1);
    await tester.pump();
    await tester.pump();
    expect(find.text('event 1'), findsOneWidget);

    events.add(2);
    await tester.pump();
    await tester.pump();
    expect(find.text('event 1'), findsNothing);
    expect(find.text('event 2'), findsOneWidget);

    await tester.tap(find.text('event 2'));
    await tester.pump();
    expect(find.text('event 2'), findsNothing);

    events.add(3);
    await tester.pump();
    await tester.pump();
    expect(find.text('event 3'), findsOneWidget);
  });

  testWidgets('shows and dismisses a void event', (tester) async {
    final events = StreamController<void>.broadcast();
    addTearDown(events.close);

    await tester.pumpWidget(
      MaterialApp(
        home: StreamDialogHost<void>(
          stream: events.stream,
          builder: (context, _, dismiss) {
            return GestureDetector(
              onTap: dismiss,
              child: const Text('void event'),
            );
          },
        ),
      ),
    );

    events.add(null);
    await tester.pump();
    await tester.pump();
    expect(find.text('void event'), findsOneWidget);

    await tester.tap(find.text('void event'));
    await tester.pump();
    expect(find.text('void event'), findsNothing);
  });

  testWidgets('cancels its subscription when removed', (tester) async {
    final events = StreamController<int>.broadcast();
    addTearDown(events.close);

    await tester.pumpWidget(
      MaterialApp(
        home: StreamDialogHost<int>(
          stream: events.stream,
          builder: (context, event, dismiss) => Text('event $event'),
        ),
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    expect(events.hasListener, isFalse);

    await tester.pumpWidget(
      MaterialApp(
        home: StreamDialogHost<int>(
          stream: events.stream,
          builder: (context, event, dismiss) => Text('event $event'),
        ),
      ),
    );
    expect(events.hasListener, isTrue);
  });
}
