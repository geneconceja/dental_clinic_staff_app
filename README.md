# Dental Clinic Appointment System — Staff/Admin App

Internal Flutter Web app used by clinic staff and admin to review patient-submitted appointment requests, book walk-in appointments, manage patient registration & email verification, and manage clinic services and settings.

> **This repo handles both Staff/Admin workflows and the Patient Web Portal.** It connects to the shared Firebase project (`oralscope-78cda`). See [`dental-clinic-appointment-system-plan.md`](./dental-clinic-appointment-system-plan.md) for the full architecture rationale.

---

## 🌐 Live Production Deployment

| Component | Status | Details |
| --- | --- | --- |
| **Live Web App** | 🟢 **Live** | [https://oralscope-78cda.web.app](https://oralscope-78cda.web.app) |
| **Cloud Functions (2nd Gen)** | 🟢 **Active** | Deployed in region **`asia-southeast1`** (Singapore — optimal for Philippines) |
| **Firestore Security Rules** | 🟢 **Active** | Production-hardened with patient self-registration and immutable audit logs |
| **Automated CI/CD** | 🟢 **Active** | GitHub Actions pipeline via [`.github/workflows/deploy.yml`](./.github/workflows/deploy.yml) |

---

## 🚀 Key Implemented Features

### 🔑 Auth & Access Control
- **Role-Based Routing**: Multi-role support (`admin`, `staff`, `patient`). Access control guarded centrally via Riverpod and `GoRouter`.
- **Patient Self-Registration**: Full patient signup form with password strength indicator, auto-syncing Firestore profiles, and `isVerified` protection.
- **Email Verification Gate**: Interactive verification gate for patients with 60-second resend cooldown and auto-verification detection.
- **Mobile-to-Web SSO Handoff**: Cloud Function powered single-use handoff tokens (`generateSsoToken` & `consumeSsoToken`) for authenticating patients from mobile apps.

### 📅 Appointment Management
- **Walk-In Desk Booking**: Concurrency-safe Cloud Function (`createWalkInAppointment`) preventing slot double-booking across patient and staff apps.
- **Appointment Status State Machine**: Enforces valid status transitions (`pending` ➔ `confirmed` | `cancelled`; `confirmed` ➔ `completed` | `cancelled` | `no-show`).
- **Brevo Email Integration**: Automatic email notifications triggered on status updates (`onAppointmentStatusChange`).

### ⚙️ Administration & Security
- **System Audit Logs**: Immutable system activity logging stored in Firestore `activity_logs`.
- **Services Admin**: CRUD management for clinic services, durations, and pricing.
- **Clinic Settings**: Operational hours, maximum daily slot capacity, working days, and closed holidays.

---

## 🤖 CI/CD Pipeline (GitHub Actions)

Continuous integration and continuous deployment are managed automatically via GitHub Actions:

- **Workflow File**: [`.github/workflows/deploy.yml`](./.github/workflows/deploy.yml)
- **Automated Quality Checks**: Runs `npm test` (functions), `dart analyze`, and `flutter test` on every PR or push.
- **Pull Request Preview Channel**: Deploys temporary preview channels (e.g. `pr-12--oralscope-78cda.web.app`) for incoming PRs.
- **Production Deployment**: Automatically compiles functions & Flutter web release (`ENV=prod`), then deploys to Firebase on push to `main`.

> [!NOTE]
> **Required GitHub Secret**: Set `FIREBASE_SERVICE_ACCOUNT_ORALSCOPE_78CDA` under **Repository Settings ➔ Secrets and variables ➔ Actions** with a valid GCP Service Account JSON key to enable automated deployments.

---

## 📑 Documentation Map

| Document | What it's for |
|---|---|
| [`dental-clinic-appointment-system-plan.md`](./dental-clinic-appointment-system-plan.md) | Full technical spec: data model, business logic, phased implementation plan |
| [`CONTRIBUTING.md`](./CONTRIBUTING.md) | Branching strategy, testing requirements, CI/CD, pre-deploy checklist |
| [`GETTING-STARTED.md`](./GETTING-STARTED.md) | Step-by-step build order from empty repo to first working feature |
| [`app-workflow-transaction-flow.md`](./app-workflow-transaction-flow.md) | Diagrams: user flows, booking transaction, status lifecycle, notification triggers |
| [`firestore.rules`](./firestore.rules) | Security rules governing users, appointments, services, settings, activity logs, and sso tokens |
| [`functions-api-contract.md`](./functions-api-contract.md) | Exact input/output contract for every Cloud Function |
| [`schema-types.ts`](./schema-types.ts) | Source-of-truth TypeScript types for all Firestore documents |
| [`decisions-log.md`](./decisions-log.md) | Tracks open questions and their resolutions as confirmed |

---

## Tech Stack

- **Frontend**: Flutter Web, Riverpod (State Management), GoRouter
- **Backend / BaaS**: Firebase (Authentication, Cloud Firestore, 2nd Gen Cloud Functions, Hosting)
- **Regions**: Cloud Functions deployed to `asia-southeast1` (Singapore)
- **Testing & Tooling**: Dart Analyzer, Jest, `@firebase/rules-unit-testing`, TypeScript
- **Email Service**: Brevo API integration

---

## Prerequisites

- Flutter SDK (stable channel) installed and on `PATH`
- Node.js (v22 LTS recommended)
- Firebase CLI: `npm install -g firebase-tools`
- Access to Firebase project **`oralscope-78cda`**

---

## Local Development Workflow

### 1. Clone & Install
```bash
git clone <repo-url>
cd dental_clinic_staff_app
flutter pub get
cd functions && npm install && cd ..
```

### 2. Run Firebase Emulators
```bash
firebase emulators:start --project=oralscope-78cda
```
Or with persisted state:
```bash
firebase emulators:start --project=oralscope-78cda --import=./emulator-data --export-on-exit
```

### 3. Run Flutter App (Dev Mode)
```bash
flutter run -d chrome --dart-define=ENV=dev
```

### 4. Run Unit Tests & Analysis
```bash
# Cloud Functions & Firestore Rules Tests
cd functions && npm test

# Flutter Static Analysis & Unit Tests
dart analyze
flutter test
```

---

## Manual Production Deployment

To deploy manually from your terminal:

```bash
# 1. Compile Cloud Functions
cd functions
npm run build
cd ..

# 2. Build Flutter Web Release
flutter build web --release --dart-define=ENV=prod

# 3. Deploy all services to Firebase (asia-southeast1)
firebase deploy --project=oralscope-78cda --force
```

---

## Setup & Health Checklist

- [x] `flutter run -d chrome --dart-define=ENV=dev` launches cleanly
- [x] `firebase emulators:start --project=oralscope-78cda` runs Auth, Firestore, Functions
- [x] `cd functions && npm test` passes all 70 unit and security rule tests
- [x] `dart analyze` passes with 0 issues
- [x] `flutter build web --release --dart-define=ENV=prod` builds release bundle cleanly
- [x] Live app deployed to [https://oralscope-78cda.web.app](https://oralscope-78cda.web.app)