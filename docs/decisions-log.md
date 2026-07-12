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

### 1. Slot-availability logic parity
**Status:** 🔴 Open — highest priority
**Question:** Does the patient app compute available appointment slots the same way this app does (working hours minus holidays minus existing bookings, regardless of `bookingSource`)? If not, double-booking is possible even with this app's Firestore transaction, since the two apps wouldn't agree on what's "available."
**Blocks:** Finalizing confidence in the `createWalkInAppointment` transaction's real-world safety.
**Decision:**
**Date:**
**Confirmed by:**

---

### 2. `reason` vs `serviceId`
**Status:** 🔴 Open
**Question:** Patient app currently writes `reason` as freeform text. Is there a near-term plan for the patient app to adopt `serviceId`, or should this app treat `reason` as permanent and only use `serviceId` for its own walk-in bookings?
**Blocks:** Whether reporting/analytics can rely on `serviceId` across all appointments, or only for walk-ins.
**Decision:**
**Date:**
**Confirmed by:**

---

### 3. `analysisResults` schema
**Status:** 🔴 Open
**Question:** Is the object detection model's output really a single `diseaseLabel` + `confidencePercentage`, or does it return multiple candidate labels each with their own percentage (a real "map")?
**Blocks:** Finalizing the `AnalysisResults` type in `schema-types.ts` and the staff UI for displaying results.
**Decision:**
**Date:**
**Confirmed by:**

---

### 4. Does the patient app read `services` / `clinicSettings`?
**Status:** 🔴 Open
**Question:** Confirm whether the patient app already reads these collections (e.g. to show available slots or service options on its side). Determines whether this app is the sole writer/owner of those collections.
**Blocks:** Firestore rules confidence for `services` and `clinicSettings`.
**Decision:**
**Date:**
**Confirmed by:**

---

### 5. Notification ownership
**Status:** 🔴 Open
**Question:** Who sends patient-facing notifications (booking confirmation, status-change, reminders) — this app, or does the patient app's backend already handle this? Building both risks duplicate emails/pushes to the same patient.
**Blocks:** `sendReminders` and `onAppointmentStatusChange` in `functions-api-contract.md` — both marked "do not implement" until this resolves.
**Decision:**
**Date:**
**Confirmed by:**

---

### 6. Can this app reuse the existing `analyzeImage` function?
**Status:** 🔴 Open
**Question:** For walk-in photos, can this app's Cloud Functions call/import the patient app's existing image-analysis logic, or does it need its own separate implementation?
**Blocks:** `analyzeWalkInImage` implementation pattern in `functions-api-contract.md`.
**Decision:**
**Date:**
**Confirmed by:**

---

### 7. Patient app's create/cancel write pattern
**Status:** 🔴 Open
**Question:** Does the patient app create/cancel appointments via a direct Firestore client SDK write, or via its own Cloud Function (Admin SDK, bypassing security rules)? This directly determines the correct `allow create`/patient-side `allow update` rules in `firestore.rules`.
**Blocks:** Deploying `firestore.rules` with confidence — currently defaults to the more restrictive assumption (Cloud-Function-only) with the alternative rule commented out.
**Decision:**
**Date:**
**Confirmed by:**

---

### 8. Should the redundant `date` field be dropped?
**Status:** 🔴 Open
**Question:** `date` (string) is derivable from `appointmentDateTime` (timestamp) — is it kept for a genuine Firestore query-performance reason (e.g. simpler range queries), or is it just historical? If kept, it must always be server-derived, never independently client-settable.
**Blocks:** Nothing critical — this app will treat `date` as server-derived-only regardless, but worth confirming for the patient-app side too.
**Decision:**
**Date:**
**Confirmed by:**

---

### 9. Backfill of `bookingSource` on existing records
**Status:** 🔴 Open
**Question:** Should existing appointment documents get a one-time migration write of `bookingSource: "patient_app"`, or is the read-time fallback (`resolveBookingSource()` in `schema-types.ts`, defaulting missing field to `"patient_app"`) sufficient indefinitely?
**Blocks:** Whether a migration script is needed in Phase 2 of the implementation plan.
**Decision:**
**Date:**
**Confirmed by:**

---

## Resolved Questions

*(None yet — move items here as they're resolved, keeping the full record.)*
