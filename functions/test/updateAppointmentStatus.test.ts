/**
 * functions/test/updateAppointmentStatus.test.ts
 *
 * Integration tests for the updateAppointmentStatus Cloud Function handler.
 * Runs against the Firebase emulator suite (Firestore + Functions emulators).
 *
 * Run:
 *   Terminal 1: firebase emulators:start --project=oralscope-78cda
 *   Terminal 2: cd functions && npm test -- --testPathPattern=updateAppointmentStatus
 */

import { initializeApp, getApps, App } from "firebase-admin/app";
import { getFirestore, Firestore, Timestamp } from "firebase-admin/firestore";
import { CallableRequest } from "firebase-functions/v2/https";

// Point firebase-admin at the local emulators.
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";

const PROJECT_ID = "oralscope-78cda";

let adminApp: App;
let db: Firestore;

// Import the handler AFTER environment variables are set.
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { updateAppointmentStatusHandler } = require("../src/updateAppointmentStatus") as {
  updateAppointmentStatusHandler: (req: CallableRequest<unknown>) => Promise<{ success: boolean; appointmentId: string; newStatus: string }>;
};

// ---------- Constants ----------

const STAFF_UID   = "test-status-staff-uid";
const ADMIN_UID   = "test-status-admin-uid";
const PATIENT_UID = "test-status-patient-uid";

const BASE_ISO  = "2026-09-01T09:00:00.000Z";

// ---------- Test setup / teardown ----------

beforeAll(async () => {
  if (getApps().length === 0) {
    adminApp = initializeApp({ projectId: PROJECT_ID });
  } else {
    adminApp = getApps()[0]!;
  }
  db = getFirestore(adminApp);
});

beforeEach(async () => {
  await seedStaffUsers();
});

afterEach(async () => {
  await clearCollection("appointments");
  await clearCollection("users");
});

// ---------- Seed helpers ----------

async function seedStaffUsers(): Promise<void> {
  const batch = db.batch();

  batch.set(db.collection("users").doc(STAFF_UID), {
    uid:       STAFF_UID,
    role:      "staff",
    name:      "Test Staff",
    email:     "staff-status@clinic.test",
    phone:     "555-0001",
    active:    true,
    createdAt: Timestamp.now(),
  });

  batch.set(db.collection("users").doc(ADMIN_UID), {
    uid:       ADMIN_UID,
    role:      "admin",
    name:      "Test Admin",
    email:     "admin-status@clinic.test",
    phone:     "555-0002",
    active:    true,
    createdAt: Timestamp.now(),
  });

  await batch.commit();
}

async function clearCollection(collectionName: string): Promise<void> {
  const snap = await db.collection(collectionName).get();
  const batch = db.batch();
  snap.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
}

// ---------- Request factory ----------

function makeRequest(uid: string, data: unknown): CallableRequest<unknown> {
  return {
    auth: {
      uid,
      token: {
        uid,
        aud:             PROJECT_ID,
        auth_time:       Date.now() / 1000,
        exp:             Date.now() / 1000 + 3600,
        firebase:        { identities: {}, sign_in_provider: "custom" },
        iat:             Date.now() / 1000,
        iss:             `https://securetoken.google.com/${PROJECT_ID}`,
        sub:             uid,
        email:           "test-status@clinic.test",
        email_verified:  true,
      },
    },
    data,
    rawRequest: {} as any,
    instanceIdToken: undefined,
    app: undefined,
  } as unknown as CallableRequest<unknown>;
}

async function createMockAppointment(id: string, status: string): Promise<void> {
  await db.collection("appointments").doc(id).set({
    id:                  id,
    userId:              PATIENT_UID,
    userEmail:           "patient@test.com",
    firstName:           "John",
    lastName:            "Doe",
    phoneNumber:         "555-4321",
    serviceId:           "svc-cleaning",
    serviceName:         "Teeth Cleaning",
    reason:              "Teeth Cleaning",
    date:                "2026-09-01",
    startTime:           "09:00",
    endTime:             "09:30",
    appointmentDateTime: Timestamp.fromDate(new Date(BASE_ISO)),
    notes:               null,
    imageUrl:            null,
    analysisResults:     null,
    status:              status,
    bookingSource:       "patient_app",
    createdBy:           "patient",
    paid:                false,
    reminderSent:        false,
    createdAt:           Timestamp.now(),
    updatedAt:           Timestamp.now(),
  });
}

// ---------- Tests ----------

describe("updateAppointmentStatus — happy paths & state transitions", () => {
  test("pending -> confirmed transition succeeds", async () => {
    const apptId = "appt-pending-to-confirmed";
    await createMockAppointment(apptId, "pending");

    const result = await updateAppointmentStatusHandler(
      makeRequest(STAFF_UID, { appointmentId: apptId, newStatus: "confirmed" })
    );

    expect(result.success).toBe(true);
    expect(result.appointmentId).toBe(apptId);
    expect(result.newStatus).toBe("confirmed");

    const doc = await db.collection("appointments").doc(apptId).get();
    expect(doc.data()!.status).toBe("confirmed");
  });

  test("pending -> cancelled transition succeeds and writes cancellationReason", async () => {
    const apptId = "appt-pending-to-cancelled";
    await createMockAppointment(apptId, "pending");

    const result = await updateAppointmentStatusHandler(
      makeRequest(STAFF_UID, {
        appointmentId: apptId,
        newStatus: "cancelled",
        cancellationReason: "Doctor unavailable",
      })
    );

    expect(result.success).toBe(true);
    expect(result.newStatus).toBe("cancelled");

    const doc = await db.collection("appointments").doc(apptId).get();
    expect(doc.data()!.status).toBe("cancelled");
    expect(doc.data()!.cancellationReason).toBe("Doctor unavailable");
  });

  test("confirmed -> completed transition succeeds", async () => {
    const apptId = "appt-confirmed-to-completed";
    await createMockAppointment(apptId, "confirmed");

    const result = await updateAppointmentStatusHandler(
      makeRequest(STAFF_UID, { appointmentId: apptId, newStatus: "completed" })
    );

    expect(result.success).toBe(true);
    expect(result.newStatus).toBe("completed");

    const doc = await db.collection("appointments").doc(apptId).get();
    expect(doc.data()!.status).toBe("completed");
  });

  test("confirmed -> no-show transition succeeds", async () => {
    const apptId = "appt-confirmed-to-noshow";
    await createMockAppointment(apptId, "confirmed");

    const result = await updateAppointmentStatusHandler(
      makeRequest(STAFF_UID, { appointmentId: apptId, newStatus: "no-show" })
    );

    expect(result.success).toBe(true);
    expect(result.newStatus).toBe("no-show");

    const doc = await db.collection("appointments").doc(apptId).get();
    expect(doc.data()!.status).toBe("no-show");
  });

  test("admin role is also allowed to update status", async () => {
    const apptId = "appt-admin-update";
    await createMockAppointment(apptId, "pending");

    const result = await updateAppointmentStatusHandler(
      makeRequest(ADMIN_UID, { appointmentId: apptId, newStatus: "confirmed" })
    );

    expect(result.success).toBe(true);
  });
});

describe("updateAppointmentStatus — error handling & validation", () => {
  test("throws permission-denied if caller is not authenticated", async () => {
    const unauthReq = {
      auth: null,
      data: { appointmentId: "any", newStatus: "confirmed" },
    } as unknown as CallableRequest<unknown>;

    await expect(
      updateAppointmentStatusHandler(unauthReq)
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  test("throws permission-denied if caller lacks a staff user account doc", async () => {
    await expect(
      updateAppointmentStatusHandler(makeRequest("nonexistent-uid", { appointmentId: "any", newStatus: "confirmed" }))
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  test("throws invalid-argument if appointmentId is missing or empty", async () => {
    await expect(
      updateAppointmentStatusHandler(makeRequest(STAFF_UID, { newStatus: "confirmed" }))
    ).rejects.toMatchObject({ code: "invalid-argument" });

    await expect(
      updateAppointmentStatusHandler(makeRequest(STAFF_UID, { appointmentId: "   ", newStatus: "confirmed" }))
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  test("throws invalid-argument if newStatus is invalid", async () => {
    await expect(
      updateAppointmentStatusHandler(makeRequest(STAFF_UID, { appointmentId: "appt-1", newStatus: "unknown-status" }))
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  test("throws not-found if the appointment does not exist", async () => {
    await expect(
      updateAppointmentStatusHandler(makeRequest(STAFF_UID, { appointmentId: "missing-appt-id", newStatus: "confirmed" }))
    ).rejects.toMatchObject({ code: "not-found" });
  });

  test("throws failed-precondition on invalid status transitions (e.g. pending -> completed)", async () => {
    const apptId = "appt-invalid-transition";
    await createMockAppointment(apptId, "pending"); // pending

    // pending -> completed is NOT allowed
    await expect(
      updateAppointmentStatusHandler(makeRequest(STAFF_UID, { appointmentId: apptId, newStatus: "completed" }))
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  test("throws failed-precondition if attempting to transition out of a terminal state (e.g. completed -> cancelled)", async () => {
    const apptId = "appt-terminal-state";
    await createMockAppointment(apptId, "completed"); // completed

    // completed -> cancelled is NOT allowed (completed is terminal)
    await expect(
      updateAppointmentStatusHandler(makeRequest(STAFF_UID, { appointmentId: apptId, newStatus: "cancelled" }))
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });
});
