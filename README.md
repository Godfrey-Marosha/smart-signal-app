# Street Signal

**The early signal for your street.** Residents report water and power outages, log their prepaid electricity, and get warned *before* the next outage or before their units run out. Ward leaders work on the same data in the .NET web dashboard.

This repo is the **Flutter mobile app**. Version 1 is deliberately small: water and electricity only.

## What's in version 1

| Screen | What it does |
| --- | --- |
| Sign in | Email/Password (with "Forgot password?"), Google, Apple |
| Set up your home | Name, area + ward, people at home, prepaid yes/no, electricity budget, litres of stored water, consent |
| Home | Status ("Water and power are on"), three quick actions, next 48 hours: outage forecasts with one action and a **Done** button, "units run out" and budget warnings; "Did this happen?"; ward alerts |
| Report (3 taps) | Water or electricity → what's happening → send. "Back on" closes your report |
| Area | Your open reports, and the last 7 days of reports grouped into incidents |
| Electricity | One headline ("lasts about 3 days, buy R260"), 14-day usage chart with trend, budget bar; log a top-up or units left |
| Community | Five sectors: **Food** (gardens and pantries, bulk-buy groups, surplus food), **Energy** (best times to use power, charging spots, group buying of solar or gas), **Water** (quality checks, working water points, spare stored water), **Transport** (lifts, lending things, road and access problems), **Prepare** (neighbours who can help, plus a private list of your home's emergency needs). Join or respond in one tap; optional WhatsApp contact |
| Me | Your home, what Street Signal did for you, your community activity, your area, settings |
| Settings | Account, edit household, load pilot history, sign out |

## Run it

```powershell
flutter pub get
flutter run                                  # live Firebase (default)
flutter run --dart-define=DEMO=true          # offline demo, no Firebase needed
flutter test
flutter analyze
```

## Firebase setup

1. `flutterfire configure --project=<your-project-id>` (creates `lib/firebase_options.dart` and `android/app/google-services.json` for package `za.co.streetsignal.app`).
2. Firestore: **Firestore Database → Create database**, then deploy the rules: `firebase deploy --only firestore:rules` (file: `firebase/firestore.rules`).
3. Sign-in methods, under **Authentication → Sign-in method**:

### Email/Password (about 1 minute)
Enable **Email/Password**. Done.

### Google (about 15 minutes)
1. Enable **Google** and pick a support email.
2. Get your debug SHA-1:
   ```powershell
   cd android
   .\gradlew signingReport
   ```
   Copy the SHA-1 for `debug`.
3. Firebase console → **Project settings → Your apps → Android app** → **Add fingerprint** → paste the SHA-1.
4. Run `flutterfire configure` again so `google-services.json` includes the new OAuth client.
5. Copy the **Web client ID** (Authentication → Sign-in method → Google → *Web SDK configuration*, or the `oauth_client` with `"client_type": 3` in `android/app/google-services.json`) into `lib/auth/sign_in_config.dart` as the `defaultValue`. Android won't return a Firebase token without it ("serverClientId must be provided").
6. Test on a phone or emulator that has a Google account added (emulators: pick a *Google Play* image).
7. Before release, add your release key's SHA-1 too (and Play App Signing's SHA-1 if you use Google Play).

### Apple (needs an Apple Developer account, US$99/year)
1. In [Apple Developer → Certificates, IDs & Profiles](https://developer.apple.com/account/resources):
   - Create an **App ID** with *Sign in with Apple* enabled.
   - Create a **Services ID** (e.g. `za.co.streetsignal.signin`), enable *Sign in with Apple*, and add the return URL
     `https://<your-project-id>.firebaseapp.com/__/auth/handler`.
   - Create a **Key** with *Sign in with Apple* enabled; download the `.p8` file and note the Key ID and your Team ID.
2. Firebase console → enable **Apple** and enter the Services ID, Team ID, Key ID and the private key.
3. On Android, Apple sign-in opens a secure browser page; nothing else is needed in the app.
4. On iOS, also add the **Sign in with Apple** capability in Xcode (Runner → Signing & Capabilities).

On Android the Apple button is hidden until you've done this; then run with `--dart-define=APPLE_ON_ANDROID=true`. It always shows on iPhone.

## Faster builds on Windows

- The first `flutter run` is slow (5-10 minutes); later runs reuse the Gradle cache. Avoid `flutter clean` unless something is broken.
- Leave `flutter run` running and press **r** (hot reload, about 1 second) or **R** (hot restart) instead of stopping and starting again.
- Add Windows Security exclusions for your project folder, the Flutter SDK, `%USERPROFILE%\.gradle`, `%LOCALAPPDATA%\Android\Sdk` and `%LOCALAPPDATA%\Pub\Cache`. Antivirus scanning is often the biggest slowdown.
- Use a real phone over USB, or an x86_64 emulator with hardware acceleration. Close Android Studio's emulator and other heavy apps if you have 8 GB of RAM.
- `android/gradle.properties` turns on the build cache and parallel builds and limits Gradle to 4 GB of memory.

## Pilot history (for demos)

A brand-new database has no history, so there's nothing to forecast from or measure. **Load pilot history** (on Home, or in Settings) writes an 8-week pilot for your ward, shaped like a real township:

- **46 households**, several reports per outage, about 30 outages and 250 reports
- Regular patterns the app learns: water off Tuesday evenings, low pressure Thursday and Saturday mornings, power off Monday and Wednesday evenings, each on most but not all weeks
- Two unplanned outages no forecast could predict (a 31-hour burst main, 14-hour cable theft)
- Your home's last 6 weeks: meter readings, five R300 top-ups after "runs out soon" warnings, and about 12% lower use after switching the geyser to a timer
- A forecast track record with "Did this happen?" answers, including misses

Every pilot document has `pilot: true` (reports also carry `pilotHousehold`), so it can be removed later. Demo mode loads it automatically.

## Data for the web dashboard

Every report carries dashboard-ready fields (area, ward, people affected, duration, day / weekday / hour buckets, source). Household sub-records carry `areaId` for per-area queries. See **[docs/DASHBOARD_DATA.md](docs/DASHBOARD_DATA.md)** for every field and which chart it powers.

## Project structure

```
lib/
  main.dart                       live Firebase by default; DEMO=true for offline
  app.dart                        sign in → set up home → main app
  auth/                           AuthService + Firebase (email, Google, Apple) and demo versions
  core/enums.dart                 wire values shared with the .NET dashboard (Wire.cs)
  data/                           Repository + Firestore and demo implementations
  logic/prediction_engine.dart    all forecasting, unit-tested, to be ported to C#
  logic/pilot_history.dart        the small pilot dataset
  state/app_state.dart            app state (no extra state-management package)
  screens/                        sign in, onboarding, home, report, area, electricity, settings
test/                             engine, pilot data and a sign-in-to-Home widget test
firebase/firestore.rules          security rules for the mobile app
```

## After the hackathon

- Push alerts (firebase_messaging) from the dashboard's Broadcast page
- Map view and GPS area detection
- Neighbour sharing (water, charging, lifts)
- Food prices and transport disruptions
- isiZulu and Sesotho translations
