# Cloud Functions API Contract — Dental Clinic Staff/Admin App

This document defines the exact signature, behavior, and error handling for every Cloud Function this app implements or depends on. Treat this as the source of truth an AI assistant or developer should implement against — if the implementation needs to deviate, update this file in the same PR.

Functions marked **(TBD ownership)** depend on an unresolved Open Question (see `decisions-log.md`) about whether this app or the patient app's backend owns that responsibility. Do not implement those until the question is resolved.

---

## 1. `createWalkInAppointment`

**Type:** Callable Cloud Function
**Auth required:** Yes — caller must have a `users/{uid}` doc with `role in ['staff', 'admin']`

### Input
```typescript
{
  firstName: string;        // required, non-empty
  lastName: string;         // required, non-empty
  phoneNumber: string;      // required, non-empty
  serviceId: string;        // required, must exist in `services` and be active
  appointmentDateTime: string; // required, ISO 8601 timestamp
  notes?: string;           // optional
  imageUrl?: string;        // optional, Cloudinary URL if staff attached a photo
}
```

### Behavior
1. Verify caller is staff/admin (throw `permission-denied` otherwise).
2. Look up `services/{serviceId}`; throw `not-found` if missing, `failed-precondition` if `active == false`.
3. Compute `endTime` from `appointmentDateTime + service.durationMinutes`.
4. Run inside a Firestore transaction:
   - Query `appointments` where `date == <derived date>` and `status in ['pending', 'confirmed']`.
   - Verify the requested `[startTime, endTime]` range does not overlap any existing appointment.
   - If it overlaps, throw `already-exists` with message `"Slot no longer available"`.
   - Otherwise, create the `appointments` document.
5. If `imageUrl` was provided, asynchronously trigger the image analysis path (see `analyzeWalkInImage` below) — do not block the response on this.

### Output
```typescript
{
  appointmentId: string;
  status: "confirmed";
}
```

### Fields written on the created document
```typescript
{
  userId: null,
  userEmail: null,
  firstName, lastName, phoneNumber,   // as provided
  serviceId, serviceName,             // serviceName denormalized from lookup
  reason: service.name,               // populate legacy `reason` field too, for read-compatibility with any existing UI that still reads it
  appointmentDateTime,
  date,                               // derived, YYYY-MM-DD
  startTime, endTime,                 // derived server-side
  notes: notes ?? null,
  imageUrl: imageUrl ?? null,
  analysisResults: null,              // populated later if imageUrl present
  status: "confirmed",
  bookingSource: "staff_walkin",
  createdBy: <caller uid>,
  paid: false,
  reminderSent: false,
  createdAt: <server timestamp>,
  updatedAt: <server timestamp>,
}
```

### Errors
| Code | When |
|---|---|
| `permission-denied` | Caller is not staff/admin |
| `invalid-argument` | Missing/malformed required fields |
| `not-found` | `serviceId` doesn't exist |
| `failed-precondition` | Service is inactive |
| `already-exists` | Slot conflict detected inside the transaction |

---

## 2. `updateAppointmentStatus`

**Type:** Callable Cloud Function
**Auth required:** Yes — staff/admin only

### Input
```typescript
{
  appointmentId: string;
  newStatus: "confirmed" | "cancelled" | "completed" | "no-show";
  cancellationReason?: string; // optional, only meaningful if newStatus == "cancelled"
}
```

### Behavior
1. Verify caller is staff/admin.
2. Fetch the appointment; throw `not-found` if missing.
3. Validate the transition against the allowed table:
   ```
   pending    → confirmed, cancelled
   confirmed  → cancelled, completed, no-show
   ```
   Throw `failed-precondition` if the transition isn't allowed.
4. Update `status`, `updatedAt`, and `cancellationReason` if provided.
5. Do NOT modify `userId`, `userEmail`, `firstName`, `lastName`, `phoneNumber`, `reason`, `imageUrl`, `analysisResults` — this function only ever touches status-adjacent fields.

### Output
```typescript
{ success: true, appointmentId: string, newStatus: string }
```

### Errors
| Code | When |
|---|---|
| `permission-denied` | Caller is not staff/admin |
| `not-found` | Appointment doesn't exist |
| `failed-precondition` | Invalid status transition |

---

## 3. `cancelAppointmentAsPatient` **(external — patient app's responsibility, documented here for awareness only)**

This app does **not** implement this function. It's documented here because it writes to the same `appointments` collection this app reads, so understanding its contract matters for avoiding conflicting assumptions.

⚠️ **Confirm with the patient app team**: does a patient-initiated cancellation go through a Cloud Function (Admin SDK) or a direct client write under Firestore rules? This determines what `firestore.rules` needs to allow for patient-owned documents. See the `allow update` patient branch in `firestore.rules` for the assumed shape.

---

## 4. `analyzeWalkInImage`

**Type:** Firestore-triggered function (`onCreate` on `appointments/{id}`, filtered to `bookingSource == "staff_walkin" && imageUrl != null`) — OR a directly-callable function invoked from `createWalkInAppointment`. **Pick one pattern and use it consistently; don't implement both.**

⚠️ **Open question (see decisions-log.md):** can this app call/reuse the existing patient-app-side analysis function, or does it need this separate implementation? The contract below assumes a separate implementation is needed; update this doc once confirmed.

### Behavior
1. Triggered when a walk-in appointment is created with a non-null `imageUrl`.
2. Calls the object detection model's inference endpoint with the image URL.
3. On success, updates `appointments/{id}.analysisResults`:
   ```typescript
   {
     diseaseLabel: string | null,
     confidencePercentage: number | null, // 0-100
   }
   ```
   *(Schema pending confirmation — see decisions-log.md; may need to become an array of candidates instead of a single label.)*
4. On failure (timeout, model error), log the error and leave `analysisResults: null` — do **not** block or retry indefinitely. Surface the failure state in the staff UI (e.g. "Analysis failed" rather than a blank/loading state forever).

### Errors
Logged, not thrown back to any client — this is a background/async process. Failures should be visible in Cloud Functions logs and, ideally, reflected as an `analysisStatus: "failed"` field if you want the UI to distinguish "not analyzed" from "analysis attempted and failed" (flagged as a possible additive field — confirm if wanted).

---

## 5. `sendReminders` **(TBD ownership)**

**Type:** Scheduled function (Cloud Scheduler + Pub/Sub, e.g. hourly)

Do not implement until decisions-log.md's "notification ownership" question is resolved. If this app ends up owning it:

### Behavior (draft, pending confirmation)
1. Query `appointments` where `status == "confirmed"` and `appointmentDateTime` is within `clinicSettings.reminderHoursBefore` hours from now, and `reminderSent == false`.
2. For appointments with a non-null `userEmail` (patient-app bookings), send a reminder email/push.
3. For walk-ins (`userEmail == null`), skip automated reminders — no channel to reach them.
4. Set `reminderSent = true` after a successful send.

---

## 6. `onAppointmentStatusChange` **(TBD ownership)**

**Type:** Firestore-triggered function (`onUpdate` on `appointments/{id}`, filtered to status field changes)

Do not implement until decisions-log.md's "notification ownership" question is resolved — same reasoning as `sendReminders`. If owned by this app, notify the patient (if `userEmail` present) on `confirmed`/`cancelled` transitions, and optionally notify staff internally via FCM for coordination.

---

## Summary Table

| Function | Type | Auth | Status |
|---|---|---|---|
| `createWalkInAppointment` | Callable | staff/admin | Ready to implement |
| `updateAppointmentStatus` | Callable | staff/admin | Ready to implement |
| `cancelAppointmentAsPatient` | External (patient app) | N/A | Reference only — not built here |
| `analyzeWalkInImage` | Trigger or callable | N/A (internal) | Ready to implement, pending pattern choice |
| `sendReminders` | Scheduled | N/A (internal) | **Blocked** on ownership decision |
| `onAppointmentStatusChange` | Trigger | N/A (internal) | **Blocked** on ownership decision |
