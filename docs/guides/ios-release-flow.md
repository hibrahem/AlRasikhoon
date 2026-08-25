# iOS Release Flow — Al-Rasikhoon

How an iOS build travels from a developer's machine to a user's iPhone, and
what has to be true at each step. Written for someone new to Apple's release
machinery; the project-specific facts are at the bottom.

Companion docs: `.github/workflows/README.md` (CI secrets and prerequisites),
`docs/agdr/AgDR-0004-android-firebase-distribution.md` (the Android equivalent).

---

## 1. The three systems

Apple splits into three consoles what most platforms treat as one. Nearly every
confusing iOS error is these three disagreeing with each other.

| System | Owns | Al-Rasikhoon's state |
|---|---|---|
| **developer.apple.com** | Identity: App IDs, devices, certificates, provisioning profiles | Team `USVB42947P` (Tech Mentors LLC); App ID `com.alrasikhoon.alRasikhoon`; one registered device |
| **appstoreconnect.apple.com** | The product: app record, TestFlight, App Review, sales | App `6805197010`, SKU `AL-RASIKHOON-IOS-001`, primary locale `ar-SA` |
| **Your Mac / GitHub Actions** | Compiling and signing the binary | `.github/workflows/distribute-ios.yml` |

## 2. Code signing

iOS refuses to run code that isn't cryptographically vouched for. Four pieces:

- **App ID** — the app's permanent identity (`com.alrasikhoon.alRasikhoon`).
  Cannot be renamed after registration; a typo means registering a new one.
- **Certificate** — proves *who built it*. **Development** certificates run
  builds on your own registered devices; **Distribution** certificates ship to
  TestFlight and the App Store.
- **Provisioning profile** — the contract binding App ID + certificate +
  permitted devices. Development profiles enumerate specific devices;
  distribution profiles do not.
- **App Store Connect API key** — lets automation do all of the above without a
  human clicking through the portal.

### The archive → export → upload sequence

```
archive  → compiles and signs with a DEVELOPMENT certificate
export   → re-signs the same app with a DISTRIBUTION certificate
upload   → delivers it to App Store Connect
```

The non-obvious part: **`archive` needs a development provisioning profile even
for a release build**, and Apple will not issue one to a team with zero
registered devices. Distribution signing only enters at `export`. This is why a
brand-new team must register at least one device before it can ship anything.

## 3. The two version numbers

| Field | Example | Meaning |
|---|---|---|
| `CFBundleShortVersionString` | `1.0.0` | Marketing version. What users see. Change at will. |
| `CFBundleVersion` | `1` | Build number. **Must increase on every upload.** Reusing one is rejected. |

Both derive from a single line in `pubspec.yaml`:

```yaml
version: 1.0.0+1
#        ^marketing
#              ^build
```

`distribute-ios.yml` passes `--build-number=${{ github.run_number }}`, so CI
builds always get a unique, increasing build number. **Local builds do not** —
bump it yourself, or the upload is refused as a duplicate.

## 4. Development loop

1. **Simulator** — `flutter run`. No signing involved. Where most work happens.
2. **Physical device** — needs a development certificate and profile, and the
   device must be registered with the team.
3. **CI** — `ci.yml` runs analyze plus unit tests on every pull request.

None of this touches release machinery.

## 5. Testing tiers

| Tier | Audience | Review | Latency |
|---|---|---|---|
| **TestFlight internal** | ≤100 App Store Connect users | None | Minutes after processing |
| **TestFlight external** | ≤10,000, any email | Beta App Review on the first build of a version | ~24–48h first time |

**TestFlight builds expire after 90 days.**

External testing requires complete Test Information. Because Al-Rasikhoon is
login-gated with no self-service signup, that **must** include working demo
credentials.

## 6. Production release

1. Complete the **App Store listing** — screenshots per device size,
   description, keywords, support URL, and a **privacy policy URL (mandatory)**.
2. Complete the **App Privacy** questionnaire — what data is collected and why.
3. Set the **age rating**.
4. **Select a build** already uploaded and tested via TestFlight. Production
   never ships a fresh, untested binary.
5. **Submit for App Review** — typically a day or two.
6. **Release**: immediately on approval, manually, or **phased** over 7 days.

Subsequent updates repeat steps 4–6 only. The first submission is the expensive
one.

## 7. Project-specific notes

### What the app collects

Firestore collections: `users`, `institutes`, `students`, `teacher_institutes`,
`supervisor_institutes`, `levels`, `sessions`, `session_records`,
`sard_records`, `exam_records`, `home_practices`, `reposition_audit`,
`status_audit`.

Personal fields live on `UserModel`: `username`, `email`, `phone` (optional),
`name`, `role`. Everything else is memorization progress and assessment history.

Relevant to the App Privacy questionnaire:

- **No analytics, no crash reporting, no advertising SDKs.** Nothing in
  `pubspec.yaml` and nothing in `lib/`.
- **No tracking** in Apple's sense — no data shared with third parties for
  advertising, no cross-app identifiers.
- Sign-in emails are **synthesized**, not real: `<username>@alrasikhoon.local`
  (`AppConstants.synthesizedEmailDomain`).
- `firebase_storage` is declared in `pubspec.yaml` but **not used** anywhere in
  `lib/`.
- Data processor is Google Firebase (Auth, Firestore, Cloud Functions).

### Review requirements, checked against the code

- **Sign in with Apple: not required.** That rule triggers only when an app
  offers third-party social login. Authentication is email/password only — the
  `signInWithGoogle` strings in `lib/l10n/` are unused localization entries, not
  a real provider.
- **In-app account deletion: likely not applicable.** Guideline 5.1.1(v) applies
  to apps where users *create* accounts. Accounts here are provisioned by
  administrators through the `createUserAccount` Cloud Function;
  `account_not_found_screen.dart` directs users to contact a supervisor. Be
  prepared to explain this to a reviewer.
- **Demo credentials are mandatory.** A reviewer cannot sign up, so without a
  working account the submission is rejected. This is the most likely rejection
  cause for this app.
- **Export compliance is already declared** — `ITSAppUsesNonExemptEncryption`
  is `0` in `ios/Runner/Info.plist`, so no per-upload prompt appears.
- **Age rating deserves deliberate thought.** The user base plausibly includes
  children under 13, and the Made for Kids category carries a much stricter
  regime. Decide it consciously.

## 8. Manual runbook

Only needed when CI cannot be used. Normally use the **Distribute iOS**
workflow instead.

```bash
# 1. Compile (bump the build number — it must be unique per upload)
flutter build ios --release --no-codesign --build-number=<N>

# 2. Archive — development signing, needs >=1 registered device
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath /tmp/Runner.xcarchive archive \
  -allowProvisioningUpdates \
  -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_<ADMIN_KEY>.p8 \
  -authenticationKeyID <ADMIN_KEY> -authenticationKeyIssuerID <ISSUER_ID>

# 3. Export — re-signs for distribution, needs an ADMIN key
xcodebuild -exportArchive -archivePath /tmp/Runner.xcarchive \
  -exportOptionsPlist ios/ExportOptionsAppStore.plist \
  -exportPath /tmp/export -allowProvisioningUpdates \
  -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_<ADMIN_KEY>.p8 \
  -authenticationKeyID <ADMIN_KEY> -authenticationKeyIssuerID <ISSUER_ID>

# 4. Validate, then upload
xcrun altool --validate-app -f /tmp/export/al_rasikhoon.ipa -t ios \
  --apiKey <ADMIN_KEY> --apiIssuer <ISSUER_ID>
xcrun altool --upload-app -f /tmp/export/al_rasikhoon.ipa -t ios \
  --apiKey <ADMIN_KEY> --apiIssuer <ISSUER_ID>
```

Always `--validate-app` before uploading: it catches the same problems in
seconds that a failed upload surfaces after minutes of transfer.

## 9. Troubleshooting

Errors hit during the first real distribution (2026-08-25), with causes that
are not obvious from the message text.

| Error | Actual cause | Fix |
|---|---|---|
| `Your team has no devices from which to generate a provisioning profile` | Archive needs a *development* profile; Apple won't issue one to a team with no devices. Reads like a project misconfiguration; it is account state. | Register a device under Certificates, Identifiers & Profiles → Devices |
| `No profiles for 'com.alrasikhoon.alRasikhoon' were found` | Same root cause as above; appears alongside it | Same |
| `Cloud signing permission error` + `No signing certificate "iOS Distribution" found` | The API key lacks certificate-management permission. **App Manager is not enough** — cloud signing creates the distribution certificate, and those endpoints require **Admin**. The key authenticates and can upload, so this surfaces only at export. | Generate a new **Admin** key; roles cannot be changed after creation |
| `Runner has conflicting provisioning settings ... manually specified` | A `CODE_SIGN_IDENTITY` pinned in the project conflicts with automatic signing | Leave `CODE_SIGN_IDENTITY` unset and let automatic signing choose |
| Upload rejected as a duplicate build | `CFBundleVersion` reused | Bump the build number; CI does this automatically |

A note on verifying build settings: `xcodebuild -showBuildSettings` reports
static defaults and does **not** predict what automatic signing does during
`archive`. Run the actual archive to find out.

Beware exit codes through pipes — `xcodebuild ... | tail` reports `tail`'s
status, so a failed build looks successful. Redirect to a file and check `$?`,
as the runbook above does.
