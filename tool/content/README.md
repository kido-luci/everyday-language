# Content pack generator

Writes the vocabulary packs the app bundles. The packs are kept out of this
repository (see [`content/README.md`](../../content/README.md)); this script is
the machinery that produces them.

```bash
dart run tool/content/generate_pack.dart --count 60
```

Zero dependencies — plain `dart:io` against the Messages API, because
Anthropic publishes no official Dart SDK.

## Credentials

`ANTHROPIC_API_KEY` if it is exported, otherwise the token from `ant auth
login`. Nothing is read from a file in this repository and nothing is written
back, so a key never lands in the tree.

## Flags

| Flag | Default | Meaning |
| --- | --- | --- |
| `--count` | `60` | Entries the pack should end up with |
| `--batch` | `20` | Entries per API call |
| `--id` | `everyday-v1` | Pack id; also the filename and the deck key |
| `--name` | `Everyday starter` | Deck name |
| `--out` | `content/<id>.json` | Where to write |

The app loads `content/everyday-v1.json` — `SeedPackLoader.assetPath`. A pack
written under a different `--id` is not picked up without changing that
constant.

## Growing a pack

The run is **resumable and additive**. It reads whatever is already at the
output path, keeps every entry, and asks only for the shortfall — passing the
existing words to the model so they are not repeated. So the intended way to
scale up is to raise `--count` and re-run:

```bash
dart run tool/content/generate_pack.dart --count 60    # read these first
dart run tool/content/generate_pack.dart --count 300   # then top up
```

Changing `--id` between runs starts a new pack, and re-importing under a new
id gives the learner a second deck rather than replacing the first.

Batches are steered across a rotating list of everyday topics (work, travel,
food, health, money, …) so a large pack does not end up bunched in one corner
of the language.

## What comes back is checked

Entries are validated against the same rules `SeedEntry.fromJson` enforces —
one word, non-empty required fields, and a sentence that actually contains the
word — and anything failing is dropped with a note on stderr and re-requested.
Two consecutive rounds producing nothing usable stops the run rather than
looping.

The response is constrained by a JSON schema (structured outputs), so the
shape is guaranteed; the validation above is about the content being usable,
not the JSON being well-formed.

## Model settings

`claude-opus-5`, adaptive thinking, `effort: high`, streamed. Streaming is not
optional at this size: a batch with thinking on can outrun the default request
timeout, and the failure would look like a hang.

## Keeping the two schemas in step

`_responseSchema` here and `SeedEntry` in
`packages/features/vocabulary/lib/src/data/seed/seed_pack.dart` describe the
same thing. There is no shared definition — the script is plain Dart and the
parser lives in a Flutter package — so a field added to one has to be added to
the other by hand. The fixture test
(`packages/features/vocabulary/test/data/seed/seed_pack_test.dart`) is what
catches a parser that drifted; a generator that drifted shows up as entries
skipped at generation time.
