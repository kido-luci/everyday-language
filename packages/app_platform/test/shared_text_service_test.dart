// The plugin ships a mock hook, so the extraction rules can be exercised
// without a platform channel. What is worth pinning is what gets dropped: a
// share that carries no text at all must not surface as an empty capture,
// because the app would open the add-word form over whatever the learner was
// doing and offer them nothing to save.

import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

void main() {
  late StreamController<List<SharedMediaFile>> stream;

  SharedMediaFile file(String path, SharedMediaType type) =>
      SharedMediaFile(path: path, type: type);

  void mock({List<SharedMediaFile> initial = const []}) {
    ReceiveSharingIntent.setMockValues(
      initialMedia: initial,
      mediaStream: stream.stream,
    );
  }

  setUp(() => stream = StreamController<List<SharedMediaFile>>.broadcast());
  tearDown(() => stream.close());

  group('the share that launched the app', () {
    test('is the text it carried', () async {
      mock(initial: [file('decision', SharedMediaType.text)]);

      expect(await SharedTextService().initialText(), 'decision');
    });

    test('is null when there was no share', () async {
      mock();

      expect(await SharedTextService().initialText(), isNull);
    });

    test('is null when the share carried no text', () async {
      // An image share is a share, but not one this app can do anything with.
      mock(initial: [file('/tmp/photo.jpg', SharedMediaType.image)]);

      expect(await SharedTextService().initialText(), isNull);
    });

    test('joins the parts a browser sends separately', () async {
      mock(
        initial: [
          file('It was a hard decision.', SharedMediaType.text),
          file('https://example.com', SharedMediaType.url),
          file('Read more', SharedMediaType.text),
        ],
      );

      expect(
        await SharedTextService().initialText(),
        'It was a hard decision. Read more',
        reason: 'the URL is not text and is dropped here',
      );
    });
  });

  group('shares while the app is open', () {
    test('arrive on the stream', () async {
      mock();
      final service = SharedTextService();

      final received = service.textStream().first;
      stream.add([file('deadline', SharedMediaType.text)]);

      expect(await received, 'deadline');
    });

    test('a textless share is not delivered at all', () async {
      mock();
      final service = SharedTextService();

      final received = <String>[];
      final subscription = service.textStream().listen(received.add);

      stream
        ..add([file('/tmp/photo.jpg', SharedMediaType.image)])
        ..add([file('agenda', SharedMediaType.text)]);
      await Future<void>.delayed(Duration.zero);

      expect(received, ['agenda']);
      await subscription.cancel();
    });
  });
}
