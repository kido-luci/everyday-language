import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';

import 'wiktionary_gloss.dart';

/// What a lookup came back with.
///
/// The three cases are not interchangeable, and the caller has to tell them
/// apart: a found gloss is stored, a word the dictionary does not have is
/// settled for good, and a failed request is worth trying again later.
sealed class LookupResult {
  const LookupResult();
}

class LookupFound extends LookupResult {
  const LookupFound(this.gloss);

  final WordGloss gloss;
}

/// The dictionary answered, and has nothing for this word.
class LookupAbsent extends LookupResult {
  const LookupAbsent();
}

/// The dictionary could not be reached, or did not make sense.
class LookupFailed extends LookupResult {
  const LookupFailed();
}

/// Credits the dictionary in the app's license page.
///
/// Not optional: the glosses this app stores and shows are Wiktionary's, under
/// Creative Commons Attribution-ShareAlike 4.0 (the wiki's own
/// `meta=siteinfo&siprop=rightsinfo` says so), and attribution is a condition
/// of that licence. `LicenseRegistry` puts it on the same page as the package
/// licences, which is where a reader already goes looking.
///
/// Called once from the app bootstrap.
void registerWiktionaryAttribution() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      ['Vietnamese Wiktionary'],
      'Word meanings and pronunciations in this app are taken from the '
      'Vietnamese Wiktionary (vi.wiktionary.org), which draws its '
      'English–Vietnamese entries from the free Vietnamese dictionary '
      'project edited by Hồ Ngọc Đức.\n\n'
      'Used under the Creative Commons Attribution-ShareAlike 4.0 '
      'International licence: '
      'https://creativecommons.org/licenses/by-sa/4.0/',
    );
  });
}

/// Reads Vietnamese glosses for English words off vi.wiktionary.org.
///
/// The endpoint is the MediaWiki action API rather than the tidier REST one:
/// `/api/rest_v1/page/definition` answers 501 on this wiki, so
/// `prop=extracts` is what there is.
///
/// Content is Wiktionary's, CC BY-SA, sourced from the free Vietnamese
/// dictionary project — attribution belongs wherever the app credits its
/// sources.
@lazySingleton
class WiktionaryClient {
  WiktionaryClient() : _client = http.Client();

  @visibleForTesting
  WiktionaryClient.withClient(this._client);

  final http.Client _client;

  /// Wikimedia asks callers to identify themselves, and throttles the ones
  /// that will not.
  static const _userAgent =
      'EverydayLanguage/0.1 (https://github.com/kido-luci/everyday-language)';

  static const _timeout = Duration(seconds: 8);

  Future<LookupResult> lookUp(String word) async {
    final uri = Uri.https('vi.wiktionary.org', '/w/api.php', {
      'action': 'query',
      'prop': 'extracts',
      'explaintext': '1',
      'format': 'json',
      'titles': word,
    });

    try {
      final response = await _client
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(_timeout);
      if (response.statusCode != 200) return const LookupFailed();

      // `bodyBytes` decoded explicitly: the glosses are Vietnamese, and
      // `response.body` guesses latin-1 when the charset is unstated.
      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final pages =
          (decoded['query'] as Map<String, dynamic>?)?['pages']
              as Map<String, dynamic>?;
      if (pages == null || pages.isEmpty) return const LookupFailed();

      final page = pages.values.first as Map<String, dynamic>;
      // A word with no page comes back as `"missing": ""`, with no extract.
      final extract = page['extract'] as String?;
      if (extract == null) return const LookupAbsent();

      final gloss = parseVietnameseGloss(extract);
      // A page that exists but carries no English sense is just as settled as
      // no page at all — retrying will not change it.
      return gloss == null ? const LookupAbsent() : LookupFound(gloss);
    } on Object {
      // Offline, timed out, or a shape this parser does not know. All of them
      // are worth another attempt on another day.
      return const LookupFailed();
    }
  }
}
