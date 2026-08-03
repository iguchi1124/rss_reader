# RSS Reader

An RSS reader built with Flutter. Subscribe to RSS 2.0, RSS 1.0 (RDF), and Atom
feeds; articles are stored on the device so they can be read offline.

## Features

- **Subscription management** — add a feed by URL. Give it a site URL instead and
  the feed is discovered from the page's `<link rel="alternate">`
- **Fetching** — refresh one feed or all of them. Already-imported articles are
  matched by `guid`, so only the content is replaced while read and starred state
  is preserved
- **Feed icons** — the publisher's own image, or failing that the site's favicon,
  stands in for a feed in the list. Feeds that offer neither keep their initial
- **Read state** — tap to read, swipe to toggle read/unread, mark a whole feed as
  read at once
- **Stars** — mark articles to read later and filter the list down to them
- **Article bodies** — the published HTML is rendered on-device, covering
  headings, lists, quotes, code, images, and links. Feeds that publish no body
  open in the browser instead
- **Offline reading** — anything already fetched reads without a connection

## Running

```sh
flutter pub get
flutter run
```

Supported platforms are iOS, Android, and macOS.

## Development

```sh
flutter analyze   # static analysis
flutter test      # tests
```

## Structure

Two layers — UI and data — following the
[Flutter architecture guide](https://docs.flutter.dev/app-architecture). The UI
layer uses MVVM; the data layer uses the repository pattern.

```
lib/
├── data/
│   ├── models/          # parser output (ParsedFeed)
│   ├── repositories/    # FeedRepository — the single source of truth
│   └── services/        # HTTP, XML parsing, SQLite
├── domain/
│   └── models/          # Feed, Article
├── ui/
│   ├── core/            # theme, shared widgets, HTML rendering
│   └── features/
│       ├── home/        # tab scaffold
│       ├── feeds/       # subscribed feed list
│       ├── articles/    # article list
│       └── article_detail/
└── utils/               # Result type, date formatting
```

Dependencies point one way, UI → data. View models see only the repository; they
never touch HTTP or SQLite directly.

### Data flow

```
FeedApiClient  ─┐
                ├─ FeedRepository ── ViewModel ── View
FeedParser     ─┤   (ChangeNotifier)
FeedDatabase   ─┘
```

`FeedRepository` is a `ChangeNotifier`, so marking an article read or adding and
removing feeds reaches every view model. That is why the unread badge on the feed
list follows what happens in the article list.

### Design decisions

- **provider for state management** — the smallest thing that lets ChangeNotifier
  -based MVVM be written plainly, with no code generation
- **rendering article bodies in-house** — feed bodies use a narrow set of tags, so
  rather than pulling in a WebView or a large HTML rendering package,
  `lib/ui/core/widgets/html_content.dart` handles just that range. Unsupported
  tags degrade to their text content, so nothing renders broken
- **SQLite for storage** — list filtering and unread counts stay in SQL as the
  number of articles grows
- **`Result` instead of exceptions** — fetching and parsing fail routinely, so
  callers are forced to handle it
- **a package for the glass** — the tab bar, the sidebar and the header refract
  what passes behind them, which needs a fragment shader that Flutter does not
  ship. `liquid_glass_widgets` supplies one, and
  `lib/ui/core/widgets/glass_surface.dart` is the only file that imports it, so
  the rest of the UI asks for a glass panel without knowing where one comes from

### On feed compatibility

Feeds in the wild frequently deviate from the specs. The following is tolerated
deliberately.

- Namespace prefixes are ignored; elements are matched on their local name
- Dates accept both ISO 8601 and RFC 822, and allow the weekday, seconds, and
  time zone to be omitted. Anything unparseable falls back to the fetch time
- Responses with no `charset` declaration are read as UTF-8 (the http package
  defaults to Latin-1, which mangles non-ASCII text)
- A missing `guid` falls back to the link, and then to the title
