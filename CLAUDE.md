# rss_reader

Flutter RSS/Atom reader. Everything runs on-device: feeds are fetched over HTTP,
parsed locally, and stored in SQLite. There is no backend and no account.

## Commands

Flutter is installed through mise (3.41.0), so it may not be on `PATH`:

```sh
mise exec flutter -- flutter analyze
mise exec flutter -- flutter test
mise exec flutter -- flutter test test/data/services/feed_parser_test.dart
mise exec flutter -- flutter run
```

Run `flutter analyze` and `flutter test` before finishing a change.

## Language

This is a public repository and English is the language for everything in it:
code, comments, doc comments, user-facing strings, test descriptions,
documentation, commit messages, and pull request titles and descriptions. The
app's UI is English too.

Pull requests are English here even when the conversation that produced them is
not, and even when a tool or workflow would otherwise write them in another
language.

There is no localization layer — strings are inline at their use site. A
`FeedException` message is shown to the user verbatim, so write those as finished
sentences.

One deliberate exception: `test/ui/html_content_test.dart` keeps a non-ASCII
`href` because percent-encoding is exactly what that test covers. Do not
"translate" test data that exists to exercise encoding.

## Comments

Do not write comments that explain what the code does. Code must be
self-explanatory — extract a named function or rename a variable instead of
narrating a block.

If the name already says it, write no comment. `class FeedListScreen`,
`markAllRead`, `EmptyView`, and `formatFullDate` need nothing above them; a doc
comment that only restates the identifier is noise and should be deleted.

Comment only what the code cannot say: why a non-obvious choice was made, which
external constraint forces it, what breaks without it. Contracts that the
signature cannot express — what null means for a parameter, what a returned
`String?` carries — are worth a line.

## Architecture

Layers under `lib/`, with dependencies pointing inward only:

- `ui/` — screens, widgets, and `Notifier` / `AsyncNotifier` view models. Depends
  on `domain/` and the repository. Never touches HTTP, XML, or SQL.
- `domain/models/` — `Feed`, `Article`, `ArticleFilter`. Immutable, no dependencies.
- `data/` — `repositories/` (`FeedRepository`) over `services/` (`FeedApiClient`,
  `FeedParser`, `FeedDatabase`) and `models/` (`ParsedFeed`, wire-level only).
- `utils/` — `Result`, date formatting.

State is Riverpod, declared by hand — there is no code generation, so no
`build_runner` step. `main.dart` only wraps the app in a `ProviderScope`;
`data/providers.dart` builds the object graph (`feedApiClientProvider`,
`feedDatabaseProvider`, `feedRepositoryProvider`).

`FeedRepository` is the single source of truth. It combines fetch, parse, and
persist and exposes domain models only, but holds no state and announces
nothing. View models talk to it and never to a service directly;
`ui/features/<feature>/{view_models,views}/` is the layout for each feature.

Since a write on one screen changes what another shows, every provider that
reads feeds or articles watches `feedRevisionProvider`, and every write goes
through `Ref.writeFeedData` so that counter is bumped afterwards. That helper
also takes its handles before awaiting: an auto-disposing provider can be gone
by the time its write finishes, and its `Ref` is unusable from then on.

A refresh the user asked for is tracked by its own `RefreshState` provider.
Reusing the `AsyncValue` for it would flash the spinner after every ordinary
write, since those reload the list too.

## Conventions

**Errors.** Fallible operations return `Result<T>` (`Ok` / `Failure`) instead of
throwing. Anything that reaches the user carries a `FeedException` whose message
is displayable as-is. Switch over `Result` with pattern matching; do not add a
default case.

**Feed parsing.** `FeedParser` handles RSS 2.0, RSS 1.0 (RDF), and Atom by
matching element *local names* and ignoring namespace prefixes — real-world feeds
declare namespaces inconsistently. Missing or unparseable dates fall back to the
fetch time rather than failing the item.

**Storage.** Articles are unique per `(feed_id, guid)`. Re-fetching updates
content but never overwrites `is_read` or `is_starred` — those are the user's
state. `PRAGMA foreign_keys` must be set per connection in `onConfigure` for
cascade delete to work. Timestamps are stored as epoch milliseconds.

**HTTP.** `FeedApiClient` sends an explicit `User-Agent` (some hosts reject
requests without one) and decodes bodies as UTF-8 unless a different charset is
declared, because `http` assumes Latin-1 and mangles non-ASCII feeds.

**Rendering.** Article HTML is rendered by the hand-rolled `HtmlContent` widget,
not a WebView. Unsupported tags degrade to their text content.

## Tests

`test/` mirrors `lib/`. Databases are real SQLite via `sqflite_common_ffi`:
call `sqfliteFfiInit()` and set `databaseFactory = databaseFactoryFfi` in
`setUpAll`, then construct `FeedDatabase(databaseName: inMemoryDatabasePath)` per
test. HTTP is stubbed with `MockClient` from `package:http/testing.dart`; no test
touches the network.

Reach the providers by overriding `feedRepositoryProvider` with a repository
built that way — `ProviderScope(overrides: ...)` for widget tests,
`ProviderContainer.test()` for view models on their own.
