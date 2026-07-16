/**
 * functions/test/smoke/callCreateWalkIn.ts
 *
 * Standalone smoke test — calls the createWalkInAppointment callable function
 * directly against the local Firebase emulator and prints the result.
 *
 * Prerequisites:
 *   1. Firebase emulator running:
 *        firebase emulators:start --project=oralscope-78cda
 *   2. Emulator seeded with a staff user:
 *        cd scripts && node seed-emulator.js
 *   3. Compile this script (or use ts-node):
 *        npx ts-node functions/test/smoke/callCreateWalkIn.ts
 *      OR compile first:
 *        cd functions && npx tsc && node lib/test/smoke/callCreateWalkIn.js
 *
 * What this tests end-to-end:
 *   - The callable function is exported and registered correctly in index.ts
 *   - Firebase Auth emulator accepts the staff credentials
 *   - The function body runs without errors against the Firestore emulator
 *   - The response matches the expected shape { appointmentId, status }
 *   - The created Firestore document has the correct field values
 *
 * This script is intentionally NOT a Jest test — it's a quick manual check
 * you can run in a terminal to visually confirm the function works before
 * looking at structured test output.
 */

import { initializeApp } from "firebase/app";
import {
  getAuth,
  signInWithEmailAndPassword,
  connectAuthEmulator,
} from "firebase/auth";
import { getFunctions, httpsCallable, connectFunctionsEmulator } from "firebase/functions";
import { getFirestore, doc, getDoc, connectFirestoreEmulator } from "firebase/firestore";

// ---------- Firebase config (emulator — no real credentials needed) ----------

const firebaseConfig = {
  apiKey:    "fake-api-key-for-emulator",
  projectId: "oralscope-78cda",
};

const app       = initializeApp(firebaseConfig);
const auth      = getAuth(app);
const functions = getFunctions(app);
const db        = getFirestore(app);

// Point all SDKs at the local emulators
connectAuthEmulator(auth,           "http://127.0.0.1:9099",  { disableWarnings: true });
connectFunctionsEmulator(functions, "127.0.0.1",               5001);
connectFirestoreEmulator(db,        "127.0.0.1",               8080);

// ---------- Main ----------

async function main(): Promise<void> {
  console.log("=== createWalkInAppointment smoke test ===\n");

  // Step 1: Sign in as the seeded staff user
  console.log("1. Signing in as staff1@clinic.test ...");
  let idToken: string;
  try {
    const cred = await signInWithEmailAndPassword(auth, "staff1@clinic.test", "password123");
    idToken = await cred.user.getIdToken();
    console.log(`   ✅ Signed in — UID: ${cred.user.uid}\n`);
  } catch (err) {
    console.error("   ❌ Sign-in failed:", err);
    console.error("   Make sure the emulator is running and seeded (node scripts/seed-emulator.js).");
    process.exit(1);
  }

  // Step 2: Call the Cloud Function
  console.log("2. Calling createWalkInAppointment ...");
  const payload = {
    firstName:           "Smoke",
    lastName:            "Test",
    phoneNumber:         "555-SMOKE",
    serviceId:           "svc-cleaning",     // adjust to match your seeded service ID
    appointmentDateTime: nextMondayAt9amISO(),   // a future slot to avoid conflicts
    notes:               "Smoke test walk-in",
  };
  console.log("   Payload:", JSON.stringify(payload, null, 2), "\n");

  const callFn = httpsCallable<typeof payload, { appointmentId: string; status: string }>(
    functions,
    "createWalkInAppointment"
  );

  let appointmentId: string;
  try {
    const result = await callFn(payload);
    appointmentId = result.data.appointmentId;
    console.log("   ✅ Function returned:", result.data, "\n");
  } catch (err: any) {
    console.error("   ❌ Function call failed:", err?.code, err?.message);
    console.error("   Full error:", err);
    process.exit(1);
  }

  // Step 3: Read back the created document from Firestore
  console.log("3. Reading back appointment document from Firestore ...");
  try {
    const snap = await getDoc(doc(db, "appointments", appointmentId));
    if (!snap.exists()) {
      console.error(`   ❌ Document appointments/${appointmentId} does not exist`);
      process.exit(1);
    }

    const data = snap.data()!;
    console.log("   ✅ Document exists. Key fields:");
    console.log("      bookingSource: ", data["bookingSource"]);
    console.log("      status:        ", data["status"]);
    console.log("      userId:        ", data["userId"]);
    console.log("      userEmail:     ", data["userEmail"]);
    console.log("      date:          ", data["date"]);
    console.log("      startTime:     ", data["startTime"]);
    console.log("      endTime:       ", data["endTime"]);
    console.log("      paid:          ", data["paid"]);
    console.log("      reminderSent:  ", data["reminderSent"]);
    console.log("      createdBy:     ", data["createdBy"]);
    console.log("");

    // Quick assertions
    const errors: string[] = [];
    if (data["bookingSource"] !== "staff_walkin") errors.push(`bookingSource should be "staff_walkin", got "${data["bookingSource"]}"`);
    if (data["status"] !== "confirmed")            errors.push(`status should be "confirmed", got "${data["status"]}"`);
    if (data["userId"] !== null)                    errors.push(`userId should be null, got "${data["userId"]}"`);
    if (data["userEmail"] !== null)                 errors.push(`userEmail should be null, got "${data["userEmail"]}"`);
    if (data["paid"] !== false)                     errors.push(`paid should be false`);
    if (data["reminderSent"] !== false)             errors.push(`reminderSent should be false`);

    if (errors.length > 0) {
      console.error("   ❌ Field validation failures:");
      errors.forEach((e) => console.error(`      - ${e}`));
      process.exit(1);
    }

    console.log("   ✅ All field assertions passed.\n");
  } catch (err) {
    console.error("   ❌ Firestore read failed:", err);
    process.exit(1);
  }

  console.log("=== Smoke test PASSED ===");
  console.log(`   Appointment ID: ${appointmentId}`);
  console.log("   Check http://127.0.0.1:4000/firestore to inspect the document.\n");
  process.exit(0);
}

// ---------- Helper: next Monday at 09:00 UTC (avoids collisions with seed data) ----------

function nextMondayAt9amISO(): string {
  const now = new Date();
  const daysUntilMonday = (8 - now.getUTCDay()) % 7 || 7; // always at least 1 day ahead
  const nextMonday = new Date(Date.UTC(
    now.getUTCFullYear(),
    now.getUTCMonth(),
    now.getUTCDate() + daysUntilMonday,
    9, 0, 0, 0
  ));
  return nextMonday.toISOString();
}

main().catch((err) => {
  console.error("Unhandled error:", err);
  process.exit(1);
});
