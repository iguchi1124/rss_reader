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

## Design

`design/rss_reader.pen` is a pen.dev canvas mirroring `lib/ui/`. It is a design
source, not a build input — nothing generates Dart from it, and `metadata.dart`
on a screen frame names the file it stands for. Keep the two in step or delete
the frame.

Three screen frames sit at 393x852 with the safe-area insets (59 top, 34 bottom)
drawn in, so a frame's height is what the device shows rather than what the
scroll view holds:

- `ScreenLatest` — `ArticleListScreen` with the filter bar and navigation bar
- `ScreenFeeds` — `FeedListScreen` with the extended FAB
- `ScreenArticleDetail` — the article header and the HtmlContent blocks below it

Each screen carries a `theme` key pinning it to light, and repeats one row down
as `…Dark`. Pinning is what puts both modes on the canvas at once — an unpinned
frame follows whatever mode the canvas is set to, so only one mode is ever
visible. The cost is that the pair are separate subtrees: editing `ScreenLatest`
does not reach `ScreenLatestDark`, and nothing checks that they still agree.
Edit both or delete the dark row.

The component frames are unpinned and follow the canvas.

Below them are the pieces on their own: `ArticleTile`, `FeedTile`, `FilterBar`,
`ReadSwipeBackground`, `EmptyView`, `ErrorView`, `AddFeedDialog`,
`ConfirmDialog`, `HtmlContentSpecimen`.

Every node carries an explicit width and height rather than sizing to its
content, because the canvas has no text engine to reflow with. Text heights are
`fontSize` times the Material 3 line height, or times the `height` the widget
overrides it with. Editing a string does not resize its box; the number has to
follow.

Sizes that Flutter owns rather than this app — app bar 64, navigation bar 80,
`ListTile` 72, dialog corner radius 28 — are transcribed from the Material 3
specs Flutter implements. They are close, not authoritative: measure a
screenshot before trusting one to the pixel.

Only `color.*` and `text.*` variables are generated from `AppTheme`; anything
else added on the canvas survives. `test/ui/core/theme_pen_sync_test.dart` fails
when the generated ones drift. Regenerate after touching the theme:

```sh
UPDATE_PEN_VARIABLES=1 mise exec flutter -- flutter test test/ui/core/theme_pen_sync_test.dart
```

A colour change means changing `AppTheme._seedColor`, not the `.pen` file.

Translating a node to a widget:

| `.pen` | Dart |
| --- | --- |
| `"fill": "$color.<role>"` | `Theme.of(context).colorScheme.<role>` |
| `"fontSize": "$text.<style>.size"` | `Theme.of(context).textTheme.<style>` |
| `frame` with `layout: "vertical"` | `Column` |
| `frame` with `layout: "horizontal"` | `Row` |
| `alignItems` / `justifyContent` | `crossAxisAlignment` / `mainAxisAlignment` |
| `padding: [top, right, bottom, left]` | `EdgeInsets.fromLTRB(left, top, right, bottom)` |
| `gap` | `spacing` on the `Row` or `Column` |
| childless `frame` between siblings | `SizedBox` of that height |
| `width: "fill_container"` | `Expanded` |
| `width: "fit_content"` | intrinsic size, no wrapper |
| `cornerRadius` with `fill` | `BoxDecoration` on a `Container` |
| `ellipse` | `BoxDecoration(shape: BoxShape.circle)` |

A `fill` or `fontSize` holding a literal rather than a `$` reference is
unfinished design, not a spec. Never carry one into Dart: the reference is what
survives a theme change, and a hard-coded hex is invisible in light mode review
and wrong in dark mode.

pen.dev's MCP server is local to the machine running it, so the agent that reads
a `.pen` file is the one running beside pen.dev.

### App icon

`design/app_icon.pen` holds three frames, each exporting to the PNG named in its
`metadata.export`:

| frame | export | used for |
| --- | --- | --- |
| `AppIcon` | `design/app_icon.png` | iOS, Android legacy `mipmap` |
| `AppIconMacOS` | `design/app_icon_macos.png` | macOS — rounded and inset, since macOS does not mask |
| `AppIconForeground` | `design/app_icon_foreground.png` | Android adaptive foreground, transparent |

The foreground frame draws the glyph smaller than the others on purpose: an
adaptive icon only guarantees the middle 72 of its 108 units are visible, so
artwork sized like `AppIcon` would lose its edges under a circular mask.

Re-export the three PNGs from pen.dev, then regenerate every platform asset:

```sh
mise exec flutter -- flutter pub get
mise exec flutter -- dart run flutter_launcher_icons
```

`flutter_launcher_icons.yaml` holds the configuration. `#1A120E` appears there
and in `android/app/src/main/res/values/colors.xml` because the Android adaptive
background is a platform resource, not a Flutter theme value — it cannot read
`AppTheme`. Change it in both, or the launcher background and the icon artwork
drift apart.

The icon's colours are fixed, not theme-derived: `$icon.background`,
`$icon.foreground`, and `$icon.accent` in the `.pen` file carry no `theme` key.
A launcher icon does not follow the system light/dark setting, so the rule about
`$color.*` references tracking `AppTheme` does not apply here.

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
