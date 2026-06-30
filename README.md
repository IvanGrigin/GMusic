# GMusic

A local-first iOS music library app. You import MP3/M4A/AAC/FLAC/WAV/AIFF files,
GMusic copies them into its own sandboxed storage (verifying a SHA-256 hash
before ever touching the original), lets you edit metadata/artwork/albums/
playlists, and plays everything back with full Lock Screen / Control Center
integration.

This repository contains **Swift source files only** — no `.xcodeproj`. You
create the Xcode project yourself and add these folders as a target.

## Why no .xcodeproj?

Generating a `.xcodeproj` by hand (outside Xcode) is brittle and tends to
produce project files that don't open cleanly. Since this code can't be
compiled in the environment it was written in, it's safer to hand you clean
source files and let Xcode generate its own project file, which is guaranteed
to be valid.

## Setting up the Xcode project

1. Open Xcode → **File → New → Project… → iOS → App**.
2. Product Name: `GMusic`. Interface: **SwiftUI**. Language: **Swift**.
   Minimum deployment target: **iOS 17.0** (required for SwiftData and the
   modern AVFoundation async APIs used throughout).
3. Once the project is created, delete the placeholder `ContentView.swift`
   and the generated `@main` App file — they're replaced by `App/GMusicApp.swift`.
4. Drag the following folders from this repository into your Xcode project
   (check "Copy items if needed" and add them to the `GMusic` target):
   - `App/`
   - `Core/`
   - `Features/`
   - `DesignSystem/`
   - `Shared/`
5. Create a second target group for tests: **File → New → Target → Unit
   Testing Bundle**, name it `GMusicTests`, then drag in the `GMusicTests/`
   folder from this repo (these tests use the **Swift Testing** framework,
   `import Testing`, available in Xcode 16+).
6. In your app target's **Info** tab, add a **Background Modes** capability
   and enable **Audio, AirPlay, and Picture in Picture** — this is required
   for playback to continue when the app is backgrounded and for Lock
   Screen / Control Center controls to work.
7. Build and run on an iOS 17+ simulator or device.

No third-party dependencies are used — every `import` in this codebase
(`SwiftUI`, `SwiftData`, `AVFoundation`, `MediaPlayer`, `CryptoKit`, `UIKit`,
`PhotosUI`, `UniformTypeIdentifiers`) is a system framework, so there is
nothing to fetch via Swift Package Manager or CocoaPods.

## Architecture

- **Core/Models** — SwiftData `@Model` classes (`Track`, `Album`, `Playlist`,
  `Artwork`, `ImportRecord`). Relationships between them are plain `UUID`
  foreign keys, resolved through repositories, rather than SwiftData
  `@Relationship` macros.
- **Core/Database** — `ModelContainerFactory` plus one `@ModelActor` actor
  per model for safe concurrent access.
- **Core/Storage** — `StoragePaths`, `FileStorage`, `FileHashingService`,
  `ArtworkFileStore`. Everything the app considers "the library" lives under
  one root directory (`Application Support/GMusic`).
- **Core/Metadata** — reads embedded ID3/iTunes tags via AVFoundation, falls
  back to filename parsing, extracts embedded artwork.
- **Core/Import** — `ImportPipeline` orchestrates: copy to staging → hash →
  duplicate check → read metadata → move into the library → re-hash and
  verify → commit to the database → only then, optionally, delete the
  source file. `SourceDeletionService` is the single place in the app
  allowed to delete a file outside the library, and only does so after
  confirming the library copy exists and its hash matches.
- **Core/Cleanup** — `ExternalDuplicateScanner` / `ExternalDuplicateCleaner`
  find and safely remove files elsewhere on disk that duplicate tracks
  already in the library, reusing the same safety checks.
- **Core/Audio** — `PlayerEngine` (thin `AVPlayer` wrapper), `QueueManager`
  (queue/shuffle/repeat), `NowPlayingInfoService` (Lock Screen / Control
  Center), and `PlayerService`, the single `@MainActor` `ObservableObject`
  the UI talks to.
- **Features/** — SwiftUI views + view models: `Library` (tracks/albums/
  playlists, search, favorites, playlist management), `ImportInbox` (file
  picker, connected-folder scanning, import history), `NowPlaying` (full
  player, queue editing), `TrackEditor` (metadata + artwork editing),
  `Storage` (library size, external duplicate scan/cleanup), `Settings`
  (import policy toggles).
- **App/** — `GMusicApp` (entry point), `AppEnvironment` (composes every
  repository/service exactly once), `RootView` (tab bar + mini player).

## The project's core rule

The app's own library directory is the single source of truth. A source
file outside that directory is only ever deleted after: (1) it has been
copied into the library, (2) the library copy has been verified to exist on
disk, and (3) a fresh SHA-256 hash of the source matches the hash recorded
for the library copy. If any of those checks fail, the source file is left
alone.
