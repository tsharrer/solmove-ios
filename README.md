# Solmove — iOS App

Native **SwiftUI** iOS app for Solmove, a boutique wellness marketplace (a gamified ClassPass competitor with an instructor sub-shift marketplace). Economics and seed data are ported directly from the *Wellness Marketplace Financial Model*.

Companion to the web prototype: https://tsharrer.github.io/solmove/

## Features

- **Three personas** via a role switcher (Member / Studio / Instructor), each with its own tab set.
- **Member**: role-aware home, studio discovery, class booking, bookings + ratings, membership tiers.
- **Map**: MapKit map of Houston studios with tappable pins → studio detail.
- **Per-persona profiles**:
  - Member — stats, achievements, favorites, "your instructors / studios".
  - Instructor — **gamified** XP, levels (Rookie→Legend), leaderboard rank, achievements, "teaches at".
  - Studio — blended rating, badges, achievements, instructor roster.
- **Two-sided reputation**: members rate **both** studios and instructors; each earns ratings + badges.
- **Favoriting / following** studios and instructors, with gamified follower counts.
- **Instructor gamification**: XP ring in the Shifts tab, level progression, unlockable achievements.
- **Economics** (studio only): membership revenue table, per-class and per-shift economics vs ClassPass.
- Persisted state (`UserDefaults`, key `solmove.v2`), light/dark theme toggle.

## Build & run

The Xcode project is generated with [XcodeGen](https://github.com/yonatan/XcodeGen) from `project.yml`.

```sh
xcodegen generate
open Solmove.xcodeproj      # or build from the command line:

xcodebuild -project Solmove.xcodeproj -scheme Solmove \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Requires Xcode 26+ (iOS 17 deployment target). `Solmove.xcodeproj/` is git-ignored — run `xcodegen generate` after cloning.

## Run it for real (with the live backend)

By default the login screen's **Continue in demo mode** runs fully offline with
seed data. To run against the real backend (auth, live studios/classes, booking,
gamification, messaging), follow the end-to-end setup in **[RUNNING.md](RUNNING.md)** —
it covers starting the `solmove-api` server, pointing the app at it (simulator vs.
physical device), logging in, and deploying to production.
