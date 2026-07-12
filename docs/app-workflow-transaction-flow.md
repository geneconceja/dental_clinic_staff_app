# App Workflow & Transaction Flow — Dental Clinic Staff/Admin App

> This repo is the **staff/admin-only** app. Patient registration and self-booking happen in a **separate, already-live app on a different platform** — those flows are shown below only as external context, not as something built in this repo. Both apps share the same Firestore project. Diagrams use Mermaid syntax.

---

## 1. Where This App Fits (system context)

```mermaid
flowchart LR
    subgraph "Patient App (external, separate repo/platform)"
        A[Patient registers/logs in]
        A --> B[Submits appointment request]
        B --> C[Uploads optional photo to Cloudinary]
    end

    subgraph "Shared Firebase Project"
        D[(appointments collection)]
        E[(services collection)]
        F[(clinicSettings)]
    end

    subgraph "Staff/Admin App (this repo)"
        G[Staff reviews pending requests]
        H[Staff books walk-ins directly]
        I[Staff manages services/settings]
    end

    B --> D
    C --> D
    G <--> D
    H --> D
    I --> E
    I --> F
    G --> E
    H --> E
```

**Key point:** this repo never creates a patient-app-originated appointment — it only reads/reviews those. It *does* create walk-in appointments directly.

---

## 2. Staff Journey — Reviewing Patient-App Requests

```mermaid
flowchart TD
    A[Staff login] --> B[Dashboard]
    B --> C[Review Queue: status == pending]
    C --> D[Open a request]
    D --> E{Image attached?}
    E -- Yes --> F[View photo + analysisResults]
    E -- No --> G[View patient/service/time details]
    F --> H{Decision}
    G --> H
    H -- Confirm --> I[Status: confirmed]
    H -- Decline --> J[Status: cancelled]
    I --> K[Patient notified — ownership of this send TBD, see spec Open Questions]
    J --> K
```

---

## 3. Staff Journey — Booking a Walk-In

```mermaid
flowchart TD
    A[Staff clicks New Walk-In Appointment] --> B[Enter patient name, phone]
    B --> C[Select service]
    C --> D[Pick date]
    D --> E[System computes available slots]
    E --> F{Any slots available?}
    F -- No --> G[Show: fully booked, pick another date]
    G --> D
    F -- Yes --> H[Staff selects a slot]
    H --> I{Attach a photo too?}
    I -- Yes --> J[Upload to Cloudinary, trigger analysis]
    I -- No --> K[Skip photo]
    J --> L[Staff confirms]
    K --> L
    L --> M[createWalkInAppointment Cloud Function]
    M --> N{Slot still valid at write time?}
    N -- Yes --> O[Appointment created: bookingSource = staff_walkin, status = confirmed]
    N -- No --> P[Error: slot taken, refresh & retry]
    P --> E
```

Note the difference from the review flow: a walk-in goes straight to `confirmed`, since the staff member is both the requester and the approver — there's no separate party to wait on.

---

## 4. Booking Transaction Flow — Walk-In Path (the critical path for this app)

```mermaid
sequenceDiagram
    participant S as Staff (Flutter Web, this app)
    participant CF as Cloud Function: createWalkInAppointment
    participant FS as Firestore (shared with patient app)

    S->>CF: createWalkInAppointment(firstName, lastName, phoneNumber, serviceId, appointmentDateTime, notes, createdBy)
    CF->>FS: lookup services/{serviceId} for durationMinutes
    CF->>FS: BEGIN TRANSACTION
    CF->>FS: query appointments where date == X AND status in [pending, confirmed]
    Note over CF,FS: This query must return BOTH patient-app and walk-in\nappointments for that date — same collection, same query
    FS-->>CF: existing appointments for that date, any bookingSource
    CF->>CF: recompute available slots, verify requested slot still open
    alt slot still available
        CF->>FS: create appointments/{id}: userId=null, userEmail=null,\nbookingSource=staff_walkin, createdBy=staffUid, status=confirmed
        FS-->>CF: write confirmed
        CF->>FS: COMMIT TRANSACTION
        CF-->>S: success + appointmentId
    else slot no longer available
        CF->>FS: ROLLBACK TRANSACTION
        CF-->>S: error: slot no longer available, refresh slots
    end
```

**Why this transaction is critical:** a patient could be submitting a request through the patient app for the same slot a staff member is booking as a walk-in, at nearly the same moment. Because both write to the same `appointments` collection, this app's transaction only protects against double-booking **if it reads the same collection the patient app writes to with an equivalent query** — this depends on the patient app using compatible logic. See the spec's Open Questions on slot-availability parity; this is the single biggest risk point in the whole system.

---

## 5. Appointment Status Lifecycle

```mermaid
stateDiagram-v2
    [*] --> pending: patient app creates request (external)
    [*] --> confirmed: staff creates walk-in (this app)
    pending --> confirmed: staff confirms
    pending --> cancelled: staff cancels
    confirmed --> cancelled: staff cancels
    confirmed --> completed: staff marks after visit
    confirmed --> no-show: staff marks after missed visit
    cancelled --> [*]
    completed --> [*]
    no-show --> [*]
```

Two distinct entry points into the state machine now: patient-app requests start at `pending`, walk-ins start at `confirmed` directly. Everything downstream of `confirmed` is identical regardless of source.

---

## 6. Image Handling — Two Separate Paths

```mermaid
flowchart TD
    subgraph "Patient-app path (external)"
        A[Patient uploads photo in patient app] --> B[Cloudinary URL saved to appointments.imageUrl]
        B --> C[Existing analysis pipeline runs — this app does not trigger it]
        C --> D[analysisResults populated by external pipeline]
    end

    subgraph "Walk-in path (this app)"
        E[Staff optionally uploads photo during walk-in booking] --> F[Cloudinary URL saved to appointments.imageUrl]
        F --> G{Can this app call the existing analyzeImage function?}
        G -- Yes, shared/callable --> H[Reuse existing function]
        G -- No, not accessible --> I[Duplicate minimal analysis-call logic in this app's functions]
        H --> J[analysisResults populated]
        I --> J
    end

    D --> K[Staff views photo + analysisResults in appointment detail — same UI regardless of source]
    J --> K
```

Whichever path populated `imageUrl`/`analysisResults`, the staff-side **display** is identical — the appointment detail screen doesn't need to know or care which app triggered the upload.

---

## 7. Notification Trigger Flow (ownership TBD — see spec Open Questions)

```mermaid
flowchart LR
    A[status → confirmed] -->|onUpdate trigger| B{Does patient have userId/userEmail?}
    B -- Yes patient_app booking --> C{Who sends this — this app or patient app's backend?}
    B -- No walk-in --> D[No automated patient notification — staff informs in person/by phone]
    C -- This app --> E[Send email/push]
    C -- Patient app's backend --> F[This app does nothing — avoid duplicate send]
    G[Scheduled reminder function, hourly] --> H{Confirmed appt ~N hours out, reminderSent == false, has userEmail?}
    H -- Yes --> I[Send reminder]
    H -- No userEmail, e.g. walk-in --> J[Skip — no channel to reach them automatically]
```

This diagram intentionally shows the open decision point — **do not build the notification-sending Cloud Function until it's confirmed whether the patient app already handles this**, to avoid two systems both emailing the same patient.

---

## 8. Slot Availability Calculation

```mermaid
flowchart TD
    A[Input: target date] --> B{Is date a holiday?}
    B -- Yes --> Z[Return: no slots]
    B -- No --> C{Is clinic open that day of week?}
    C -- No --> Z
    C -- Yes --> D[Generate candidate slots: open→close in slotDurationMinutes increments]
    D --> E[Fetch existing appointments for date where status in pending, confirmed — ALL bookingSource values]
    E --> F[Remove candidate slots overlapping any existing appointment range]
    F --> G[Return remaining slots]
```

This logic must produce the **same result** whether run from this app (for walk-in booking) or from the patient app (for patient requests) — otherwise the two apps disagree about what's bookable, and the transaction in Section 4 can't fully prevent conflicts. Confirm the patient app's actual implementation matches this before relying on it.

---

## 9. Summary: What Must Never Happen (guardrails)

- ❌ This app writing/renaming/removing any patient-app-owned field (`userId`, `userEmail`, `firstName`, `lastName`, `phoneNumber`, `reason`, `imageUrl`, `analysisResults` for patient-app records)
- ❌ Fabricating a Firebase Auth user for a walk-in patient — `userId`/`userEmail` stay `null`
- ❌ Direct client write to `appointments` from this app — always through `createWalkInAppointment` or a status-update Cloud Function
- ❌ Booking a walk-in without re-validating slot availability inside a transaction that queries the *full* `appointments` collection (all `bookingSource` values)
- ❌ Re-triggering image analysis for a patient-app-originated appointment that already has `analysisResults`
- ❌ Building automated patient notifications before confirming the patient app doesn't already send them
- ❌ Assuming the patient app's slot-availability logic matches this app's without verifying it directly
