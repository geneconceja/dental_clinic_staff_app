/**
 * index.ts
 * Dental Clinic Staff/Admin App — Cloud Functions entry point.
 *
 * One export per function file. Add new functions here as they are implemented.
 * See docs/functions-api-contract.md for the contract each function implements.
 */

import { setGlobalOptions } from "firebase-functions";

// Cost-control: cap concurrent containers across all functions.
// Individual functions may override this with their own maxInstances option.
setGlobalOptions({ maxInstances: 10 });

// Phase 2 — Walk-in booking engine
export { createWalkInAppointment } from "./createWalkInAppointment";

// Phase 2 — Status updates (to be implemented next)
// export { updateAppointmentStatus } from "./updateAppointmentStatus";

// Phase 5 — Walk-in image analysis (blocked on decisions-log.md #6)
// export { analyzeWalkInImage } from "./analyzeWalkInImage";

// Phase 6 — Notifications (blocked on decisions-log.md #5)
// export { sendReminders } from "./sendReminders";
// export { onAppointmentStatusChange } from "./onAppointmentStatusChange";
