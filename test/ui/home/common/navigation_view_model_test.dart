import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/ui/home/common/navigation_view_model.dart';

import 'fake_user_settings.dart';

const _verse = Reference(bookId: 1, chapter: 2, verse: 4);

SyncPosition _positionFor(Reference ref) {
  final anchor = Anchor(ref, AnchorEnd.start);
  return SyncPosition(anchor, anchor, 0);
}

void main() {
  late FakeUserSettings settings;
  late NavigationViewModel viewModel;

  setUp(() {
    settings = FakeUserSettings();
    viewModel = NavigationViewModel(settings);
  });

  tearDown(() {
    viewModel.dispose();
  });

  group('init', () {
    test('restores the saved chapter at the chapter top', () async {
      settings = FakeUserSettings(bookId: 19, chapter: 23);
      viewModel = NavigationViewModel(settings);

      await viewModel.init();

      const ref = Reference(bookId: 19, chapter: 23, verse: 1);
      expect(viewModel.position, _positionFor(ref));
      expect(viewModel.displayReference, ref);
      expect(viewModel.currentReference, ref);
      expect(viewModel.anchor.value, ref);
      expect(settings.saveCalls, 0);
    });
  });

  group('navigateTo', () {
    test('writes position, display and anchor, and persists the chapter', () {
      viewModel.navigateTo(_verse);

      expect(viewModel.position, _positionFor(_verse));
      expect(viewModel.displayReference, _verse);
      expect(viewModel.currentReference, _verse);
      expect(
        viewModel.anchor.value,
        const Reference(bookId: 1, chapter: 2, verse: 1),
      );
      expect(settings.currentBookChapter, (1, 2));
      expect(settings.saveCalls, 1);
    });

    test('does not persist when persist is false', () {
      viewModel.navigateTo(_verse, persist: false);

      expect(viewModel.currentReference, _verse);
      expect(settings.currentBookChapter, (1, 1));
      expect(settings.saveCalls, 0);
    });

    test('keeps the anchor when the chapter does not change', () {
      viewModel.navigateTo(_verse);
      viewModel.navigateTo(const Reference(bookId: 1, chapter: 2, verse: 9));

      expect(
        viewModel.anchor.value,
        const Reference(bookId: 1, chapter: 2, verse: 1),
      );
    });

    test('clears the active source so manual navigation supersedes a drag', () {
      viewModel.setActiveSource('panel');

      viewModel.navigateTo(_verse);

      expect(viewModel.isSourceActive('panel'), isFalse);
      expect(viewModel.currentReference, _verse);
    });

    test('persists only when the chapter changes', () {
      viewModel.navigateTo(_verse);
      expect(settings.saveCalls, 1);

      viewModel.navigateTo(const Reference(bookId: 1, chapter: 2, verse: 9));
      expect(settings.saveCalls, 1);

      viewModel.navigateTo(const Reference(bookId: 1, chapter: 3, verse: 1));
      expect(settings.saveCalls, 2);
    });

    test('navigateTo after a preview still persists the chapter', () {
      viewModel.navigateTo(_verse, persist: false);
      expect(settings.saveCalls, 0);

      viewModel.navigateTo(_verse);
      expect(settings.currentBookChapter, (1, 2));
      expect(settings.saveCalls, 1);
    });

    test('emits a hard navigation by default', () {
      final events = <HardNavigation>[];
      final subscription = viewModel.hardNavigation.listen(events.add);
      addTearDown(subscription.cancel);

      viewModel.navigateTo(_verse);

      expect(events.single.reference, _verse);
    });

    test('does not emit hard navigation when hard is false', () {
      final events = <HardNavigation>[];
      final subscription = viewModel.hardNavigation.listen(events.add);
      addTearDown(subscription.cancel);

      viewModel.navigateTo(_verse, hard: false);

      expect(events, isEmpty);
    });
  });

  group('seekTo', () {
    test('writes a verse-interval position and display reference', () {
      viewModel.seekTo(_verse);

      expect(viewModel.position, _positionFor(_verse));
      expect(viewModel.displayReference, _verse);
      expect(viewModel.lastUpdateIsSeek, isTrue);
      expect(viewModel.lastUpdateAnimated, isFalse);
    });

    test('does not emit a hard navigation', () {
      final events = <HardNavigation>[];
      final subscription = viewModel.hardNavigation.listen(events.add);
      addTearDown(subscription.cancel);

      viewModel.seekTo(_verse);

      expect(events, isEmpty);
    });

    test('clears the active source so manual seeks supersede a drag', () {
      viewModel.setActiveSource('panel');

      viewModel.seekTo(_verse);

      expect(viewModel.isSourceActive('panel'), isFalse);
      expect(viewModel.position, _positionFor(_verse));
    });

    test('audio follows are ignored while a panel is the active source', () {
      final audioReference = ValueNotifier<Reference?>(null);
      addTearDown(audioReference.dispose);
      viewModel.bindAudioReference(audioReference);
      viewModel.setActiveSource('panel');

      audioReference.value = _verse;

      expect(viewModel.position, isNull);
      expect(viewModel.isSourceActive('panel'), isTrue);

      viewModel.clearActiveSource();
      const nextVerse = Reference(bookId: 1, chapter: 2, verse: 5);
      audioReference.value = nextVerse;

      expect(viewModel.position, _positionFor(nextVerse));
      expect(viewModel.lastUpdateAnimated, isTrue);
    });

    test('persists the target chapter', () {
      viewModel.seekTo(_verse);
      expect(settings.currentBookChapter, (1, 2));
    });

    test('leader reports clear the seek flags', () {
      viewModel.seekTo(_verse, animated: true);
      viewModel.setActiveSource('panel');

      viewModel.reportPosition('panel', _positionFor(_verse), display: _verse);

      expect(viewModel.lastUpdateIsSeek, isFalse);
      expect(viewModel.lastUpdateAnimated, isFalse);
    });
  });

  group('reportPosition', () {
    test('reports from a non-active source are ignored', () {
      viewModel.setActiveSource('leader');
      final position = _positionFor(_verse);

      viewModel.reportPosition('follower', position, display: _verse);
      expect(viewModel.position, isNull);

      viewModel.reportPosition('leader', position, display: _verse);
      expect(viewModel.position, position);
    });

    test('never changes the navigation anchor', () {
      viewModel.navigateTo(const Reference(bookId: 1, chapter: 1, verse: 1));
      final originalAnchor = viewModel.anchor.value;

      viewModel.setActiveSource('panel');
      viewModel.reportPosition(
        'panel',
        _positionFor(const Reference(bookId: 1, chapter: 2, verse: 4)),
        display: const Reference(bookId: 1, chapter: 2, verse: 4),
      );

      expect(viewModel.anchor.value, originalAnchor);
    });

    test('persists chapter changes from scrolling', () {
      viewModel.setActiveSource('panel');
      viewModel.reportPosition('panel', _positionFor(_verse), display: _verse);

      expect(settings.currentBookChapter, (1, 2));
      expect(settings.saveCalls, 1);
    });
  });

  test(
    'reanchorToCurrentReference moves the anchor to the display chapter',
    () {
      viewModel.navigateTo(const Reference(bookId: 1, chapter: 1, verse: 1));
      viewModel.setActiveSource('panel');
      viewModel.reportPosition(
        'panel',
        _positionFor(const Reference(bookId: 1, chapter: 2, verse: 4)),
        display: const Reference(bookId: 1, chapter: 2, verse: 4),
      );

      viewModel.reanchorToCurrentReference();

      expect(
        viewModel.anchor.value,
        const Reference(bookId: 1, chapter: 2, verse: 1),
      );
      expect(viewModel.isSourceActive('panel'), isTrue);
    },
  );

  test(
    'audio reference changes seek with animation unless a panel is active',
    () {
      final audio = ValueNotifier<Reference?>(null);
      viewModel.bindAudioReference(audio);
      addTearDown(audio.dispose);

      audio.value = _verse;
      expect(viewModel.displayReference, _verse);
      expect(viewModel.lastUpdateIsSeek, isTrue);
      expect(viewModel.lastUpdateAnimated, isTrue);

      viewModel.setActiveSource('panel');
      audio.value = const Reference(bookId: 1, chapter: 3, verse: 1);
      expect(viewModel.displayReference, _verse);
    },
  );
}
