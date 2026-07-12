# Contributing Guide — Dental Clinic Staff/Admin App

> This repo builds the **staff/admin-only** side of the system. Patients use a **separate, already-live app on a different platform** to register and submit requests — that app is out of scope here and is not part of this repo.
>
> **Critical constraint:** this app shares a Firestore project with the patient app. The `appointments` schema is **owned by the patient app** — this repo may only add new fields additively (see `bookingSource` in the spec) and must never rename, remove, or repurpose existing fields. Any schema change beyond a pure addition requires signoff from whoever maintains the patient app, before merging, not after.

This document defines the development pipeline for this project. Follow it to keep the dev/prod environments safe and the booking logic (the most fragile part of this system) well-tested.

---

## 1. Environments

Two separate Firebase projects are required:

| Environment | Firebase Project | Purpose |
|---|---|---|
| Development | `dental-clinic-dev` | Local development, emulator seeding, manual QA |
| Production | `dental-clinic-prod` | Live clinic data — never used for testing |

Configure both with:
```bash
flutterfire configure
```
Use `--dart-define=ENV=dev` / `--dart-define=ENV=prod` (or Flutter flavors) to switch which Firebase config the app builds against. Never hardcode prod credentials into a dev build.

### Firebase Emulator Suite
All local development runs against the emulator suite — not live Firebase.

```bash
firebase emulators:start --import=./emulator-data --export-on-exit
```
This covers Auth, Firestore, Functions, and Hosting locally. `--import`/`--export-on-exit` persists your seed data between sessions.

---

## 2. Getting Started

```bash
git clone <repo-url>
cd dental-clinic-app
flutter pub get
cd functions && npm install && cd ..
firebase emulators:start
flutter run -d chrome --dart-define=ENV=dev
```

Seed the emulator with test data before your first run:
```bash
node scripts/seed-emulator.js
```
(Seeds `services`, `clinicSettings/main`, a few sample `users` (staff/admin only — patient accounts live in the other app's Auth, not seeded here), and sample `appointments` covering **both** `bookingSource` values — `patient_app` (with `userId`/`userEmail` populated, mirroring real patient-app writes) and `staff_walkin` (with those fields null). Write this script early — you'll use it constantly.)

---

## 3. Branching Strategy

Trunk-based, kept simple for solo/small-team development:

- **`main`** — always deployable, maps to `dental-clinic-prod`
- **`dev`** — integration branch, maps to `dental-clinic-dev`
- **`feat/<name>`** — short-lived feature branches off `dev` (e.g. `feat/booking-flow`, `feat/staff-dashboard`)

Workflow:
1. Branch from `dev`
2. Build the feature against the emulator
3. Open a PR into `dev`
4. Once verified on the dev Firebase project, merge `dev` → `main` to ship

Commit at phase boundaries from the project spec (Setup & Staff Auth → Schema Reconciliation & Walk-In Booking → Review Queue & Dashboard → Admin Tools → Image Handling for Walk-Ins → Notifications → Polish) so history stays easy to bisect.

---

## 4. Build Order (per feature)

Always build in this order — data layer first, UI last:

1. **Firestore schema + seed data** for the feature
2. **Cloud Functions + security rules together** — write the rule test in the same sitting as the function. This is non-negotiable for anything touching `appointments`.
3. **UI** — build screens against the already-working emulator backend

Do not build UI against a function that hasn't been tested. It hides bugs until it's expensive to fix.

---

## 5. Testing Requirements

| Layer | Tool | What to cover |
|---|---|---|
| Firestore rules | `@firebase/rules-unit-testing` | Every status transition; that this app's client can never write to patient-app-owned fields (`userId`, `userEmail`, `firstName`, `lastName`, `phoneNumber`, `reason`, `imageUrl`, `analysisResults`) except through the sanctioned Cloud Functions; that walk-in creation always sets `userId`/`userEmail` to null, never fabricated values |
| Cloud Functions | Jest/Mocha against emulator | `createAppointment` double-booking prevention — test with concurrent requests for the same slot |
| Flutter | `flutter test` | Only for screens with non-trivial conditional logic (e.g. slot picker). Skip widget tests for simple display screens on MVP. |

Rules and function tests are the highest priority — they protect against double-booked appointments and unauthorized status changes, which are the two failure modes that actually hurt a real clinic.

---

## 6. CI/CD (GitHub Actions)

**On PR → `dev`:**
```yaml
- flutter analyze
- flutter test
- firebase emulators:exec --only firestore,functions "npm test"
```

**On merge → `main`:**
```yaml
- flutter build web --release --dart-define=ENV=prod
- firebase deploy --only hosting,functions,firestore:rules,firestore:indexes --project prod
```

Do not deploy to prod manually from a local machine except in a genuine hotfix emergency — and if you do, open a follow-up PR to keep `main` and the deploy history in sync.

---

## 7. Pre-Deploy Checklist

Before merging to `main` for the first time (going live):

- [ ] Firestore composite indexes deployed (check emulator logs for missing-index errors during QA — Firestore will throw an error with a direct link to create it)
- [ ] Security rules cross-checked against the **patient app's actual current rules** (not just this spec's assumptions) — get these from whoever maintains that app before finalizing, to avoid either app being unexpectedly blocked or overly permissive
- [ ] Confirm slot-availability logic matches the patient app's — if the two apps compute availability differently, double-booking is possible even with this app's transaction (see spec Open Questions)
- [ ] FCM web push tested on an actual mobile browser (Safari/Chrome mobile), not just desktop
- [ ] Firestore scheduled export to Cloud Storage enabled on the prod project (backup)
- [ ] Confirm whether this app can reuse the existing `analyzeImage` Cloud Function/logic or needs its own copy for walk-in photos
- [ ] Confirm Cloudinary signed-upload preset is configured so the client never has direct access to the API secret
- [ ] Confirm who owns notification sending (reminders, status-change emails) to avoid duplicate sends from both apps
- [ ] `clinicSettings/main` populated with real working hours before go-live

---

## 8. Code Style

- Flutter: follow `flutter_lints` defaults, feature-first folder structure (see spec Section 9)
- Cloud Functions: TypeScript, one function per file under `functions/src/`
- Commit messages: `<phase>: <short description>` (e.g. `booking-engine: add slot conflict transaction`)

---

## 9. When in Doubt

Refer to the main spec (`dental-clinic-appointment-system-plan.md`) for data model field names, status transition rules, and business logic. Don't invent new field names or status values — consistency with the spec is what keeps the AI-assisted development loop reliable.
