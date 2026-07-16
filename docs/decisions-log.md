# Decisions Log — Dental Clinic Appointment System

Tracks open questions raised during planning and their resolutions as they're confirmed. Update this file — don't just resolve things in chat/Slack and let the answer get lost. Anything marked **Open** is currently blocking related work; check `functions-api-contract.md` and `firestore.rules` for inline references to these.

---

## How to use this file

When a question is resolved:
1. Change its status to **Resolved**
2. Fill in the decision, date, and who confirmed it
3. Update any file that referenced the open question (`firestore.rules` comments, `functions-api-contract.md` blocked functions, the main spec's Open Questions section)
4. Do not delete resolved entries — they're a record of why the system is built the way it is

---

## Open Questions

*(None. All decisions have been resolved.)*

---

## Resolved Questions

### 1. Slot-availability logic parity
**Status:** 🟢 Resolved
**Question:** Does the patient app compute available appointment slots the same way this app does (working hours minus holidays minus existing bookings, regardless of `bookingSource`)? If not, double-booking is possible even with this app's Firestore transaction, since the two apps wouldn't agree on what's "available."
**Blocks:** Finalizing confidence in the `createWalkInAppointment` transaction's real-world safety.
**Decision:** No, the patient app uses fixed discrete slot intervals and exact key matching while this app checks continuous overlaps. To resolve this and prevent double-booking, the staff app will snap walk-in `startTime` and `endTime` to the clinic's standard slot boundaries.
**Date:** 2026-07-15
**Confirmed by:** User

---

### 2. `reason` vs `serviceId`
**Status:** 🟢 Resolved
**Question:** Patient app currently writes `reason` as freeform text. Is there a near-term plan for the patient app to adopt `serviceId`, or should this app treat `reason` as permanent and only use `serviceId` for its own walk-in bookings?
**Blocks:** Whether reporting/analytics can rely on `serviceId` across all appointments, or only for walk-ins.
**Decision:** Treat `reason` as legacy text for backward compatibility with the patient app, which selects appointment types by name. For staff walk-ins, write both `serviceId`/`serviceName` and populate `reason` with the service's name.
**Date:** 2026-07-16
**Confirmed by:** User

---

### 3. `analysisResults` schema
**Status:** 🟢 Resolved
**Question:** Is the object detection model's output really a single `diseaseLabel` + `confidencePercentage`, or does it return multiple candidate labels each with their own percentage (a real "map")?
**Blocks:** Finalizing the `AnalysisResults` type in `schema-types.ts` and the staff UI for displaying results.
**Decision:** The patient app stores `analysisResults` as an array of object maps: `[{ tag: string, confidence: number }]`. Align the TypeScript/Dart schema types to expect this array format.
**Date:** 2026-07-16
**Confirmed by:** User

---

### 4. Does the patient app read `services` / `clinicSettings`?
**Status:** 🟢 Resolved
**Question:** Confirm whether the patient app already reads these collections (e.g. to show available slots or service options on its side). Determines whether this app is the sole writer/owner of those collections.
**Blocks:** Firestore rules confidence for `services` and `clinicSettings`.
**Decision:** No, the patient app only reads `booking_settings`. The staff app is the sole owner, reader, and writer of the `services` and `clinicSettings` collections.
**Date:** 2026-07-16
**Confirmed by:** User

---

### 5. Notification ownership
**Status:** 🟢 Resolved
**Question:** Who sends patient-facing notifications (booking confirmation, status-change, reminders) — this app, or does the patient app's backend already handle this? Building both risks duplicate emails/pushes to the same patient.
**Blocks:** `sendReminders` and `onAppointmentStatusChange` in `functions-api-contract.md` — both marked "do not implement" until this resolves.
**Decision:** The staff app's backend is the sole manager of appointment-related notifications and reminders (using cloud providers like Resend or Twilio). The patient app only has local, client-side alerts.
**Date:** 2026-07-16
**Confirmed by:** User

---

### 6. Can this app reuse the existing `analyzeImage` function?
**Status:** 🟢 Resolved
**Question:** For walk-in photos, can this app's Cloud Functions call/import the patient app's existing image-analysis logic, or does it need its own separate implementation?
**Blocks:** `analyzeWalkInImage` implementation pattern in `functions-api-contract.md`.
**Decision:** No, we do not need image analysis for walk-in appointments. The Cloud Function's imageUrl processing/image analysis hook will be removed or skipped entirely.
**Date:** 2026-07-16
**Confirmed by:** User

---

### 7. Patient app's create/cancel write pattern
**Status:** 🟢 Resolved
**Question:** Does the patient app create/cancel appointments via a direct Firestore client SDK write, or via its own Cloud Function (Admin SDK, bypassing security rules)? This directly determines the correct `allow create`/patient-side `allow update` rules in `firestore.rules`.
**Blocks:** Deploying `firestore.rules` with confidence — currently defaults to the more restrictive assumption (Cloud-Function-only) with the alternative rule commented out.
**Decision:** The patient app writes directly to Firestore via client SDK calls. Thus, `firestore.rules` must allow authenticated patients direct create and update (cancel) access for their own bookings.
**Date:** 2026-07-16
**Confirmed by:** User

---

### 8. Should the redundant `date` field be dropped?
**Status:** 🟢 Resolved
**Question:** `date` (string) is derivable from `appointmentDateTime` (timestamp) — is it kept for a genuine Firestore query-performance reason (e.g. simpler range queries), or is it just historical? If kept, it must always be server-derived, never independently client-settable.
**Blocks:** Nothing critical — this app will treat `date` as server-derived-only regardless, but worth confirming for the patient-app side too.
**Decision:** No, the string date field (YYYY-MM-DD) is kept because the patient app queries it directly for simpler equality matching, avoiding range queries.
**Date:** 2026-07-16
**Confirmed by:** User

---

### 9. Backfill of `bookingSource` on existing records
**Status:** 🟢 Resolved
**Question:** Should existing appointment documents get a one-time migration write of `bookingSource: "patient_app"`, or is the read-time fallback (`resolveBookingSource()` in `schema-types.ts`, defaulting missing field to `"patient_app"`) sufficient indefinitely?
**Blocks:** Whether a migration script is needed in Phase 2 of the implementation plan.
**Decision:** A one-time database migration script will be written to backfill `bookingSource: "patient_app"` to legacy appointments, making rule validation clean.
**Date:** 2026-07-16
**Confirmed by:** User

