/// Spaced-repetition scheduling for the review queue.
///
/// Wraps the FSRS algorithm (`package:fsrs`, from the team that owns it)
/// behind this project's own vocabulary, so callers speak in `ReviewGrade` and
/// `CardSchedule` and never see the library's types. Swapping the engine is a
/// change to `SrsScheduler` alone.
library;

export 'src/card_schedule.dart';
export 'src/srs_scheduler.dart';
