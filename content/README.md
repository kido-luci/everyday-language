# Content packs

Vocabulary packs bundled into the app at build time. **The packs themselves
are not in this repository** — `.gitignore` keeps `content/*.json` out.

The code here is Apache-2.0; the word lists are not, and a fork should get a
working app with an empty dictionary rather than someone else's corpus. This
directory is committed (empty but for this file) only because `pubspec.yaml`
declares `content/` as an asset directory and Flutter fails the build when a
declared directory is missing.

## Building with a pack

Generate one, or drop an existing one in:

```bash
dart run tool/content/generate_pack.dart --count 60
```

That writes `content/everyday-v1.json`. See [`tool/content/README.md`](../tool/content/README.md)
for the schema, the flags, and what the generator asks the model for.

## Building without one

Supported and silent. `SeedPackLoader` treats a missing pack as "no pack" —
the app starts with an empty word list and the learner adds their own. Nothing
logs an error, because for a fork this is the normal case.
