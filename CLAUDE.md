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

`DESIGN.md` at the repo root is the design language both of them answer to: an
analysis of Apple's surfaces, expressed as colour, type, radius and elevation
tokens. Its rules are what the palette and the type ladder encode — one accent
and no second hue, body copy at 17 rather than 16, negative tracking from 14 up,
a weight ladder of 400 and 600 with 500 and 700 absent, radii of 8 / 18 / pill
and nothing between, and elevation carried by a hairline or a change of surface
rather than a shadow. Read it before changing a token; the values here are
chosen, not derived, and a seed colour will not reproduce them.

Two places bend a documented rule on purpose. `onPrimary` is near-black in dark
mode, where the doc says white — white on the dark-mode accent measures 2.7:1.
And `secondaryContainer` is a tint of the accent rather than a hue of its own,
because the doc forbids a second accent but a selected tab still needs a chip.

Three screen frames sit at 393x852 with the safe-area insets (59 top, 34 bottom)
drawn in, so a frame's height is what the device shows rather than what the
scroll view holds:

- `ScreenLatest` — `ArticleListScreen` with the filter bar and the tab bar
- `ScreenFeeds` — `FeedListScreen` with the circular FAB above the tab bar
- `ScreenArticleDetail` — the article header and the HtmlContent blocks below it

`ScreenLatestMacOS` is the desktop arrangement and sits at 1024x680. A window
has no safe area, but the hidden title bar leaves 28 points at the top that the
app bar and the sidebar both spend, and `trafficLights1` draws the window
buttons into that strip so nothing is placed under them.
`metadata.platform` on each frame records which build it stands for.

Each screen carries a `theme` key pinning it to light, and repeats one row down
as `…Dark`. Pinning is what puts both modes on the canvas at once — an unpinned
frame follows whatever mode the canvas is set to, so only one mode is ever
visible. The cost is that the pair are separate subtrees: editing `ScreenLatest`
does not reach `ScreenLatestDark`, and nothing checks that they still agree.
Edit both or delete the dark row.

The component frames are unpinned and follow the canvas.

Two properties are easy to leave out, because a `.pen` file stays valid JSON
without them and only looks wrong once it is open on the canvas:

- A text node wraps only when `textGrowth` is set. Every one here uses
  `"fixed-width"`, which fixes the width and lets the height grow; the default
  grows the width instead and runs the string out of its frame. The format has
  no `maxLines`, so where a widget caps its lines the count is recorded in
  `metadata` and spent on the node's `height`. That height is a starting point —
  the canvas is free to grow it, and the numbers written here are what Flutter
  renders, not what pen.dev will.
- An icon node needs a `library` from the documented set: `lucide`, `feather`,
  `phosphor`, or `Material Symbols` followed by `Outlined`, `Rounded` or
  `Sharp`. A bare `"Material Symbols"` renders as `?`, and so does any name
  carrying Flutter's variant suffix — `Icons.article_outlined` and
  `Icons.star_border` are `article` and `star` here. Material Symbols carries
  the variant on a FILL axis the icon node cannot reach, so a selected tab draws
  outlined on the canvas and filled in the app.

### Right edge

Content sits 16 from either side. The left comes for free — a title, a list
tile and an app bar's leading icon are all inset 16 by Material. On the right
two widgets arrive at a different number on their own and are corrected:

- An app bar's `actions` run flush to the edge, so a 48-wide icon button leaves
  its 24-point glyph 12 in, while the leading icon gets 56 points to sit in and
  lands at 16. `AppTheme` closes the 4 with `actionsPadding`.
- `_FeedTile` overrides `contentPadding` to 4 on the right. Its trailing
  `PopupMenuButton` carries 12 of its own, which the theme's 16 would stack on
  top of, putting the glyph 28 out.

The article tile's star is the one left alone, 18 rather than 16: its
`IconButton` insets a 20-point icon by 10, and the 2 is not worth a magic
number in the tile's padding.

macOS adds 8 on top, so those become 24 — a 16-point edge reads as cramped
against the 220-point sidebar. `rightGutter` in `theme.dart` is the amount and
`appBarActionsPadding` folds it into the app bar's 4; both take the platform
from the theme, like `HomeScreen` does, so a test can render either width. A
list spends it as `ListView` padding, which carries it to the tiles and to the
dividers' `endIndent` at once.

The gutter is spent edge by edge rather than as a single `Padding` around
`HomeScreen`'s body, which would be one line. An app bar tints when a list
scrolls under it — `#ffffff` to `#ebf3fb` in light, `#1d1d1f` to `#1e2731` in
dark — so pulling its background in along with its contents leaves an untinted
strip down the right of the window. The background stays full width; only what
sits on it moves.

### Glass

Navigation splits two ways, and `home_screen.dart` branches on
`Theme.of(context).platform` to match:

| | frame | widget |
| --- | --- | --- |
| iOS, Android | `ScreenLatest`, `ScreenFeeds` | `HomeNavigationBar` — a capsule floating over the list |
| macOS | `ScreenLatestMacOS` | `HomeSidebar` — 220 wide, fixed, full height |

Both are built on `GlassSurface`, which is a `ClipRRect` over a
`BackdropFilter`. The clip is not decoration: a `BackdropFilter` blurs
everything inside its nearest ancestor clip, so without one it would blur the
whole screen.

The phone bar floats, which is why `HomeScreen` sets `extendBody: true` — a
translucent panel with nothing passing behind it is a tinted rectangle, not
glass. `extendBody` also hands the bar's height down as `MediaQuery` bottom
padding, and the two list screens spend it explicitly rather than relying on
`ListView` to adopt it, since what they are clearing is a widget of ours and
not a system inset.

The sidebar has less to work with. macOS vibrancy samples the desktop behind
the window, which Flutter cannot reach without an `NSVisualEffectView`, so what
`HomeSidebar` blurs is the window background. It reads as translucent, not as
vibrancy, and no amount of tuning here will change that.

Neither is Liquid Glass. The refraction at the edges needs a fragment shader
through `ImageFilter.shader`; what is here is the frosting and a hairline that
stands in for the specular edge. Flutter ships none of this and is not taking
contributions for it, so nothing better arrives by upgrading.

Anything anchored to the bottom of a screen inside the tabs has to clear the
bar by hand. `Scaffold` lifts its floating action button and its snack bars over
its own `bottomNavigationBar`, and these screens have none — the bar belongs to
`HomeScreen`, one Scaffold further out. So `FeedListScreen` pads its FAB by
`MediaQuery.paddingOf(context).bottom`, and every snack bar goes through
`AppMessenger`, which floats it and gives it the same margin. A fixed snack bar
cannot take one, which is why they float.

`BackdropFilter` is expensive, and both of these sit over a scrolling list, so
they re-filter every frame. If a second glass surface ever appears, give them a
shared `BackdropKey` so the engine filters once.

`glass.tint` and `glass.rim` in the `.pen` are hand-owned. They need an alpha
channel and the generated `color.*` values are opaque, so they sit under their
own prefix — which is also what keeps `UPDATE_PEN_VARIABLES=1` from deleting
them. They were picked by eye against `color.surface` and will not follow a
change to the accent in `AppTheme`.

There is no `glass.shadow`: the panels carry a hairline and no drop shadow, so
`glassEdge` is the only thing separating one from the list behind it.

### Title bar

`MainFlutterWindow` hides the macOS title bar — `.fullSizeContentView`,
`titlebarAppearsTransparent`, `titleVisibility = .hidden` — so the window stops
painting a band of system colour above the app's own surface and the Flutter
view runs the full height of the window. Only the traffic lights are left, and
they float over the sidebar.

Nothing reports what that costs. The title bar view still sits above the content
and still swallows drags, so that strip of the window is neither empty nor
clickable. `TitleBarInset`, wrapped around `MaterialApp.builder`, adds it as
`MediaQuery` top padding, which is where the `SafeArea` in `HomeSidebar` and
every `AppBar` then take it from. It sits above the navigator so a pushed route
clears the strip too.

The height is not a constant, because it is not constant: full screen turns the
title bar into an auto-hiding overlay that covers nothing, and a window that
gained a toolbar would have a taller one. `MainFlutterWindow` measures it —
`contentView.bounds.height - contentLayoutRect.height`, zero when the style mask
says full screen — and answers `getHeight` on the `rss_reader/title_bar` channel,
then pushes `setHeight` from the full-screen notifications. Nothing else tells
Dart which state the window is in.

The channel is an `OptionalMethodChannel` and `TitleBarInset` carries no platform
check: only the macOS runner registers it, and a height nobody reports is no
inset.

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
