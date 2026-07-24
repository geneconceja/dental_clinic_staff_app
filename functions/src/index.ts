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

// Cost-control & low-latency region for Philippines (Asia/Singapore):
setGlobalOptions({ region: "asia-southeast1", maxInstances: 10 });

// Phase 2 — Walk-in booking engine
export { createWalkInAppointment } from "./createWalkInAppointment";

// Phase 2 — Status updates
export { updateAppointmentStatus } from "./updateAppointmentStatus";

// Phase 5 — Walk-in image analysis (skipped per user decision — no image uploads on clinic side)
// export { analyzeWalkInImage } from "./analyzeWalkInImage";

// Phase 6 — Notifications
export { sendReminders } from "./sendReminders";
export { onAppointmentStatusChange } from "./onAppointmentStatusChange";

// Phase 7 — Mobile-to-Web SSO Engine
export { generateSsoToken } from "./generateSsoToken";
export { consumeSsoToken } from "./consumeSsoToken";

