import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Text handed to this app from another one — the share sheet, or Android's
/// text-selection menu.
///
/// The counterpart of `ShareService`, which sends text out. This one only
/// deals in text: a shared image or video is not a word, and is dropped here
/// rather than travelling up to a caller that would have to ignore it.
///
/// Two arrival routes, and both matter. A share that launches the app cold is
/// waiting in [initialText] before the first frame; a share that arrives while
/// the app is already open comes through [textStream]. Handling only one of
/// them works perfectly in testing and fails for half of real use.
@lazySingleton
class SharedTextService {
  SharedTextService();

  /// The share the app was launched with, or null.
  ///
  /// Call [markHandled] once it has been acted on: the platform keeps holding
  /// it otherwise, and the next cold start would open the same word again.
  Future<String?> initialText() async =>
      _textOf(await ReceiveSharingIntent.instance.getInitialMedia());

  /// Shares arriving while the app is running.
  Stream<String> textStream() => ReceiveSharingIntent.instance
      .getMediaStream()
      .map(_textOf)
      .where((text) => text != null)
      .cast<String>();

  /// Tells the platform the pending share has been dealt with.
  Future<void> markHandled() => ReceiveSharingIntent.instance.reset();

  /// Joins the text parts of a share, or null when it carried none.
  ///
  /// A selection shared from a browser often arrives as several parts — the
  /// text and the page URL as separate entries. Only the text is kept; what
  /// remains of a URL is stripped again downstream, where the parsing rules
  /// live.
  static String? _textOf(List<SharedMediaFile> media) {
    final parts = [
      for (final item in media)
        if (item.type == SharedMediaType.text) item.path,
    ];
    if (parts.isEmpty) return null;

    final joined = parts.join(' ').trim();
    return joined.isEmpty ? null : joined;
  }
}
