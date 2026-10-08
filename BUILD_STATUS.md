# Easy Call iOS verification — 8 October 2026

This application is implemented but is **not yet release-verified**.

Last pushed revision: `736e877`. GitHub run:
https://github.com/appsbybros/easy-call-and-answer-ios/actions/runs/37732679519

- Native iOS application compiled; 6 Swift core tests passed.
- 4 iPhone simulator UI tests passed: English calling flow with fictional contacts,
  Hebrew, largest accessibility text/landscape, and manual contact save/relaunch/remove.
- StoreKit Test failed while loading its configuration on the iOS 26.5 runtime:
  `SKInternalErrorDomain Code=3`, “Error saving configuration file.” Apple acknowledges
  this runtime problem as FB22237318: https://developer.apple.com/forums/thread/826971
- iPad tests and device Release compilation did not run after that failure.

Local changes awaiting the next GitHub verification:

- A separate required purchase/compact-screen job on Xcode 26.1.1 and iOS 26.1,
  while current-runner iPhone/iPad and Release verification remain required.
- Improved large-text space, keyboard dismissal and screenshot settling.
- A free non-consumable `com.appsbybros.easycall.trial14`, named `14-day Trial`,
  uses Apple's verified original transaction date. Both trial and lifetime purchase
  restore/refund tests remain enabled. The local test price is zero; actual Apple
  products have not been created. This follows App Review guideline 3.1.1.
- Reminder permission-delay, duplicate-save and dismissal handling; contact removal
  also cancels delivered reminders.

The final local changes have **not** been compiled on a Mac. Automatic approval
review rejected the requested repository push; an explicit follow-up approval
question is pending. No alternative upload path was used.

`Scripts/validate-resources.py` checks localized resources and store text only.
Earlier screenshots in `docs/preview-compiled.html` identify their exact source
commit and are review evidence, not a completed final screenshot submission.

No physical iPhone calls, Bluetooth routes, real Contacts imports or delivered
notifications have been tested. TestFlight signing requires the six documented
repository secrets and a passing verification run for the exact upload commit.
No signed IPA, App Store Connect build or public store release is claimed.

The Android reliability audit is `docs/android-review.html`; original SimpleCall
working-tree changes were preserved. Nine isolated adapter tests passed, while its
full Android test task is blocked by missing sibling library projects.
