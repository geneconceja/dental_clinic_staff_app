# OralScope — Dental Clinic Staff & Patient Portal

> A full-stack **Flutter Web + Firebase + Render** production application built for a single-dentist dental clinic. Staff and patients are served from the same web app, separated by role-based routing, with server-side transactions powered by a dedicated Express API hosted on Render.

![Flutter](https://img.shields.io/badge/Flutter-Web-02569B?logo=flutter)
![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%7C%20Auth%20%7C%20Hosting-FFCA28?logo=firebase&logoColor=black)
![Render](https://img.shields.io/badge/Backend-Render-46E3B7?logo=render&logoColor=white)
![Express](https://img.shields.io/badge/API-Express.js-000000?logo=express&logoColor=white)
![TypeScript](https://img.shields.io/badge/TypeScript-5.6-3178C6?logo=typescript)
![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF?logo=github-actions&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green)
[![Live App](https://img.shields.io/badge/Live%20Demo-dental--clinic--ams.web.app-4CAF50)](https://dental-clinic-ams.web.app)

---

## Table of Contents

- [What This Is](#what-this-is)
- [Key Features](#key-features)
- [Tech Stack](#tech-stack)
- [Live Demo & Presentation Guide](#-live-demo--presentation-guide)
- [Local Development](#local-development)
- [Running Tests](#running-tests)
- [CI/CD](#-cicd-github-actions)
- [Manual Production Deployment](#manual-production-deployment)
- [Project Structure](#project-structure)
- [Documentation](#documentation)
- [Security & Data Privacy](#security--data-privacy)
- [Support](#support)
- [License](#license)

---

## What This Is

OralScope is a full-stack clinic management system with two portals served from a single Flutter Web deployment:

- **Staff/Admin Portal** — appointment review queue, walk-in booking desk, calendar, services management, staff account administration, and a real-time audit log.
- **Patient Portal** — self-registration with email verification, a multi-step booking wizard with real-time slot availability, appointment history, and profile management.

Both portals share a Firebase project with strict Firestore security rules enforcing role boundaries. Backend state transitions, walk-in slot locking, analytics aggregation, and staff management are executed via an **Express REST API hosted on Render**, triggering transactional email notifications via Brevo.

---

## Key Features

| Area | Feature |
|---|---|
| **Auth & Access** | Role-based routing (`admin` / `staff` / `patient`), patient self-signup, staff provisioned by admin only |
| **Appointment Flow** | Walk-in booking (staff-side), patient self-booking with slot conflict prevention, status state machine (`pending → confirmed → completed / cancelled / no-show`) |
| **Backend API** | Standalone Express server on Render with Bearer ID token auth; zero credit-card dependencies |
| **Notifications** | Brevo transactional email on status change, scheduled appointment reminders |
| **Admin Tools** | Staff account management (create, deactivate, password reset), services CRUD, clinic hours & settings |
| **Audit** | Immutable `activity_logs` collection; real-time audit trail screen for admins |
| **CI/CD** | GitHub Actions: lint → test → build → automated deploy to Firebase Hosting on push to `main` |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter Web (3.x stable) |
| State Management | Riverpod |
| Routing | GoRouter |
| Backend Hosting | Render (Free Web Service) |
| API Framework | Express.js (Node.js 22 LTS, TypeScript) |
| Database & Auth | Cloud Firestore · Firebase Authentication |
| Web Hosting | Firebase Hosting (`dental-clinic-ams.web.app`) |
| Email | Brevo transactional API |
| Testing | Dart Analyzer · `flutter test` · Jest · `@firebase/rules-unit-testing` |
| CI/CD | GitHub Actions |

---

## 🎬 Live Demo & Presentation Guide

🌐 **Live Application:** [https://dental-clinic-ams.web.app](https://dental-clinic-ams.web.app)

> ⚡ **1-Click Quick Login:** The live login screen features built-in **"👑 Quick Login: Admin"** and **"👤 Quick Login: Patient"** buttons so reviewers and evaluators can explore full operational and administrative features with zero typing!

### Live Demo Accounts:
| Portal | Email | Password | Access Level |
|---|---|---|---|
| **Admin Portal** | `admin@clinic.test` | `password123` | Full Access (Analytics, Review Queue, Walk-In Desk, Settings, Services, Staff) |
| **Staff Portal** | `staff1@clinic.test` | `password123` | Operational Access (Review Queue, Walk-In Desk, Calendar) |
| **Patient Portal** | `patient1@clinic.test` | `password123` | Patient Self-Booking Experience (Wizard, Appointments, Profile) |

> 📖 **Full Presentation Guide:** See [`docs/USER-AND-DEMO-GUIDE.md`](./docs/USER-AND-DEMO-GUIDE.md) for a comprehensive 5-act presentation script and architecture walkthrough.

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

> ⚠️ Never commit `.env` or `functions/.env` files. Both are covered in `.gitignore` — double-check before pushing if you rename or move them.

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
firebase deploy --only hosting,firestore --project=dental-clinic-ams --force

# Blaze (pay-as-you-go) plan — deploys Hosting, Firestore, and Cloud Functions:
# firebase deploy --project=dental-clinic-ams --force
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
│   │   ├── auth/           # Login, signup, verification gate, password flows
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
| [`USER-AND-DEMO-GUIDE.md`](./docs/USER-AND-DEMO-GUIDE.md) | **Comprehensive User Manual & 5-Act Live Demo Presentation Script** |
| [`local-emulator-testing-guide.md`](./docs/local-emulator-testing-guide.md) | Complete step-by-step guide for local emulator setup, seeding, and testing |
| [`dental-clinic-appointment-system-plan.md`](./docs/dental-clinic-appointment-system-plan.md) | Full technical spec: data model, business logic, phased implementation |
| [`dev-process.md`](./docs/dev-process.md) | Phase-by-phase development history with implementation details |
| [`functions-api-contract.md`](./docs/functions-api-contract.md) | Input/output contract for every Cloud Function |
| [`app-workflow-transaction-flow.md`](./docs/app-workflow-transaction-flow.md) | User flows, booking transaction, status lifecycle, notification triggers |
| [`decisions-log.md`](./docs/decisions-log.md) | Open questions and their resolutions |
| [`CONTRIBUTING.md`](./CONTRIBUTING.md) | Branching strategy, testing requirements, pre-deploy checklist |

---

## Security & Data Privacy

This application stores patient personal and appointment data, so a few practices are worth calling out explicitly for anyone deploying or contributing:

- **Firestore rules are the source of truth** for access control — role checks live in `firestore.rules`, not just in client code. Run the rules test suite (`cd functions && npm test`) before deploying any rules change.
- **Secrets stay out of source control** — Firebase config and the Brevo API key are supplied via `.env` files (git-ignored) and GitHub Actions secrets, never hardcoded.
- **Audit trail is immutable** — the `activity_logs` collection is write-once from Cloud Functions, giving admins a tamper-evident record of status changes and account actions.

This is not a compliance certification (e.g. HIPAA) — if you're deploying this for a real clinic, review applicable local health-data regulations and your hosting provider's compliance offerings separately.

---

## Support

- **Bugs & feature requests:** open an issue in this repository.
- **Questions about setup:** check [`docs/local-emulator-testing-guide.md`](./docs/local-emulator-testing-guide.md) first — most local dev issues are covered there.
- **Contributing:** see [`CONTRIBUTING.md`](./CONTRIBUTING.md) for branching strategy and the pre-deploy checklist.

---

## License

MIT © 2026 Gene Conceja — see [`LICENSE`](./LICENSE)