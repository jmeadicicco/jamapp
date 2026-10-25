# jam

A personal iOS app that brings Calendar, Reminders, Contacts and (later) Health, Music, Home and Mail into one on-device store, then surfaces what matters through the day. Built for one person and installed from Xcode; never published to the App Store.

Architecture and roadmap: [jam plan](https://claude.ai/artifact/9TjNpvEuhVGYEEByJqB62E).

## Status

Phase 1: app shell, local SwiftData store, Calendar, Reminders and Contacts connectors, and three screens:

- **Today**: today's events, reminders due or overdue, birthdays in the next 7 days.
- **People**: everyone from Contacts plus event attendees, merged by email, with linked items.
- **Sources**: connect each source and see its permission state.

## Build and install

Requirements: a Mac with Xcode 26 or later, an iPhone on iOS 26 or later, and an Apple ID signed in to Xcode.

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen), which generates the Xcode project from `project.yml`:
   ```sh
   brew install xcodegen
   ```
2. Set your signing team:
   ```sh
   cp Config/Local.xcconfig.example Config/Local.xcconfig
   ```
   Put your team ID in it (Xcode > Settings > Accounts > your Apple ID > Personal Team shows it). If Xcode later says the bundle id is taken, set `JAM_BUNDLE_ID` there too.
3. Generate and open the project:
   ```sh
   xcodegen
   open Jam.xcodeproj
   ```
4. Connect the iPhone, pick it as the run destination, and press Run.
5. First run only, on the iPhone: Settings > General > VPN & Device Management > trust your developer certificate. Developer Mode must also be on (Settings > Privacy & Security > Developer Mode).

Run `xcodegen` again whenever files are added or `project.yml` changes.

### Free Apple ID limits

Builds signed with a free Apple ID stop launching after 7 days; reconnect the phone and press Run again to renew. Free accounts also cannot use some capabilities planned for later phases (MusicKit service, push). A paid Apple Developer Program membership removes both limits.

## Layout

```
project.yml            XcodeGen project definition
Config/                build settings; Local.xcconfig holds personal signing values (git-ignored)
Jam/App/               app entry point
Jam/Model/             SwiftData models (Item, Person) and source definitions
Jam/Connectors/        one connector per framework; each returns plain snapshots
Jam/Sync/              SyncEngine: requests access, pulls each source, upserts into the store
Jam/Views/             SwiftUI screens
```

All data stays on the device. Nothing is sent to any server.
