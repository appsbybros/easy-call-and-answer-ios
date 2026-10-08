# Easy Call & Answer for iPhone

A calm, accessible favorite-contacts app: large contact cards, phone keypad, useful notes, local call reminders, and guidance for Apple's accessibility and Bluetooth settings. Native SwiftUI, iOS 17+, iPhone and iPad. English and Hebrew, including right-to-left layout and Dynamic Type.

See [BUILD_STATUS.md](BUILD_STATUS.md) for exact verification and release limits.

## Honest platform boundary

Ordinary carrier calls are handed to Apple's Phone app through the public `tel:` API. Easy Call does not pretend to answer, end, record, automatically place, or track a carrier call. It is not an Android default-dialer port and does not claim the EU-only default-dialer entitlement. FaceTime Audio is an optional handoff. Device/carrier charges and availability still apply.

## Build and verify

Install Xcode and XcodeGen on macOS, then run `swift test`, `xcodegen generate`, and open `EasyCall.xcodeproj`. The GitHub **Build, test and capture iOS** workflow executes core tests, builds the app, runs UI tests on iPhone and iPad simulators, and exports actual screenshot attachments. It also tests trial/lifetime purchases on a compact iPhone and compiles Release for physical iOS devices without signing. No Apple secrets are needed for verification. See [the actual screens](docs/preview-compiled.html) and [recorded results](docs/verification-mac.json).

UI tests use `--screenshots` only in Debug: seeded fictional contacts and calling disabled. Release ignores that argument. Simulator evidence does not prove real cellular, Bluetooth, notification delivery, Contacts import, or StoreKit production behavior. The release checklist records those physical-device checks separately.

## Privacy and commerce

No account, advertising, analytics SDK, call-log access, microphone permission, or backend. Selected contacts, notes, photos and reminders are local. Apple device backups may contain them. Reminder notification previews may display a contact's name.

Calling and four favorites are free. Optional extra favorites and reminders have a deliberately started free StoreKit 14-day Trial, with no renewal or automatic conversion. The free non-consumable is `com.appsbybros.easycall.trial14`; its verified original purchase date determines the trial period. A one-time StoreKit non-consumable unlocks extras: `com.appsbybros.easycall.lifetime`. Already saved contacts remain callable after expiry or refund. The trial start is restored from verified StoreKit entitlements. A local latest-seen time also guards ordinary clock rollback; this is not a server-based anti-tampering system or a subscription trial.

The bundle identifier is `com.appsbybros.easycall`. App Store Connect registration, the two configured purchases, and Apple signing credentials are separate release setup steps. They are not created by the simulator build.

Copyright © 2026 Apps by Bros. All rights reserved.
