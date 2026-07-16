/**
 * backfill-booking-source.js
 * Dental Clinic Staff/Admin App — One-time Migration
 *
 * Backfills `bookingSource: "patient_app"` to any appointment document that
 * was written before this field existed (i.e. before the staff app was built).
 *
 * Decision: 2026-07-16 (see decisions-log.md #8)
 *
 * Usage against the LOCAL EMULATOR:
 *   1. Start the Firebase emulator suite.
 *   2. Run: node scripts/backfill-booking-source.js
 *
 * Usage against PRODUCTION:
 *   1. Remove the FIRESTORE_EMULATOR_HOST override below.
 *   2. Set GOOGLE_APPLICATION_CREDENTIALS to a service-account key.
 *   3. Run: node scripts/backfill-booking-source.js
 *
 * Safety:
 *   - Only updates documents where bookingSource is MISSING (undefined or null).
 *   - Uses batch writes (max 499 writes per batch).
 *   - Dry-run mode: set DRY_RUN=1 env var to preview without writing.
 *   - Idempotent: running it twice has no effect.
 */

"use strict";

const PROJECT_ID = process.env.GCLOUD_PROJECT || "oralscope-78cda";
const DRY_RUN    = process.env.DRY_RUN === "1";

// Point at the local emulator when running locally.
// Comment this out for production.
process.env.FIRESTORE_EMULATOR_HOST =
  process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";

const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

initializeApp({ projectId: PROJECT_ID });
const db = getFirestore();

const BATCH_LIMIT = 499;

async function run() {
  console.log("=== backfill-booking-source.js ===");
  console.log("Project: " + PROJECT_ID);
  console.log("Emulator: " + (process.env.FIRESTORE_EMULATOR_HOST || "(none — production)"));
  console.log("Dry-run: " + DRY_RUN);
  console.log("");

  const allSnap = await db.collection("appointments").get();

  const missing = allSnap.docs.filter(
    (doc) =>
      doc.data().bookingSource === undefined ||
      doc.data().bookingSource === null
  );

  console.log("Total appointments:           " + allSnap.size);
  console.log("Missing bookingSource field:  " + missing.length);
  console.log("");

  if (missing.length === 0) {
    console.log("All documents already have bookingSource. Nothing to do.");
    return;
  }

  if (DRY_RUN) {
    console.log("DRY RUN — would update:");
    missing.forEach((doc) => console.log("  - " + doc.id));
    console.log("\nTotal: " + missing.length + " documents (NOT written).");
    return;
  }

  let batchCount  = 0;
  let totalUpdated = 0;

  for (let i = 0; i < missing.length; i += BATCH_LIMIT) {
    const chunk = missing.slice(i, i + BATCH_LIMIT);
    const batch = db.batch();
    for (const doc of chunk) {
      batch.update(doc.ref, { bookingSource: "patient_app" });
    }
    await batch.commit();
    batchCount++;
    totalUpdated += chunk.length;
    console.log("Batch " + batchCount + ": wrote " + chunk.length + " docs (cumulative: " + totalUpdated + ")");
  }

  console.log("\nBackfill complete: " + totalUpdated + " documents updated.");

  // Verify
  const stillMissing = (await db.collection("appointments").get()).docs.filter(
    (doc) =>
      doc.data().bookingSource === undefined ||
      doc.data().bookingSource === null
  );

  if (stillMissing.length > 0) {
    console.error("WARNING: " + stillMissing.length + " documents still missing bookingSource.");
    process.exit(1);
  } else {
    console.log("All documents now have bookingSource set.");
  }
}

run().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
