import receive_sharing_intent

/// Receives text shared from other apps and hands it to Everyday Language.
///
/// All of the work is in `RSIShareViewController`: it writes the shared items
/// into the shared App Group container and opens the host app on the
/// `ShareMedia-<bundle id>` URL scheme. There is nothing to add here — the
/// extension shows no interface of its own, because a word is captured in one
/// tap and a form would only get in the way.
///
/// If this ever fails to build with "no such module 'receive_sharing_intent'",
/// the Runner target's `Embed Foundation Extensions` phase has drifted back
/// below `Thin Binary`; `tool/ios_share_extension.rb` puts it back.
class ShareViewController: RSIShareViewController {}
