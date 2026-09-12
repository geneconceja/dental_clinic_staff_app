# OralScope — Dental Clinic Staff & Patient Portal

> A full-stack **Flutter Web + Firebase** production application built for a single-dentist dental clinic. Staff and patients are served from the same web app, separated by role-based routing.

![Flutter](https://img.shields.io/badge/Flutter-Web-02569B?logo=flutter)
![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%7C%20Auth%20%7C%20Functions-FFCA28?logo=firebase&logoColor=black)
![TypeScript](https://img.shields.io/badge/TypeScript-Cloud%20Functions-3178C6?logo=typescript)
![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF?logo=github-actions&logoColor=white)
[![Live App](https://img.shields.io/badge/Live%20Demo-oralscope--78cda.web.app-4CAF50)](https://oralscope-78cda.web.app)

---

## What This Is

OralScope is a full-stack clinic management system with two portals served from a single Flutter Web deployment:

- **Staff/Admin Portal** — appointment review queue, walk-in booking desk, calendar, services management, staff account administration, and a real-time audit log.
- **Patient Portal** — self-registration with email verification, a multi-step booking wizard with real-time slot availability, appointment history, and profile management.

Both portals share a single Firebase project with strict Firestore security rules enforcing role boundaries. All appointment state transitions are handled by Cloud Functions (TypeScript) to guarantee consistency and trigger transactional email notifications via Brevo.

---

## Key Features

| Area | Feature |
|---|---|
| **Auth & Access** | Role-based routing (`admin` / `staff` / `patient`), patient self-signup with email verification, staff provisioned by admin only |
| **Appointment Flow** | Walk-in booking (staff-side), patient self-booking with slot conflict prevention, status state machine (`pending → confirmed → completed / cancelled / no-show`) |
| **Notifications** | Brevo transactional email on status change, scheduled appointment reminders via Cloud Scheduler |
| **Admin Tools** | Staff account management (create, deactivate, password reset), services CRUD, clinic hours & settings |
| **SSO** | Mobile-to-web single-use token handoff (`generateSsoToken` / `consumeSsoToken`) for linking the companion mobile app |
| **Audit** | Immutable `activity_logs` collection; real-time audit trail screen for admins |
| **CI/CD** | GitHub Actions: lint → test → build → deploy on every push to `main` |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter Web (3.x stable) |
| State Management | Riverpod |
| Routing | GoRouter |
| Backend | Firebase Auth · Cloud Firestore · Cloud Functions (2nd Gen) · Firebase Hosting |
| Functions Runtime | TypeScript · Node.js 22 |
| Email | Brevo transactional API |
| Testing | Dart Analyzer · `flutter test` · Jest · `@firebase/rules-unit-testing` |
| CI/CD | GitHub Actions |
| Functions Region | `asia-southeast1` (Singapore) |

---

## Live Demo

🌐 **[https://oralscope-78cda.web.app](https://oralscope-78cda.web.app)**

> The live app connects to the production Firebase project. Use the emulator + seed script for local development (see below) — the demo credentials below are **emulator-only**.

---

## Local Development

### Prerequisites

- Flutter SDK (stable channel) on `PATH`
- Node.js 22 LTS
- Java Runtime (JRE/JDK 11+) — *required by Firebase to run the Firestore emulator*
- Firebase CLI: `npm install -g firebase-tools`

### 1. Clone & Install

```bash
git clone <repo-url>
cd dental_clinic_staff_app
flutter pub get
cd functions && npm install && npm run build && cd ..
```

### 2. Configure Environment

```bash
# Root env — Firebase credentials for the Flutter app
cp .env.example .env
# Edit .env with your Firebase project values
# (for emulator-only development, any syntactically valid values will work)

# Functions env — Brevo email API key
cp functions/.env.example functions/.env
# The emulator works without a real Brevo key — emails are logged to the console
```

### 3. Start Firebase Emulators

```bash
firebase emulators:start
```

> 📖 **Detailed Guide:** See [`docs/local-emulator-testing-guide.md`](./docs/local-emulator-testing-guide.md) for full architecture diagrams, functions verification, and persistent data instructions.

### 4. Seed Demo Data

```bash
node scripts/seed-emulator.js
```

This creates the following demo accounts in the local emulator:

| Role | Email | Password | Portal |
|:---|:---|:---|:---|
| Admin | `admin@clinic.test` | `password123` | Staff portal — full access |
| Staff | `staff1@clinic.test` | `password123` | Staff portal — standard access |
| Staff | `staff2@clinic.test` | `password123` | Staff portal — standard access |
| Patient | `patient1@clinic.test` | `password123` | Patient portal — pre-verified |

> **Note:** These credentials only work against the local emulator. The live production app uses separate accounts.

### 5. Run the Flutter App (Dev Mode)

```bash
flutter run -d chrome --dart-define=ENV=dev
```

The `ENV=dev` flag points all Firebase SDKs at the local emulator automatically.

---

## Running Tests

```bash
# Cloud Functions & Firestore security rules tests (Jest)
cd functions && npm test

# Flutter static analysis
dart analyze

# Flutter unit tests
flutter test
```

---

## 🤖 CI/CD (GitHub Actions)

Continuous integration and deployment run automatically on every push. See [`.github/workflows/deploy.yml`](./.github/workflows/deploy.yml).

| Trigger | Pipeline |
|---|---|
| Pull Request | Lint + test + preview channel deploy |
| Push to `main` | Lint + test + production deploy |
| Manual (`workflow_dispatch`) | Production deploy on demand |

> **Required GitHub Secret:** `FIREBASE_SERVICE_ACCOUNT_ORALSCOPE_78CDA` — a GCP service account JSON key with Hosting/Functions deploy permissions.

---

## Manual Production Deployment

```bash
# 1. Build Cloud Functions
cd functions && npm run build && cd ..

# 2. Build Flutter Web (production)
flutter build web --release --dart-define=ENV=prod

# 3. Deploy
# Spark (free) plan — deploys Hosting & Firestore:
firebase deploy --only hosting,firestore --project=oralscope-78cda --force

# Blaze (pay-as-you-go) plan — deploys Hosting, Firestore, and Cloud Functions:
# firebase deploy --project=oralscope-78cda --force
```

---

## Project Structure

```
dental_clinic_staff_app/
├── lib/
│   ├── core/               # Shared models, services, theme, utilities
│   │   ├── models/         # Dart mirrors of Firestore document schemas
│   │   ├── services/       # ActivityLoggerService, etc.
│   │   ├── theme/          # AppTheme, AppColors
│   │   └── utils/          # FirebaseEmulator, FunctionsClient, SlotGenerator
│   ├── features/           # One folder per feature area
│   │   ├── auth/           # Login, signup, verification gate, SSO, password flows
│   │   ├── dashboard/      # Appointment timeline + KPI cards
│   │   ├── calendar/       # Week-view calendar grid
│   │   ├── review_queue/   # Pending appointment review + detail view
│   │   ├── walk_in_booking/# Walk-in appointment form (staff)
│   │   ├── services_admin/ # Clinic services CRUD (admin)
│   │   ├── settings/       # Clinic hours, holidays, slot config (admin)
│   │   ├── staff_management/ # Staff accounts: create, deactivate, reset password
│   │   ├── activity_logs/  # Immutable audit trail viewer (admin)
│   │   └── patient_portal/ # Patient dashboard, booking wizard, appointments, profile
│   └── routing/            # GoRouter with auth guards and role redirect logic
├── functions/
│   ├── src/                # Cloud Functions (TypeScript)
│   │   ├── index.ts        # Function exports
│   │   ├── schema-types.ts # Source-of-truth Firestore document types
│   │   ├── createWalkInAppointment.ts
│   │   ├── updateAppointmentStatus.ts
│   │   ├── onAppointmentStatusChange.ts  # Firestore trigger → Brevo email
│   │   ├── sendReminders.ts              # Scheduled reminders
│   │   ├── generateSsoToken.ts / consumeSsoToken.ts
│   │   ├── createStaffUser.ts / adminResetPassword.ts
│   │   └── brevoService.ts               # Email abstraction (dev-mock mode)
│   └── test/               # Jest tests for all functions + Firestore rules
├── scripts/
│   └── seed-emulator.js    # Seed emulator with demo users, services, settings
├── docs/                   # Architecture docs, API contracts, decisions log
├── firestore.rules         # Firestore security rules (production-hardened)
├── .env.example            # Environment variable template (copy → .env)
├── .github/workflows/      # CI/CD pipeline
└── LICENSE                 # MIT
```

---

## Documentation

| Document | Purpose |
|---|---|
| [`local-emulator-testing-guide.md`](./docs/local-emulator-testing-guide.md) | Complete step-by-step guide for local emulator setup, seeding, and testing |
| [`dental-clinic-appointment-system-plan.md`](./docs/dental-clinic-appointment-system-plan.md) | Full technical spec: data model, business logic, phased implementation |
| [`dev-process.md`](./docs/dev-process.md) | Phase-by-phase development history with implementation details |
| [`functions-api-contract.md`](./docs/functions-api-contract.md) | Input/output contract for every Cloud Function |
| [`app-workflow-transaction-flow.md`](./docs/app-workflow-transaction-flow.md) | User flows, booking transaction, status lifecycle, notification triggers |
| [`decisions-log.md`](./docs/decisions-log.md) | Open questions and their resolutions |
| [`CONTRIBUTING.md`](./CONTRIBUTING.md) | Branching strategy, testing requirements, pre-deploy checklist |

---

## License

MIT © 2026 Gene Conceja — see [`LICENSE`](./LICENSE)