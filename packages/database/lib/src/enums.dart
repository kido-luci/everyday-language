/// Enums stored in the database.
///
/// Persisted by **name**, not index (`textEnum`, not `intEnum`). An index
/// column silently reinterprets every existing row the day someone reorders
/// the enum or inserts a value in the middle — a corruption with no error and
/// no obvious symptom. Names cost a few bytes and cannot do that.
///
/// Renaming a value is therefore a schema migration, not a refactor.
library;

/// What a word still needs before it can be studied.
///
/// A captured word starts [pending]: the learner has the word and the sentence
/// they met it in, but not yet a definition, phonetics or a collocation. Those
/// arrive when the device is next online.
enum EnrichmentStatus { pending, ready, failed }

/// Where an example sentence came from.
///
/// [userCapture] is the valuable one — the sentence the learner actually met
/// the word in. Drills prefer it over anything generated.
enum ExampleOrigin { userCapture, llm, seed }

/// How a word was captured.
enum CaptureKind { manual, url, app, ocr }

/// What a card asks of the learner.
///
/// Three cards per word, scheduled independently, because recognising a word
/// and being able to produce it are different memories that decay at different
/// rates.
enum CardKind {
  /// See the word, recall its meaning.
  recognise,

  /// See the meaning, type the word.
  recall,

  /// Fill the word into the sentence it was met in.
  cloze,
}
