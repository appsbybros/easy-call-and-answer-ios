# Easy Call iOS — verified source, 8 October 2026

Source revision `8cc90fd` passed [Mac verification](https://github.com/appsbybros/easy-call-and-answer-ios/actions/runs/37767175315). The final handoff
commit adds the resulting screenshots and documentation without changing app code.
Its own workflow must also be green before the TestFlight gate allows that commit.

The first attempt hit an Xcode simulator launch timeout before the accessibility test began. The failed job was rerun on the unchanged commit; the successful result below is that retry.

- Six Swift core tests passed.
- Four UI tests passed on each of the large iPhone, iPad and compact iPhone simulators:
  English, Hebrew, maximum accessibility text/landscape, and saved-contact persistence/removal.
- Two StoreKit tests passed: free-trial original purchase date/expiry/restore/refund,
  and lifetime purchase/restore/refund. Purchases used local StoreKit test data.
- Release compiled successfully for physical iOS devices, with signing disabled.
- Sixteen original English/Hebrew screenshots are packaged for 6.9-inch iPhone and
  13-inch iPad. Exact device names, hashes and source commit are in
  `app-store/screenshots-provenance.json`; browse `docs/preview-compiled.html`.
- English and Hebrew resources and listing lengths passed validation.

Purchase tests run on Xcode 26.1.1 / iOS 26.1 because Apple acknowledges a StoreKit
Test configuration failure on iOS 26.5 (FB22237318). Current-runner iPhone/iPad and
Release checks remain enabled. Assertions were not weakened to bypass that failure.

Apple products are not configured: `com.appsbybros.easycall.lifetime` is the
optional lifetime upgrade; `com.appsbybros.easycall.trial14` must be a free
non-consumable named **14-day Trial**, with Family Sharing off. Its verified original
purchase date determines the trial period. Calling and four favorites stay free.

No physical iPhone calls, Bluetooth routes, real Contacts imports or delivered
notifications have been tested. No signed IPA or TestFlight/App Store release is
claimed. Follow `docs/release.html` for the app record, products, six signing/upload
secrets and remaining physical-device checks. TestFlight requires a successful
verification run for the exact upload commit.

The original SimpleCall working-tree changes were preserved. Nine isolated Android
call-adapter tests passed; full Android tests are blocked by missing sibling libraries.
See `docs/android-review.html` for specific code findings and limits.
