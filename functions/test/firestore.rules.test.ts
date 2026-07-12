/**
 * functions/test/firestore.rules.test.ts
 *
 * Tests the key access-control scenarios in ../../firestore.rules.
 * Requires the Firestore emulator to be running (firebase emulators:start)
 * before running `npm test`.
 */

import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertSucceeds,
  assertFails,
} from "@firebase/rules-unit-testing";
import * as fs from "fs";
import * as path from "path";

let testEnv: RulesTestEnvironment;

const PROJECT_ID = "oralscope-78cda"; // match your real project ID

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(path.resolve(__dirname, "../../firestore.rules"), "utf8"),
      host: "127.0.0.1",
      port: 8080, // must match your firestore emulator port
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

// ---------- Test data helpers ----------

const STAFF_UID = "staff-test-uid";
const PATIENT_UID = "patient-test-uid";
const OTHER_PATIENT_UID = "other-patient-test-uid";
const APPOINTMENT_ID = "test-appt-1";

async function seedStaffUser() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context
      .firestore()
      .collection("users")
      .doc(STAFF_UID)
      .set({ uid: STAFF_UID, role: "staff", name: "Test Staff", email: "staff@test.com", phone: "123", active: true });
  });
}

async function seedAppointmentOwnedByPatient() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context
      .firestore()
      .collection("appointments")
      .doc(APPOINTMENT_ID)
      .set({
        userId: PATIENT_UID,
        userEmail: "patient@test.com",
        firstName: "Test",
        lastName: "Patient",
        phoneNumber: "123",
        reason: "Cleaning",
        date: "2026-08-15",
        startTime: "09:00",
        endTime: "09:30",
        notes: null,
        imageUrl: null,
        analysisResults: null,
        status: "pending",
        bookingSource: "patient_app",
        createdBy: null,
        paid: false,
        reminderSent: false,
      });
  });
}

// ---------- Tests ----------

describe("appointments collection", () => {
  test("staff can read any appointment", async () => {
    await seedStaffUser();
    await seedAppointmentOwnedByPatient();

    const staffCtx = testEnv.authenticatedContext(STAFF_UID);
    await assertSucceeds(
      staffCtx.firestore().collection("appointments").doc(APPOINTMENT_ID).get()
    );
  });

  test("a patient can read their own appointment", async () => {
    await seedAppointmentOwnedByPatient();

    const patientCtx = testEnv.authenticatedContext(PATIENT_UID);
    await assertSucceeds(
      patientCtx.firestore().collection("appointments").doc(APPOINTMENT_ID).get()
    );
  });

  test("a patient CANNOT read another patient's appointment", async () => {
    await seedAppointmentOwnedByPatient();

    const otherPatientCtx = testEnv.authenticatedContext(OTHER_PATIENT_UID);
    await assertFails(
      otherPatientCtx.firestore().collection("appointments").doc(APPOINTMENT_ID).get()
    );
  });

  test("an unauthenticated user CANNOT read any appointment", async () => {
    await seedAppointmentOwnedByPatient();

    const anonCtx = testEnv.unauthenticatedContext();
    await assertFails(
      anonCtx.firestore().collection("appointments").doc(APPOINTMENT_ID).get()
    );
  });

  test("direct client create is rejected (must go through Cloud Functions)", async () => {
    await seedStaffUser();

    const staffCtx = testEnv.authenticatedContext(STAFF_UID);
    await assertFails(
      staffCtx.firestore().collection("appointments").doc("new-direct-create").set({
        userId: null,
        status: "confirmed",
        bookingSource: "staff_walkin",
      })
    );
  });

  test("staff CAN transition pending -> confirmed", async () => {
    await seedStaffUser();
    await seedAppointmentOwnedByPatient();

    const staffCtx = testEnv.authenticatedContext(STAFF_UID);
    await assertSucceeds(
      staffCtx.firestore().collection("appointments").doc(APPOINTMENT_ID).update({
        status: "confirmed",
        updatedAt: new Date(),
      })
    );
  });

  test("staff CANNOT skip pending -> completed directly", async () => {
    await seedStaffUser();
    await seedAppointmentOwnedByPatient();

    const staffCtx = testEnv.authenticatedContext(STAFF_UID);
    await assertFails(
      staffCtx.firestore().collection("appointments").doc(APPOINTMENT_ID).update({
        status: "completed",
        updatedAt: new Date(),
      })
    );
  });

  test("patient can cancel their own pending appointment", async () => {
    await seedAppointmentOwnedByPatient();

    const patientCtx = testEnv.authenticatedContext(PATIENT_UID);
    await assertSucceeds(
      patientCtx.firestore().collection("appointments").doc(APPOINTMENT_ID).update({
        status: "cancelled",
        updatedAt: new Date(),
      })
    );
  });

  test("patient CANNOT sneak in a paid:true change alongside cancelling", async () => {
    await seedAppointmentOwnedByPatient();

    const patientCtx = testEnv.authenticatedContext(PATIENT_UID);
    await assertFails(
      patientCtx.firestore().collection("appointments").doc(APPOINTMENT_ID).update({
        status: "cancelled",
        paid: true, // not allowed — only status/updatedAt permitted for patients
      })
    );
  });

  test("patient CANNOT cancel another patient's appointment", async () => {
    await seedAppointmentOwnedByPatient();

    const otherPatientCtx = testEnv.authenticatedContext(OTHER_PATIENT_UID);
    await assertFails(
      otherPatientCtx.firestore().collection("appointments").doc(APPOINTMENT_ID).update({
        status: "cancelled",
        updatedAt: new Date(),
      })
    );
  });
});