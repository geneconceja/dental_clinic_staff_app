# Getting Started — Building the Dental Clinic Staff/Admin App

A concrete, in-order walkthrough for going from an empty folder to a working local dev loop. This is the "what do I actually type" companion to `CONTRIBUTING.md` (process/pipeline) and the main spec (architecture/decisions).

**Before you start:** at least items #1, #5, and #7 in `decisions-log.md` should ideally be answered first — they affect the security rules and the booking transaction's real safety. If you can't get answers immediately, proceed anyway using the documented assumptions, but don't deploy `firestore.rules` to production until #7 is confirmed.

---

## Step 0 — Get access to the shared Firebase project

This app does **not** create a new Firebase project — it connects to the existing one the patient app already uses.

1. Get added as a collaborator on the existing Firebase project (ask whoever owns the patient app).
2. Confirm you can see the `dental-clinic-dev` and `dental-clinic-prod` projects (or equivalent names) in the [Firebase Console](https://console.firebase.google.com).
3. Ask for a read-only export or a few sample documents from the live `appointments`, `services`, and `clinicSettings` collections if you don't already have them — you'll want real examples to seed your local emulator accurately, not just what's in the spec.

---

## Step 1 — Scaffold the Flutter project

```bash
flutter create dental_clinic_staff_app
cd dental_clinic_staff_app
```

Set up the feature-first folder structure from the spec (Section 9):
```bash
mkdir -p lib/core/{theme,utils,widgets}
mkdir -p lib/features/{auth,review_queue,walk_in_booking,dashboard,services_admin,settings,staff_management}
mkdir -p lib/routing
```

Add core dependencies:
```bash
flutter pub add firebase_core firebase_auth cloud_firestore cloud_functions firebase_messaging
flutter pub add flutter_riverpod
flutter pub add go_router   # or your preferred router
```

---

## Step 2 — Connect Firebase

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```
Select the **existing shared Firebase project** (both dev and prod if prompted, or run this twice with `--project` flags for each). This generates `lib/firebase_options.dart`.

Set up environment switching so you can build against dev vs prod:
```bash
flutter run -d chrome --dart-define=ENV=dev
```
(Wire `ENV` into whichever `firebase_options.dart` variant or config you use — flavors work too if you prefer that over `--dart-define`.)

---

## Step 3 — Set up the Cloud Functions project

```bash
mkdir functions && cd functions
npm init -y
npm install firebase-functions firebase-admin
npm install --save-dev typescript @types/node
npx tsc --init
cd ..
firebase init functions   # link to the same shared project, choose TypeScript
```

Copy `schema-types.ts` into `functions/src/schema-types.ts` — this is your source of truth for every document shape. Import it in every function file rather than redefining types inline.

---

## Step 4 — Set up the emulator suite

```bash
firebase init emulators
```
Enable: Authentication, Firestore, Functions, Hosting.

```bash
firebase emulators:start --import=./emulator-data --export-on-exit
```

Write the seed script early — this is the single highest-leverage thing you can do before writing any UI code:

```bash
touch scripts/seed-emulator.js
```

The script should create, against the emulator:
- 2-3 `services` docs
- 1 `clinicSettings/main` doc
- 2-3 `users` docs with `role: "staff"` / `"admin"`
- A handful of `appointments` docs covering **both** `bookingSource` values, and a spread of `status` values, using the real field shapes from `schema-types.ts` — including some legacy-style docs *without* `bookingSource` set, so you can verify `resolveBookingSource()` fallback logic works.

---

## Step 5 — Deploy the draft security rules to the emulator (not prod yet)

```bash
firebase deploy --only firestore:rules --project dev
```
Actually, for local work you don't need to deploy — the emulator picks up `firestore.rules` automatically on start. Just make sure the file is at the project root and re-run `firebase emulators:start` after any edit.

Write your first rules test before writing any app code that depends on them:
```bash
cd functions  # or a separate /tests directory, your call
npm install --save-dev @firebase/rules-unit-testing jest
```
Test at minimum: a staff user can read all appointments; a signed-in user with no `users/{uid}` doc (simulating a patient) cannot read someone else's appointment; nobody can directly `create` an appointment client-side (per the current locked-down assumption in `firestore.rules`).

---

## Step 6 — Build and test `createWalkInAppointment` first

This is the highest-risk piece of business logic (the transactional slot-booking) — build and test it in isolation before any UI touches it.

1. Implement it in `functions/src/createWalkInAppointment.ts` exactly per `functions-api-contract.md`.
2. Deploy to the emulator: functions hot-reload automatically when running `firebase emulators:start` if you're watching/building the TS output, or run `npm run build --watch` in `functions/` alongside the emulator.
3. Call it directly from a quick test script or Postman-style tool against the emulator's callable-functions endpoint before wiring up any Flutter UI — confirms the transaction logic works before you add UI complexity on top.
4. Write the concurrency test described in `CONTRIBUTING.md` (two near-simultaneous requests for the same slot — confirm only one succeeds).

---

## Step 7 — Now build the UI, in this order

Follow the phases in the main spec (Section 7), but concretely:

1. **Login screen** (`lib/features/auth/`) — staff/admin only, no registration UI
2. **Dashboard shell** (`lib/features/dashboard/`) — just routing/nav to start, no real data yet
3. **Review Queue** (`lib/features/review_queue/`) — read-only list of `pending` appointments first; wire up confirm/decline (calling `updateAppointmentStatus`) once the list renders correctly
4. **New Walk-In form** (`lib/features/walk_in_booking/`) — build against the already-tested `createWalkInAppointment` function from Step 6
5. Everything else (services admin, settings, staff management) — lower risk, build in any order once the core loop above works end to end

---

## Step 8 — First real milestone: a working end-to-end loop

Before moving further into polish or notifications, confirm this full loop works against the emulator:
1. Seed script creates a `pending` appointment
2. Staff logs in, sees it in the Review Queue
3. Staff confirms it → status updates, visible in Firestore emulator UI
4. Staff books a walk-in → new `confirmed` appointment appears, `bookingSource: "staff_walkin"`, `userId: null`
5. Staff attempts to book a walk-in in a slot that conflicts with an existing appointment → gets a clear error, not a silent double-booking

Once that loop is solid, you have a real foundation — everything else (admin tools, notifications, image analysis) builds on top of it without touching the risky transactional core again.

---

## What NOT to do yet

- Don't implement `sendReminders` or `onAppointmentStatusChange` — blocked per `decisions-log.md` #5
- Don't deploy `firestore.rules` to the **production** project until #7 in the decisions log is confirmed
- Don't build the image analysis Cloud Function until #6 is confirmed (reuse vs. duplicate)
- Don't spend time on responsive/mobile polish yet — this is a desktop-first internal tool; get the core loop working on desktop Chrome first