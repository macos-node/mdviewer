# mdviewer

A tiny native macOS Markdown reader: SwiftUI document app + `WKWebView`, rendered with
[cmark-gfm](https://github.com/swiftlang/swift-cmark) (GitHub-flavored Markdown).

## Features

- Open `.md` / `.markdown` files via File → Open, drag-and-drop, or Finder's *Open With*
- GFM: tables, task lists, ~~strikethrough~~, autolinks, footnotes[^1]
- Auto-refreshes when the file changes on disk; ⌘R / toolbar button to reload manually
- Syntax highlighting (highlight.js, GitHub themes) and a Copy button on code blocks
- Check for Updates… against GitHub Releases (the only network access, on demand)
- Light & dark mode, pinch/⌘-zoom, print (⌘P)
- Relative images and links next to the document work
- Heading anchors: [jump to Building](#building)

### Task list

- [x] Read Markdown
- [ ] Edit & save (future)

### Table

| Feature  | Status |
|:---------|:------:|
| Viewing  | ✅     |
| Editing  | later  |

```swift
let html = MarkdownRenderer.html(from: "# Hello <world>")
```

## Download

Grab `mdviewer.zip` from the [latest release](https://github.com/macos-node/mdviewer/releases/latest),
unzip, and move `mdviewer.app` to `/Applications`.

The app is ad-hoc signed (not notarized), so macOS blocks the first launch. Either right-click
the app → **Open**, or run:

```sh
xattr -dr com.apple.quarantine /Applications/mdviewer.app
```

## Building

Requires Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
xcodegen generate
xcodebuild -project mdviewer.xcodeproj -scheme mdviewer -configuration Release -derivedDataPath build
open build/Build/Products/Release/mdviewer.app
```

Install: `ditto build/Build/Products/Release/mdviewer.app /Applications/mdviewer.app`

The app icon is drawn by `Tools/make-icon.swift` (`swift Tools/make-icon.swift icon-1024.png`),
then resized into `Resources/Assets.xcassets/AppIcon.appiconset`.

## Security notes

Documents never touch the network:

- **WebKit content-blocking rules** — every load except local content (`mdviewer-file:`,
  `data:`, `about:`) is blocked inside the viewer. If the rules can't be installed, the
  document isn't shown.
- **Content Security Policy** — a second, independent block: only local images may load; remote
  images, fonts, frames, forms and `<base>` are refused. DNS prefetching is off.
- **No document JavaScript** — scripts in the Markdown never run. Syntax highlighting and copy
  buttons run as the app's own scripts in an isolated world.
- **No automatic navigation** — redirects such as `<meta http-equiv="refresh">` are refused.
  Links you click open in your default browser.
- **App Sandbox** with read-only file access.

The one exception is **mdviewer → Check for Updates…**, which the app (not a document) runs only
when you choose it. It calls `api.github.com/repos/<MDVUpdateRepository>/releases/latest`
(set in `project.yml`, currently `macos-node/mdviewer`) and offers to open the release page on
github.com. Nothing is downloaded or installed automatically.

highlight.js (BSD-3-Clause) is bundled in `Resources/`. The app is ad-hoc signed.

[^1]: Like this one.
