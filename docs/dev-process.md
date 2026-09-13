# Development Process — Dental Clinic Staff App

> **Purpose:** This file is the single source of truth for the ordered development sequence of the Dental Clinic Staff/Admin Flutter Web App. It is a living document — update status and notes as milestones are completed.
>
> **Stack:** Flutter Web · Firebase Auth · Cloud Firestore · Cloud Functions (TypeScript) · Riverpod · go_router
>
> **Key references:**
> - Architecture: [dental-clinic-appointment-system-plan.md](./dental-clinic-appointment-system-plan.md)
> - Functions: [functions-api-contract.md](./functions-api-contract.md)
> - Decisions: [decisions-log.md](./decisions-log.md)

---

## Progress Legend

| Symbol | Meaning |
|---|---|
| ✅ | Completed & verified |
| 🔄 | In progress |
| ⏳ | Ready to start |
| 🔒 | Blocked — dependency must resolve first |

---

## Phase 1 — Backend Foundation ✅

> Goal: Build and test the core write-path Cloud Function with full transaction safety, security rules, and schema alignment.

### Step 1.1 — Schema & Types ✅
- Defined [schema-types.ts](../functions/src/schema-types.ts) as the single TypeScript source of truth for all Firestore document shapes.
- Typed all collections: `StaffUser`, `Service`, `ClinicSettings`, `Appointment`.
- Added additive fields (`bookingSource`, `createdBy`, `paid`, `reminderSent`).
- Corrected `AnalysisResults` to match patient app's actual array format: `AnalysisTag[]`.

### Step 1.2 — `createWalkInAppointment` Cloud Function ✅
- Implemented [createWalkInAppointment.ts](../functions/src/createWalkInAppointment.ts) with:
  - **Auth guard** — caller must have `users/{uid}` with `role in ['staff', 'admin']`.
  - **Input validation** — all required fields, ISO 8601 date parsing.
  - **Service lookup** — verifies service exists and is active.
  - **Slot snapping** — reads `clinicSettings/main.slotDurationMinutes` (default 30) and snaps `appointmentDateTime` to the nearest slot boundary to align with the patient app's discrete slot grid.
  - **Firestore transaction** — slot-conflict check + document write are atomic.
  - Walk-in document layout: `userId/userEmail` null, `bookingSource: "staff_walkin"`, `reason` set to service name for backward compatibility.
- Exported via [index.ts](../functions/src/index.ts).
- Verified: **46/46 Jest tests pass** (including 3 concurrency double-booking prevention tests and 6 slot-snapping unit tests).

### Step 1.3 — Firestore Security Rules ✅
- Implemented [firestore.rules](../firestore.rules) covering all collections.
- Patient-side direct SDK creates enabled (decision resolved 2026-07-16).
- Staff field restrictions: status updates may only touch `status`, `paid`, `notes`, `reminderSent`, `updatedAt`.
- Verified against live emulator with rules unit tests.

### Step 1.4 — Legacy Data Migration ✅
- Created [backfill-booking-source.js](../scripts/backfill-booking-source.js).
- Backfills `bookingSource: "patient_app"` on legacy documents missing the field.
- Dry-run mode available. Verified against emulator seed data.

---

## Phase 2 — Flutter App Foundation ✅

> Goal: Set up the Flutter Web app shell with Firebase connection, Riverpod, routing, theme, and a working login screen.

### Step 2.1 — App Initialization & Firebase Connection ✅
**Files created:**
- `lib/main.dart` — Firebase initialized, Riverpod `ProviderScope`, go_router hooked up.
- `lib/firebase_options.dart` — keys loaded from `.env`; no hardcoded secrets committed.
- `lib/core/utils/firebase_emulator.dart` — conditionally points SDK to local emulators when `ENV=dev`.

**Acceptance criteria met:**
- `flutter run -d chrome --dart-define=ENV=dev` launches without error.
- Firebase Auth and Firestore connect to the local emulator in dev mode.

### Step 2.2 — App Theme & Design System ✅
**Files created:**
- `lib/core/theme/app_theme.dart` — MaterialTheme with clinic color palette, typography, spacing tokens.
- `lib/core/theme/app_colors.dart` — named color constants.

### Step 2.3 — Routing ✅
**Files created:**
- `lib/routing/app_router.dart` — `GoRouter` instance with all named routes, auth guards, and role-based redirect logic.

**Routes implemented:**
```
/login               → LoginScreen
/signup              → PatientSignUpScreen
/email-verification  → EmailVerificationGateScreen
/sso                 → SsoExchangeScreen
/dashboard           → DashboardScreen
/review-queue        → ReviewQueueScreen
/walk-in/new         → WalkInBookingScreen
/appointment/:id     → AppointmentDetailScreen
/calendar            → CalendarScreen
/services            → ServicesScreen (admin)
/settings            → SettingsScreen (admin)
/staff               → StaffScreen (admin)
/activity-logs       → ActivityLogsScreen (admin)
/patient/dashboard   → PatientDashboardScreen
/patient/book        → PatientBookingWizardScreen
/patient/appointments → PatientAppointmentsScreen
/patient/profile     → PatientProfileScreen
/403                 → ForbiddenScreen
```

### Step 2.4 — Auth Feature ✅
**Files created:**
- `lib/features/auth/auth_repository.dart` — wraps `FirebaseAuth` sign-in, sign-out, sign-up, and verify flows.
- `lib/features/auth/auth_providers.dart` — Riverpod providers for `authStateChanges`, `staffProfileProvider`.
- `lib/features/auth/login_screen.dart` — email + password login with inline error handling.
- `lib/features/auth/patient_signup_screen.dart` — self-registration with password strength indicator.
- `lib/features/auth/email_verification_gate_screen.dart` — 60s resend cooldown, auto-detection.
- `lib/features/auth/change_password_dialog.dart` — in-app password change for staff.
- `lib/features/auth/forgot_password_dialog.dart` — password reset email flow.

---

## Phase 3 — Core Data Layer ✅

> Goal: Build Riverpod providers and repository classes that stream real Firestore data.

### Step 3.1 — Dart Models ✅
**Files created:**
- `lib/core/models/appointment.dart` — mirrors the TypeScript `Appointment` interface; includes `resolveBookingSource()` fallback.
- `lib/core/models/service.dart` — mirrors `Service`.
- `lib/core/models/staff_user.dart` — mirrors `StaffUser`.
- `lib/core/models/clinic_settings.dart` — mirrors `ClinicSettings`.
- `lib/core/models/activity_log.dart` — mirrors `ActivityLog`.

### Step 3.2 — Firestore Repositories ✅
**Files created:**
- `lib/features/review_queue/appointments_repository.dart`
- `lib/features/services_admin/services_repository.dart`
- `lib/features/settings/clinic_settings_repository.dart`
- `lib/features/staff_management/staff_repository.dart`
- `lib/features/patient_portal/patient_repository.dart`

### Step 3.3 — Cloud Function Callers ✅
**Files created:**
- `lib/core/utils/functions_client.dart` — wrapper pointing to emulator in dev mode.
- `lib/features/walk_in_booking/walk_in_functions.dart` — typed wrapper for `createWalkInAppointment`.
- `lib/features/review_queue/status_functions.dart` — typed wrapper for `updateAppointmentStatus`.
- `lib/features/staff_management/staff_functions.dart` — typed wrapper for `createStaffUser` and `adminResetPassword`.

---

## Phase 4 — Review Queue UI ✅

> Goal: Build the primary staff workflow — viewing, confirming, and declining patient-submitted appointment requests.

### Step 4.1 — `updateAppointmentStatus` Cloud Function ✅
**File:** `functions/src/updateAppointmentStatus.ts`
- Auth guard (staff/admin only).
- Validates transition matrix: `pending → confirmed/cancelled`, `confirmed → cancelled/completed/no-show`.
- Triggers Brevo email notification via `onAppointmentStatusChange` Firestore trigger.
- Tested: Jest test suite in `functions/test/updateAppointmentStatus.test.ts`.

### Step 4.2 — Review Queue Screen ✅
**Files created:**
- `lib/features/review_queue/review_queue_screen.dart` — list of `status == "pending"` appointments with confirm/decline actions.
- `lib/features/review_queue/appointment_card.dart` — card widget showing patient name, time, service.

### Step 4.3 — Appointment Detail Screen ✅
**Files created:**
- `lib/features/review_queue/appointment_detail_screen.dart` — full appointment details with action buttons (`Confirm`, `Cancel`, `Complete`, `No-Show`, `Mark Paid`).

---

## Phase 5 — Walk-In Booking UI ✅

> Goal: Allow staff to book walk-in appointments via `createWalkInAppointment`.

### Step 5.1 — Walk-In Form Screen ✅
**Files created:**
- `lib/features/walk_in_booking/walk_in_booking_screen.dart` — form with fields: first name, last name, phone, service dropdown, date+time picker, notes.
- `lib/features/walk_in_booking/walk_in_functions.dart` — typed Cloud Function caller.
- Time picker shows only slot-boundary times (e.g., 09:00, 09:30, 10:00).

---

## Phase 6 — Dashboard & Calendar ✅

> Goal: Bird's-eye view of the day's and week's appointments.

### Step 6.1 — Dashboard Screen ✅
**Files created:**
- `lib/features/dashboard/dashboard_screen.dart` — appointment timeline with date/range filter (today, this week, this month, custom), status filter, KPI cards.
- `lib/features/dashboard/dashboard_appointment_tile.dart` — appointment tile widget.
- `lib/features/calendar/calendar_screen.dart` — interactive week-view calendar grid.
- `lib/features/calendar/calendar_day_panel.dart` — day panel sub-widget.
- `lib/core/utils/slot_generator.dart` — utility to compute available slots from clinic settings.

---

## Phase 7 — Admin Tools ✅

> Goal: Admin-only screens for managing services, clinic settings, staff accounts, and SSO.

### Step 7.1 — Services Management ✅
**Files created:**
- `lib/features/services_admin/services_screen.dart` — list all services, add/edit/deactivate via inline dialog.
- `lib/features/services_admin/services_repository.dart` — Firestore CRUD.

### Step 7.2 — Clinic Settings ✅
**Files created:**
- `lib/features/settings/settings_screen.dart` — edit working hours per day, slot duration, reminder config, holidays, clinic contact info.

### Step 7.3 — Staff Account Management ✅
**Files created:**
- `lib/features/staff_management/staff_screen.dart` — list staff, add new (via `createStaffUser`), deactivate.
- `lib/features/staff_management/add_staff_dialog.dart` — new staff creation form.
- `lib/features/staff_management/admin_reset_password_dialog.dart` — admin password reset dialog.

### Step 7.4 — Mobile-to-Web SSO (Deprecated & Removed)
- Formerly implemented single-use handoff token engine (`generateSsoToken.ts` / `consumeSsoToken.ts` and `sso_exchange_screen.dart`).
- Cleanly removed after companion mobile app was cancelled.

---

## Phase 8 — Notifications ✅

> Goal: Appointment reminder and status-change notifications via Brevo email.

### Step 8.1 — `sendReminders` Scheduled Function ✅
**File:** `functions/src/sendReminders.ts`
- Runs on a Cloud Scheduler cron.
- Queries `appointments` where `status == "confirmed"`, `reminderSent == false`, within `clinicSettings.reminderHoursBefore` of now.
- Sends via Brevo; sets `reminderSent = true` on success.
- Skips walk-ins with `userEmail == null`.

### Step 8.2 — `onAppointmentStatusChange` Firestore Trigger ✅
**File:** `functions/src/onAppointmentStatusChange.ts`
- Triggered on Firestore `onUpdate` of `appointments/{id}`.
- On `confirmed`: sends booking confirmation email.
- On `cancelled`: sends cancellation notice.
- Skips walk-ins (`bookingSource == "staff_walkin"` or `userEmail == null`).

### Step 8.3 — System Audit Logs ✅
**Files created:**
- `lib/core/services/activity_logger_service.dart` — writes immutable logs to `activity_logs/{id}`.
- `lib/features/activity_logs/activity_logs_screen.dart` — real-time audit trail dashboard.

---

## Phase 9 — Polish & Deployment ✅

### Step 9.1 — Responsive Layout ✅
- All screens are usable on desktop browser widths (min 1024px).
- Sidebar navigation for wide screens.

### Step 9.2 — Error Handling & Loading States ✅
- All async Riverpod providers handle `loading`, `data`, and `error` states.
- No unhandled exceptions reach the UI.

### Step 9.3 — Patient Web Portal ✅
- Self-registration with email verification gate.
- Multi-step booking wizard with slot availability logic.
- My appointments view with cancel/reschedule.
- Patient profile management.

### Step 9.4 — Production Firestore Rules Review ✅
- [firestore.rules](../firestore.rules) production-hardened.
- Patient self-create and cancel rules confirmed against live write patterns.
- Immutable `activity_logs` enforced at rules level.

### Step 9.5 — Firebase Hosting & CI/CD ✅
- GitHub Actions pipeline: lint → test → build → deploy.
- PR preview channels deployed automatically.
- Push to `main` triggers production deployment.
- Live at: https://oralscope-78cda.web.app

---

## Deferred / Out of Scope

| Item | Reason |
|---|---|
| `analyzeWalkInImage` | Image analysis not needed for walk-ins (decision #6 resolved). Deferred indefinitely. |
| Patient-facing UI | Fully owned by the separate patient app — not built here. |
| Online payment integration | Out of scope. `paid` flag is managed manually by staff. |
| iOS/Android builds | Staff app is web-only. |

---

## Dev Workflow Rules

1. **Emulator-first**: All development and testing runs against the local Firebase emulator. Never test against production Firestore.
2. **Backend before UI**: Implement and test each Cloud Function before building the UI that depends on it.
3. **Test every function**: Every Cloud Function must have a Jest test file in `functions/test/`. No exceptions.
4. **Schema parity**: Any change to [schema-types.ts](../functions/src/schema-types.ts) must be mirrored manually in the corresponding Dart model in `lib/core/models/`.
5. **Rules with every feature**: When a new write pattern is introduced (new collection, new field update), update `firestore.rules` and add a rules test in `firestore.rules.test.ts` in the same step.
6. **Commit discipline**: Each completed step above should map to one logical git commit. Use the step number as the commit prefix, e.g. `feat(2.4): implement staff login screen`.
