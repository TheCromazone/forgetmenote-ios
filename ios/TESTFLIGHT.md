# TestFlight upload checklist

This walks you through the one-time setup to publish your first TestFlight
build of Forget Me Note. Apple-side steps require web logins to App Store
Connect; Xcode does the upload.

## Prerequisites
- Apple Developer Program enrollment is active (paid annual, ~$99/yr).
- Xcode signed-in to your Apple ID with the team `DBCJXPJXQJ` selected.
- Bundle ID `com.matthewcromaz.forgetmenote.dev` works for dev. For
  TestFlight, decide if you want to ship under that bundle ID or register
  a "production" one (e.g. `com.matthewcromaz.forgetmenote`). If you change
  the production bundle ID, update `project.yml`
  `PRODUCT_BUNDLE_IDENTIFIER` for Release config and rerun `xcodegen`.

## One-time: register the bundle ID

1. https://developer.apple.com/account/resources/identifiers/list → blue `+`.
2. App IDs → App → Continue.
3. Description: `Forget Me Note`. Bundle ID: explicit, exact match.
4. Capabilities — enable:
   - **Push Notifications** (we use the badge subsystem; required even
     though we don't send pushes).
   - **Background Modes** (for `BGTaskScheduler`).
5. Continue → Register.

## One-time: create the App Store Connect record

1. https://appstoreconnect.apple.com/apps → blue `+` → New App.
2. Platforms: iOS. Name: `Forget Me Note`. Primary language: English.
3. Bundle ID: pick the one you registered. SKU: any unique string (e.g.
   `forgetmenote-v2`). User Access: Full.
4. Create.

## Archive + upload

From the repo root:

```bash
cd ios
xcodegen generate
pod install
open ForgetMeNote.xcworkspace
```

In Xcode:

1. Top bar device picker → **Any iOS Device (arm64)**.
2. Product → **Archive**. Takes ~2–4 min.
3. When the Organizer opens with the archive selected:
   - **Validate App** first. Apple checks signing + manifest + icon set
     before letting you upload. Fix any reported issues.
   - **Distribute App** → App Store Connect → Upload. Stay on screen until
     "Upload Successful" — closing early can corrupt the upload.
4. Wait ~10 min for App Store Connect to process the build. You'll get an
   email when it's ready.

## TestFlight internal testing (just you)

In App Store Connect → your app → TestFlight tab:

1. Internal Testing → `+` New Internal Group → name it `Self`.
2. Add yourself (your Apple ID) as a tester.
3. Builds → wait until the build status is "Ready to test", then enable
   it for the `Self` group.
4. On your iPhone, install the **TestFlight** app from the App Store.
   You'll get a TestFlight invite email.
5. Open the invite, redeem, install.

Internal testing has no Apple review and is instant after upload finishes
processing.

## TestFlight external testing (your friend + others)

1. Same TestFlight tab → External Testing → `+` New External Group.
2. Add testers by email or share a public link.
3. Builds → enable for that group. Apple does a 24-hour Beta App Review
   the first time, then subsequent builds in the same group go live without
   re-review.

## Privacy manifest reminder

`PrivacyInfo.xcprivacy` is bundled at the root of the .app via xcodegen
sources. Apple started enforcing this on May 2024 — if Validate App
rejects with "missing privacy manifest", check that the file landed in the
archive at `ForgetMeNote.app/PrivacyInfo.xcprivacy` (use Organizer → Show
Package Contents to inspect).

## Required app metadata (App Store Connect → App Information)

Before you can submit to the App Store proper (not needed for TestFlight):
- Screenshots: 6.9" (iPhone 16 Pro Max), 6.7" (15 Pro Max), 6.5" — at
  least 3 per size.
- App icon: already bundled via Assets.xcassets/AppIcon.appiconset.
- Description, keywords, support URL, marketing URL (optional).
- Age rating: questionnaire → likely 4+ (no objectionable content).
- Privacy policy URL: required if you collect any data. We don't, so a
  page that says "Forget Me Note stores all data on your device. We don't
  collect, share, or transmit any user data." suffices.
- In-app purchase configuration: only needed when wiring up real
  RevenueCat. For prototype, leave empty.
