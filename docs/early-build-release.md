# Early Mac preview — 30 October 2026

Version 0.1.0 (3), bundle `com.wirebuilds.outloud.preview`, macOS 14+,
Universal Apple Silicon/Intel. Activation and countdown only; no marketing
workspace or sample data. Saving a pre-order does not start paid access.

## Sandbox distribution

The website and app both use the isolated test licensing Worker. Never embed
Stripe keys or the issuer secret in the app. `OutloudLicenseEnvironment=test`
is recorded in the signed app bundle; test licenses cannot unlock live access.
The DMG contains `Outloud Preview.app` and an Applications shortcut.

The revised flat UI was archived, exported with automatic Developer ID signing,
and uploaded to Apple's notary service. The signed app passed strict signature
verification; the DMG mounted and its enclosed app passed the same check.

Apple notarization is still processing. Website download notes disclose that
macOS may block this sandbox build. This is a test download, not a launch-ready
installer. Do not remove that note until a ticket is successfully stapled and
validated. Do not publish the older activation-card builds.

## Finish notarization

Archive: `/tmp/outloud-distribution/Outloud-Preview-Flat.xcarchive`
Signed app: `/tmp/outloud-distribution/flat-export/outloud.app`
Submission: `dae91e63-3ae7-46ae-a8d4-3abb9ca00cb2`

Use Xcode's export-notarized-app operation on that archive, or staple and validate
the signed app after Apple acceptance. Recreate the DMG from the stapled app,
replace the website's matching download, set `earlyBuildNotarized=true` in
`src/lib/commerce.ts`, rebuild and redeploy. Verify the downloaded file checksum,
Developer ID signature and Gatekeeper assessment before a public live release.

## Before live payments

Keep sandbox until Jimmy approves the complete test flow. A live release needs
separate D1 inventory, live Stripe webhook/credentials, production app licensing
configuration and a corresponding signed/notarized app. Retire the old uncapped
live Payment Link; the new 150-place limit belongs to Checkout created by the
licensing API. Never migrate sandbox counts into live sales.

## Revision 0.1.1 (5): Outloud + signed updates

The app and DMG are named Outloud (`Outloud.app`, `Outloud-0.1.1.dmg`).
The internal sandbox bundle identifier remains stable so installations and update
verification retain the same identity. This build uses explicit `outloud/Info.plist`
metadata: custom INFOPLIST_KEY build variables were not preserved by Xcode's
metadata generator. Never assume they reached an exported app; inspect the bundle.

Sparkle 2.10.0 is pinned in Package.resolved. The sandbox update feed is
`https://tryoutloud.pages.dev/updates/sandbox/appcast.xml`. Automatic checks and
updates are enabled, with a manual Check for Updates command. Sparkle's sandbox
installer helper and mach-lookup entitlements are configured. Exported updater
helpers were verified as Developer ID signed alongside the app.

Update signing account in macOS Keychain: `com.wirebuilds.outloud.updates`.
The private key remains in Keychain; only its public key is embedded in the app.
Use generate_appcast with this account when publishing each new release. Its
DMG EdDSA signature was verified with sign_update before publishing. Increasing
the bundle version and publishing a signed archive/feed is required for future
updates; the countdown by itself does not download unreleased software.

Archive: `/tmp/outloud-distribution/Outloud-Configured.xcarchive`
Export: `/tmp/outloud-distribution/configured-export/Outloud.app`
Apple upload log: `/tmp/outloud-configured-notarize.log`
Notarization remains pending. A successful upload is not approval. Once accepted,
staple the app, rebuild and re-sign the DMG update archive, regenerate the appcast,
replace both public files, and only then remove the pending-review notice.
The full replace-and-relaunch update cycle still needs verification with two
notarized releases before live distribution. Older Preview builds have no updater;
install the renamed build once before testing future updates.

## Notarization completed — 30 October 2026

Apple exportNotarizedApp succeeded for Outloud-Configured.xcarchive. The exported
Outloud.app was stapled and validated; Gatekeeper accepted it with source
`Notarized Developer ID`. A new DMG was created from the stapled app and the
Sparkle appcast regenerated. The update archive signature verified successfully.
The app INSIDE that final DMG was mounted, signature-checked, ticket-validated
and assessed by Gatekeeper successfully.

Public artifact: `/downloads/Outloud-0.1.1-5.dmg`. The new filename avoids serving
an older cached installer. Previous download URLs redirect to this artifact.
`earlyBuildNotarized=true` removes the pending-review notice. Stripe stays sandbox.
This resolves notarization; a full two-release updater installation test remains
separate from this artifact's signature/ticket and feed verification.


## 31 October 2026: 0.1.2 (7)

The redesigned founding-pass/countdown UI replaces the rejected connection diagram.
A locally bundled licensed Lottie bell plays inside the update notification, respects
Reduce Motion, and uses intrinsic sizing scaled into a bounded frame on macOS.
Visible sandbox badges were removed from the Mac UI; billing and licensing remain
isolated in the test environment. The icon mark is modestly larger. License input is
single-line and automatically grouped, with activation feedback. Entitled Data
Protection Keychain storage was exercised without a password prompt.

Universal arm64/x86_64, macOS 14+. Developer ID notarization accepted; ticket stapled
and validated on the app inside the final DMG. Gatekeeper reports Notarized Developer
ID. Sparkle EdDSA signature verified before publishing version 7 to the test feed.
The public archive checksum matches the verified local DMG. The actual user-driven
installation from version 5 should be exercised with Check for Updates; it was not
forced onto the user's running app.

Checkout has fixed 99.99 prices in USD/GBP/EUR and optional 199.99 renewal in the
purchase currency. Adaptive conversion is disabled. The real batch is 151 places,
with no invented prior sales. Existing slots and order associations were preserved
by the migration. Availability polls every five seconds and on tab focus. Atomic
holds prevent overselling; signed payment events issue licenses; refunds revoke
licenses and release places. Sold-out server and UI behavior tested.

The downloadable license is now a locally generated branded PDF containing the key,
usage rights and public support address only. The buyer email is retained privately
for recovery, not returned in the license response or written into the PDF.
The older voluntary 14-day promise is preserved for earlier purchases. New policy
retains statutory rights without adding a new voluntary post-delivery window.

15 backend tests passed. Hosted GBP checkout and paid PDF download passed. Header
CTA, EUR selection, mobile widths, and sold-out UI were exercised. Cloudflare Worker
observability enabled. Live payments remain disabled pending owner acceptance.


## 1 November 2026: 0.1.3 (10)

The final certificate uses a refined black version of the founder-supplied signature,
a blank embossed gold medal with green ribbon tails, and a short certificate layout.
No logo or label appears in the medal. The same blank medal replaces the bell in
the app. Intermediate builds 8 and 9 were never published. Version 10 adds a neutral
opening state until the initial saved-license check completes, preventing activation
form flashes. A three-second local delay test captured the opening state followed
by the countdown without the input form. All fixtures used the isolated QA Keychain.

The edition has 200 planned licenses: 151 public pre-order slots plus 49 held back
from sale. The 49 are never described as purchased. Existing D1 public slots remain
151 and retain all order associations. The website uses a restrained allocation
strip above pricing instead of a liquid bubble. The API reports batch_total=200,
held_back=49 and actual issued/held/remaining public inventory. Sandbox activity is
identified as testing, not customer sales.

Currency is automatic: trusted Cloudflare country selects GBP for the UK, EUR for
current euro-area locations, and USD elsewhere. The gateway overwrites the country
header. Checkout body currency values are ignored. Stripe has fixed 9999 minor-unit
prices and automatic conversion disabled. Hosted API checks verified GB/DE/KE; 15
backend tests passed. The manual currency selector is removed.

Version 10 was notarized, stapled and Gatekeeper-accepted in its final DMG. The
Sparkle update signature was verified. Publication uses Outloud-0.1.3-10.dmg.
No live payment configuration has been enabled. Existing order promises remain.
