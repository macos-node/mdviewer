# Backlog

Ideas for future polish. Keep everything offline: documents must never touch the network.

## 1. Remember the last opened file

Reopen the most recent `.md` file at launch.

- macOS already restores windows that were open at quit, unless **System Settings → Desktop & Dock
  → "Close windows when quitting an application"** is on. Decide whether to rely on that or to
  always reopen the last file.
- Store the last file's path (or, better, a bookmark) in `UserDefaults` and open it via
  `NSDocumentController` when no windows were restored. If the file has moved, skip it silently.
- If editing is added later, use a security-scoped bookmark so write access survives relaunches
  in the sandbox.

## 2. Show the file path of the open document

- Show the path as a window subtitle (`.navigationSubtitle`) or a small bar at the bottom, with `~`
  for the home folder.
- Click to reveal in Finder, or right-click to copy the path.
- Already available for free: ⌘-click the title in the window's title bar to see the folder path.

## 3. Open / close / save dialogs for light editing

Part of adding basic editing (see the note in `Sources/MDViewerApp.swift`).

- Switch `DocumentGroup(viewing:)` to `DocumentGroup(newDocument:)`. SwiftUI then provides New,
  Save, Save As, Revert, "unsaved changes" prompts on close, and autosave/versions.
  `MarkdownDocument` already implements writing.
- Entitlement: change `files.user-selected.read-only` to `read-write`.
- UI idea: a plain text editor next to the rendered preview (split view), or a toggle
  between Edit and Preview.
- Auto-refresh must respect unsaved edits. If the file changes on disk while there are
  unsaved changes, ask instead of overwriting.

## Other

- Decide on a license (possibly MIT). See the README.
