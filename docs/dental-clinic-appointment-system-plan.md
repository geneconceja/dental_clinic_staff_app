# Dental Clinic Appointment System — Staff/Admin App Specification (v4)

> This document is a complete technical specification intended to be handed to an AI coding assistant (or a developer) to build the system. It includes context, architecture, data models, business logic, and phased implementation instructions.
>
> **Revision note (v4):** This project is now scoped as a **standalone staff/admin Flutter Web app**. Patients use a **separate, already-built and live app on a different platform** to register and submit appointment requests. Both apps share the same Firebase project. This app **consumes the existing Firestore schema** rather than designing it — the patient app owns that schema going forward. This version also adds support for **staff-booked walk-in appointments**, which the original schema didn't account for.

---

## 1. Project Overview

Build a **staff/admin-only** Flutter Web app for a single-dentist clinic that:
- Reviews and manages appointment requests submitted by patients through the separate, existing patient app
- Allows staff to book **walk-in appointments** directly (patients without a patient-app account)
- Manages services, clinic settings, and staff accounts

**This app does not include any patient-facing registration, login, or self-booking UI** — that already exists in the separate patient app and is out of scope here.

**Tech Stack:**
- **Frontend:** Flutter Web (staff/admin only — no patient-facing routes)
- **Backend:** Firebase (Authentication, Cloud Firestore, Cloud Functions, Firebase Hosting, Firebase Cloud Messaging) — **shared project with the existing patient app**
- **State Management:** Riverpod
- **Image storage:** Cloudinary (existing patient-app integration; this app displays but doesn't own the upload flow for patient-submitted photos — see Section 4.6)

**Scope constraints (confirmed):**
- Single dentist / single clinic
- Patient registration/booking happens entirely in the separate patient app — not built here
- **Firestore schema is owned by the patient app.** This app must not rename, remove, or repurpose existing fields. New fields this app needs must be **additive only** (see `bookingSource`, Section 3).
- Staff can book walk-in appointments directly from this app
- `reason` (freeform, legacy) is being replaced with `serviceId` going forward — coordinate this change with the patient app, since it currently writes `reason` as text (flagged as an open question, Section 8)
- No online payment integration — payment handled in person; `paid` flag tracked manually by staff

---

## 2. User Roles

| Role | Capabilities |
|---|---|
| **Staff** | Login, review/confirm/decline patient-submitted requests, book walk-in appointments, manage the day's schedule, manage services |
| **Admin** | All staff capabilities + manage staff accounts, clinic settings |

> Patients are **not** a role in this app. They exist only as data on `appointments` documents (via `userId`/`userEmail` for patient-app bookings, or inline contact fields for walk-ins) — they never authenticate into this app.

---

## 3. Data Model (Cloud Firestore — shared with the patient app)

### Collection: `users/{uid}`
(Staff/admin accounts only, created internally — **not** the same collection space as patient-app end users, who are Firebase Auth users but may not have a corresponding doc here unless the patient app writes one)
```json
{
  "uid": "string (Firebase Auth uid)",
  "role": "staff | admin",
  "name": "string",
  "email": "string",
  "phone": "string",
  "active": "boolean",
  "createdAt": "timestamp"
}
```

### Collection: `services/{serviceId}`
```json
{
  "id": "string",
  "name": "string",
  "durationMinutes": "number",
  "price": "number",
  "description": "string",
  "active": "boolean"
}
```
> Confirm with the patient-app owner whether they also read from this collection when patients pick a "reason" for booking — if `reason` is still freeform text on their side, this collection may currently only be used by staff-side reporting, not enforced end-to-end. See Open Questions.

### Collection: `appointments/{appointmentId}` — **existing schema, patient-app-owned**
Fields as currently written by the live patient app (do not rename or remove):
```json
{
  "id": "string",
  "userId": "string | null (Firebase Auth uid — present for patient-app bookings, null for walk-ins)",
  "userEmail": "string | null (present for patient-app bookings, null for walk-ins)",
  "firstName": "string",
  "lastName": "string",
  "phoneNumber": "string",
  "reason": "string (freeform — legacy field, still written by patient app)",
  "date": "string (YYYY-MM-DD)",
  "appointmentDateTime": "timestamp",
  "startTime": "string (HH:mm)",
  "endTime": "string (HH:mm)",
  "notes": "string | null",
  "imageUrl": "string | null (Cloudinary URL)",
  "analysisResults": "object | null ({ diseaseLabel, confidencePercentage } — schema to confirm, see Open Questions)",
  "status": "pending | confirmed | cancelled | completed | no-show",
  "createdAt": "timestamp"
}
```

### New fields this app adds (additive only — Option C)
```json
{
  "bookingSource": "patient_app | staff_walkin",
  "createdBy": "string | null (staff uid, present only when bookingSource == staff_walkin)",
  "paid": "boolean (default false, staff-managed, not currently written by patient app)",
  "reminderSent": "boolean (default false)"
}
```
- `bookingSource` lets the UI and any reporting distinguish patient-submitted vs. staff-booked appointments without touching any existing field.
- For **existing records** written before this field existed, treat a missing/undefined `bookingSource` as `patient_app` by default when reading (since all current live data came from the patient app).
- `userId`/`userEmail` remain `null` for walk-ins — this app must **never fabricate** a Firebase Auth user for a walk-in patient (ruled out — see the discarded Option B from planning).

### Document: `clinicSettings/main` (singleton)
```json
{
  "workingHours": { "monday": { "open": "09:00", "close": "17:00", "isOpen": true }, "...": "..." },
  "holidays": ["YYYY-MM-DD"],
  "slotDurationMinutes": 30,
  "reminderHoursBefore": 24,
  "clinicName": "string",
  "clinicPhone": "string",
  "clinicAddress": "string"
}
```
> Confirm whether `clinicSettings` already exists and is read by the patient app (e.g. to show available slots there) — if so, this is also a shared, not staff-owned, document. Flagged in Open Questions.

---

## 4. Core Business Logic

### 4.1 Slot Generation
Same logic regardless of booking source: derive candidate slots from `clinicSettings.workingHours`, minus `holidays`, minus existing `appointments` where `status in [pending, confirmed]` on that date. This must be shared logic (or at least identical logic) between the patient app and this app's walk-in booking — **if the two apps compute availability differently, double-booking becomes possible even with transactions**, since each would only check against its own view of "available." This is the most important coordination point with the patient-app team. See Open Questions.

### 4.2 Walk-In Booking (staff-initiated, new)
1. Staff client calls a callable Cloud Function `createWalkInAppointment(firstName, lastName, phoneNumber, serviceId, appointmentDateTime, notes, createdBy)`.
2. Function computes `endTime` from the service's `durationMinutes`.
3. Function re-validates slot availability **inside a Firestore transaction** — same transactional protection as patient-app bookings, checking the same `appointments` collection.
4. If valid: create the document with `userId: null`, `userEmail: null`, `bookingSource: "staff_walkin"`, `createdBy: <staff uid>`, `status: "confirmed"` (walk-ins booked by staff don't need the pending-review step, since staff is both the requester and approver).
5. No Cloudinary/image analysis step for walk-ins by default — but staff should be able to optionally attach a photo too (Section 4.6).

### 4.3 Reviewing Patient-App Requests (existing flow, staff side)
1. Staff views the review queue: `appointments` where `status == "pending"` (regardless of `bookingSource` — a pending walk-in shouldn't normally occur under 4.2's logic, but the query doesn't need to exclude it).
2. Staff confirms or declines. This app writes `status` only — it does not touch `userId`/`userEmail`/`reason`/etc., since those are patient-app-owned fields.

### 4.4 Status Transitions
```
pending → confirmed    (staff action; patient-app-originated requests only, typically)
pending → cancelled    (staff action)
confirmed → cancelled  (staff action)
confirmed → completed  (staff action, after appointment date)
confirmed → no-show    (staff action)
```
This app only ever writes `status` as staff — there's no patient actor in this codebase. (The patient app may independently allow patients to cancel their own `pending`/`confirmed` requests — confirm this doesn't conflict with staff actions happening at the same time. Open Question.)

### 4.5 Notifications
- **To patients** (only for patient-app-originated bookings, since walk-ins may have no `userEmail`/push channel): status-change and reminder notifications — confirm whether this app or the patient app's backend already owns sending these (avoid duplicate sends from two codebases). Open Question.
- **To staff**: internal notification on new pending request, if useful for multi-staff coordination.

### 4.6 Image Analysis (existing pipeline, patient-app-triggered; staff app is a consumer + optional secondary trigger)
- For patient-app bookings: `imageUrl` and `analysisResults` are expected to already be populated (or populated asynchronously) by the existing pipeline — **this app does not re-trigger analysis for patient-app records.**
- For staff walk-ins: if staff attaches a photo, this app needs its **own** path to (a) upload to Cloudinary and (b) call the analysis Cloud Function, reusing the same `analyzeImage` logic if it's shared/exported in a way this app's Cloud Functions can call, or duplicating it if the existing function lives in a codebase this app can't import from. Confirm which — Open Question.
- Displayed only in the staff review/detail view, same as before — not patient-facing (no change from v3).

---

## 5. Firestore Security Rules (draft logic to implement)

```
- users/{uid}:
    read/write: staff/admin only (this collection is not shared with the patient app's user records)

- services/{id}:
    read: staff/admin (and possibly the patient app, if it reads this collection — confirm)
    write: admin only

- clinicSettings/main:
    read: staff/admin (and possibly the patient app — confirm)
    write: admin only

- appointments/{id}:
    read: staff/admin (full collection — this app needs to see all appointments regardless of source)
    create:
        - DISALLOWED directly by this app's client — walk-ins go through createWalkInAppointment
        - Patient-app-originated creates are governed by the patient app's own rules, not this spec
    update:
        - staff/admin only, restricted to valid status transitions + paid/notes/bookingSource-adjacent fields
        - this app must NOT have write access that could let it accidentally modify userId/userEmail/reason/firstName/etc. on a patient-app-originated record — consider field-level rule restrictions if Firestore rules support it for your needs, or enforce this via Cloud Function validation instead of raw client writes
```

**Important coordination point:** since both apps write to the same `appointments` collection, security rules must be written with awareness of *both* client codebases' expected write patterns. This spec's rules only cover this app's side — get the patient app's actual current rules before finalizing, to avoid either app being unexpectedly blocked or overly permissive.

---

## 6. Screens / UI Requirements (staff/admin only)

1. **Login** — staff/admin accounts only
2. **Dashboard / Calendar view** — day/week view of all appointments, filter by status and by `bookingSource`
3. **Review Queue** — pending patient-app requests, with photo + analysis results if present, confirm/decline actions
4. **New Walk-In Appointment** — manual entry form (name, phone, service, date/slot, notes, optional photo)
5. **Appointment Detail** — complete/cancel/no-show/paid toggle/notes, for any appointment regardless of source
6. **Services management** (CRUD)
7. **Clinic settings**
8. **(Admin only) Staff account management**

---

## 7. Implementation Phases

### Phase 1 — Setup & Staff Auth (≈2-3 days)
- Firebase project connection (existing, shared project — not a new one)
- Staff/admin login, route guarding
- Confirm read access to existing `appointments`/`services`/`clinicSettings` collections against real (or staging) data

### Phase 2 — Schema Reconciliation & Walk-In Booking Engine (≈4-5 days)
- Confirm exact current schema against live data (re-verify against the patient app team, not just the screenshots reviewed earlier)
- Add `bookingSource`, `createdBy`, `paid`, `reminderSent` fields (additive migration — existing docs get a default `bookingSource: "patient_app"` treatment on read, not necessarily a backfill write unless agreed with the patient-app team)
- `createWalkInAppointment` Cloud Function with transactional slot validation
- Firestore security rules

### Phase 3 — Review Queue & Staff Dashboard (≈4-5 days)
- Review queue UI (pending requests, confirm/decline)
- Calendar/list view, appointment detail actions
- New Walk-In Appointment form

### Phase 4 — Admin Tools (≈3 days)
- Services CRUD, clinic settings, staff management

### Phase 5 — Image Handling for Walk-Ins (≈2-3 days)
- Cloudinary upload path for staff-attached photos
- Reuse or duplicate the analysis Cloud Function (depends on Open Question resolution)

### Phase 6 — Notifications (≈2-3 days, scope depends on Open Question about ownership)
- Reminder scheduling, staff-side notifications
- Coordinate with patient app to avoid duplicate patient-facing sends

### Phase 7 — Polish & Deploy (≈2-3 days)
- QA against both booking sources, responsive pass, deploy

**Estimated total: ~19-24 working days**, contingent on how much Phase 2's schema reconciliation and Phase 5/6's cross-app coordination actually take — these are the two phases most likely to run long if the patient-app side isn't easy to coordinate with.

---

## 8. Open Questions to Resolve Before/During Development
- **Slot-availability logic parity**: does the patient app compute available slots the same way this spec assumes (working hours minus holidays minus existing bookings)? If not, double-booking is possible even with this app's transaction, since the two apps wouldn't agree on what's "available." This is the highest-priority question.
- **`reason` vs `serviceId`**: patient app currently writes `reason` as freeform text. Is there any near-term plan for the patient app to switch to `serviceId`, or should this app treat `reason` as permanent and build its own service-linking only for walk-ins?
- **`analysisResults` schema**: confirm the real shape (single label+percentage, or multiple candidates) directly against the existing pipeline's actual output, not just the earlier description.
- **Does the patient app already read `services`/`clinicSettings`?** Determines whether this app can safely be the sole writer of those, or needs to coordinate changes.
- **Who owns notification sending** (reminders, status-change emails/push) — this app, the patient app's backend, or a Cloud Function that's already shared? Avoid two systems both trying to notify the same patient.
- **Can this app's Cloud Functions call/reuse the existing `analyzeImage` logic**, or does it need its own copy for walk-in photos?
- **Backfill**: should existing appointment documents get a one-time `bookingSource: "patient_app"` write, or is treating a missing field as the default (read-time fallback) sufficient? Affects whether a migration script is needed in Phase 2.

---

## 9. Suggested Folder Structure (Flutter)
```
lib/
  core/
    theme/
    utils/
    widgets/
  features/
    auth/
    review_queue/
    walk_in_booking/
    dashboard/
    services_admin/
    settings/
    staff_management/
  routing/
    app_router.dart
  main.dart
functions/
  src/
    createWalkInAppointment.ts
    cancelAppointment.ts
    onAppointmentStatusChange.ts
    sendReminders.ts (scheduled — pending ownership confirmation)
    index.ts
firestore.rules
firestore.indexes.json
```

---

## 10. Instructions for the AI Development Assistant
1. This app is **staff/admin only** — do not build any patient-facing login, registration, or self-booking screens. That already exists elsewhere.
2. Treat the `appointments` schema as **externally owned** — never rename or remove existing fields (`userId`, `userEmail`, `firstName`, `lastName`, `phoneNumber`, `reason`, `date`, `appointmentDateTime`, `startTime`, `endTime`, `notes`, `imageUrl`, `analysisResults`, `status`, `createdAt`). Only add new fields additively (`bookingSource`, `createdBy`, `paid`, `reminderSent`).
3. Walk-in appointments get `userId: null`, `userEmail: null`, `bookingSource: "staff_walkin"` — never fabricate a Firebase Auth user for a walk-in.
4. Slot-booking (both walk-in and any staff-side edits) must go through Cloud Functions with a transaction — never a direct client write to `appointments`.
5. Resolve the Open Questions in Section 8 — especially slot-availability parity with the patient app — before finalizing Phase 2, since getting this wrong risks real double-bookings in production.
6. Do not assume ownership of notification-sending or the image analysis function without confirming with whoever maintains the patient app's backend.
