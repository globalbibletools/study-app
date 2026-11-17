import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/ui/home/common/scroll_sync_controller.dart';

const _verse = Reference(bookId: 1, chapter: 2, verse: 4);

void main() {
  late ScrollSyncController controller;

  setUp(() {
    controller = ScrollSyncController();
  });

  tearDown(() {
    controller.dispose();
  });

  test('seekTo writes a verse-interval position and display reference', () {
    controller.seekTo(_verse);

    final anchor = Anchor(_verse, AnchorEnd.start);
    expect(controller.position, SyncPosition(anchor, anchor, 0));
    expect(controller.displayReference, _verse);
    expect(controller.lastUpdateIsSeek, isTrue);
    expect(controller.lastUpdateAnimated, isFalse);
  });

  test('seekTo is ignored while a panel is the active source', () {
    controller.setActiveSource('panel');

    controller.seekTo(_verse);
    expect(controller.position, isNull);

    controller.clearActiveSource();
    controller.seekTo(_verse);
    expect(controller.position, isNotNull);
  });

  test('leader reports clear the seek flags', () {
    controller.seekTo(_verse, animated: true);
    controller.setActiveSource('panel');

    final anchor = Anchor(_verse, AnchorEnd.start);
    controller.updatePosition(
      'panel',
      SyncPosition(anchor, anchor, 0.0),
      displayReference: _verse,
    );

    expect(controller.lastUpdateIsSeek, isFalse);
    expect(controller.lastUpdateAnimated, isFalse);
  });

  test('reports from a non-active source are ignored', () {
    controller.setActiveSource('leader');
    final anchor = Anchor(_verse, AnchorEnd.start);
    final position = SyncPosition(anchor, anchor, 0.0);

    controller.updatePosition(
      'follower',
      position,
      displayReference: _verse,
    );
    expect(controller.position, isNull);

    controller.updatePosition(
      'leader',
      position,
      displayReference: _verse,
    );
    expect(controller.position, position);
  });

  test('audio reference changes seek with animation unless a panel is active', () {
    final audio = ValueNotifier<Reference?>(null);
    controller.listenToAudioReference(audio);
    addTearDown(audio.dispose);

    audio.value = _verse;
    expect(controller.displayReference, _verse);
    expect(controller.lastUpdateIsSeek, isTrue);
    expect(controller.lastUpdateAnimated, isTrue);

    controller.setActiveSource('panel');
    audio.value = const Reference(bookId: 1, chapter: 3, verse: 1);
    expect(controller.displayReference, _verse);
  });
}
