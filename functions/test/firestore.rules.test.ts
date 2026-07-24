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

  test("patient CAN create a pending appointment for themselves with bookingSource patient_web", async () => {
    const patientCtx = testEnv.authenticatedContext(PATIENT_UID);
    await assertSucceeds(
      patientCtx.firestore().collection("appointments").doc("new-patient-web-appt").set({
        userId: PATIENT_UID,
        status: "pending",
        bookingSource: "patient_web",
        firstName: "Jane",
        lastName: "Doe",
      })
    );
  });

  test("owning patient CAN cancel their appointment with a cancellationReason", async () => {
    await seedAppointmentOwnedByPatient();

    const patientCtx = testEnv.authenticatedContext(PATIENT_UID);
    await assertSucceeds(
      patientCtx.firestore().collection("appointments").doc(APPOINTMENT_ID).update({
        status: "cancelled",
        cancellationReason: "Schedule conflict",
        updatedAt: new Date(),
      })
    );
  });

  test("owning patient CAN reschedule their appointment date and time", async () => {
    await seedAppointmentOwnedByPatient();

    const patientCtx = testEnv.authenticatedContext(PATIENT_UID);
    await assertSucceeds(
      patientCtx.firestore().collection("appointments").doc(APPOINTMENT_ID).update({
        date: "2026-08-10",
        startTime: "10:00",
        endTime: "10:30",
        appointmentDateTime: new Date("2026-08-10T10:00:00Z"),
        status: "pending",
        updatedAt: new Date(),
      })
    );
  });
});

describe("users collection", () => {
  test("patient can read their own user profile document", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc(PATIENT_UID).set({
        uid: PATIENT_UID,
        role: "patient",
        name: "Test Patient",
        email: "patient@test.com",
      });
    });

    const patientCtx = testEnv.authenticatedContext(PATIENT_UID);
    await assertSucceeds(
      patientCtx.firestore().collection("users").doc(PATIENT_UID).get()
    );
  });

  test("patient CANNOT read another patient's user profile document", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc(PATIENT_UID).set({
        uid: PATIENT_UID,
        role: "patient",
        name: "Test Patient",
        email: "patient@test.com",
      });
    });

    const otherPatientCtx = testEnv.authenticatedContext(OTHER_PATIENT_UID);
    await assertFails(
      otherPatientCtx.firestore().collection("users").doc(PATIENT_UID).get()
    );
  });
});

describe("activity_logs collection", () => {
  test("staff can read activity_logs documents", async () => {
    await seedStaffUser();
    const staffCtx = testEnv.authenticatedContext(STAFF_UID);
    await assertSucceeds(
      staffCtx.firestore().collection("activity_logs").get()
    );
  });

  test("unauthenticated user CANNOT read activity_logs", async () => {
    const unauthCtx = testEnv.unauthenticatedContext();
    await assertFails(
      unauthCtx.firestore().collection("activity_logs").get()
    );
  });

  test("signed-in user can create an activity_log entry", async () => {
    await seedStaffUser();
    const staffCtx = testEnv.authenticatedContext(STAFF_UID);
    await assertSucceeds(
      staffCtx.firestore().collection("activity_logs").add({
        actorUid: STAFF_UID,
        actorEmail: "staff@test.com",
        actorRole: "staff",
        action: "appointment_confirmed",
        resourceId: "appt-123",
        timestamp: new Date(),
      })
    );
  });

  test("client CANNOT update an existing activity_log (immutable audit trail)", async () => {
    await seedStaffUser();
    const logId = "log-123";
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("activity_logs").doc(logId).set({
        actorUid: STAFF_UID,
        action: "appointment_confirmed",
      });
    });

    const staffCtx = testEnv.authenticatedContext(STAFF_UID);
    await assertFails(
      staffCtx.firestore().collection("activity_logs").doc(logId).update({
        action: "tampered_action",
      })
    );
  });

  test("client CANNOT delete an existing activity_log (immutable audit trail)", async () => {
    await seedStaffUser();
    const logId = "log-456";
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("activity_logs").doc(logId).set({
        actorUid: STAFF_UID,
        action: "appointment_cancelled",
      });
    });

    const staffCtx = testEnv.authenticatedContext(STAFF_UID);
    await assertFails(
      staffCtx.firestore().collection("activity_logs").doc(logId).delete()
    );
  });
});

describe("sso_tokens collection", () => {
  test("direct client read of sso_tokens is DENIED", async () => {
    await seedStaffUser();
    const staffCtx = testEnv.authenticatedContext(STAFF_UID);
    await assertFails(
      staffCtx.firestore().collection("sso_tokens").doc("token-123").get()
    );
  });

  test("direct client write to sso_tokens is DENIED", async () => {
    await seedStaffUser();
    const staffCtx = testEnv.authenticatedContext(STAFF_UID);
    await assertFails(
      staffCtx.firestore().collection("sso_tokens").doc("token-123").set({
        uid: STAFF_UID,
        used: false,
      })
    );
  });
});