/**
 * index.ts
 * Dental Clinic Staff/Admin App — Cloud Functions entry point.
 *
 * One export per function file. Add new functions here as they are implemented.
 * See docs/functions-api-contract.md for the contract each function implements.
 */

import { setGlobalOptions } from "firebase-functions";
import { initializeApp, getApps } from "firebase-admin/app";

// Initialize Firebase Admin SDK globally.
if (getApps().length === 0) {
  initializeApp();
}

// Cost-control: cap concurrent containers across all functions.
// Individual functions may override this with their own maxInstances option.
setGlobalOptions({ maxInstances: 10 });

// Phase 2 — Walk-in booking engine
export { createWalkInAppointment } from "./createWalkInAppointment";

// Phase 2 — Status updates
export { updateAppointmentStatus } from "./updateAppointmentStatus";

// Phase 5 — Walk-in image analysis (skipped per user decision — no image uploads on clinic side)
// export { analyzeWalkInImage } from "./analyzeWalkInImage";

// Phase 6 — Notifications
export { sendReminders } from "./sendReminders";
export { onAppointmentStatusChange } from "./onAppointmentStatusChange";
