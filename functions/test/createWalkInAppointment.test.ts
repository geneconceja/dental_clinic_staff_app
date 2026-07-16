/**
 * functions/test/createWalkInAppointment.test.ts
 *
 * Integration tests for the createWalkInAppointment Cloud Function handler.
 * Runs against the Firebase emulator suite (Firestore + Functions emulators
 * must be running before executing `npm test`).
 *
 * Test strategy:
 *   - Unit-style tests: call the exported handler directly with a mock
 *     CallableRequest — no HTTPS overhead, exercises all code paths cleanly.
 *   - Concurrency test: use two concurrent direct handler calls that race
 *     to claim the same slot — the Firestore transaction must ensure exactly
 *     one succeeds and one gets "already-exists".
 *
 * Run:
 *   Terminal 1: firebase emulators:start --project=oralscope-78cda
 *   Terminal 2: cd functions && npm test -- --testPathPattern=createWalkIn
 */

import { initializeApp, getApps, cert, App } from "firebase-admin/app";
import { getFirestore, Firestore, Timestamp } from "firebase-admin/firestore";
import { CallableRequest } from "firebase-functions/v2/https";

// ---------- Emulator environment setup ----------

// Point firebase-admin at the local emulators before any SDK call.
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";

// Use a dedicated test project ID — matches the emulator's project.
const PROJECT_ID = "oralscope-78cda";

let adminApp: App;
let db: Firestore;

// Import the handler AFTER environment variables are set so firebase-admin
// initialises against the emulator, not production.
// We use require() here to control the import order safely.
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { createWalkInAppointmentHandler, snapToSlot } = require("../src/createWalkInAppointment") as {
  createWalkInAppointmentHandler: (req: CallableRequest<unknown>) => Promise<{ appointmentId: string; status: string }>;
  snapToSlot: (date: Date, slotDurationMinutes: number) => Date;
};

// ---------- Constants ----------

const STAFF_UID   = "test-staff-uid";
const ADMIN_UID   = "test-admin-uid";
const PATIENT_UID = "test-patient-uid";

const SERVICE_ID  = "service-cleaning-30min";
const SERVICE_INACTIVE_ID = "service-inactive";

const BASE_DATE = "2026-09-01";
const BASE_ISO  = "2026-09-01T09:00:00.000Z"; // 09:00 UTC

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
  // Seed prerequisite documents before each test.
  await seedStaffUsers();
  await seedServices();
  await seedClinicSettings();
});

afterEach(async () => {
  // Wipe collections between tests for isolation.
  await clearCollection("appointments");
  await clearCollection("users");
  await clearCollection("services");
  await clearCollection("clinicSettings");
});

// ---------- Seed helpers ----------

async function seedStaffUsers(): Promise<void> {
  const batch = db.batch();

  batch.set(db.collection("users").doc(STAFF_UID), {
    uid:       STAFF_UID,
    role:      "staff",
    name:      "Test Staff",
    email:     "staff@clinic.test",
    phone:     "555-0001",
    active:    true,
    createdAt: Timestamp.now(),
  });

  batch.set(db.collection("users").doc(ADMIN_UID), {
    uid:       ADMIN_UID,
    role:      "admin",
    name:      "Test Admin",
    email:     "admin@clinic.test",
    phone:     "555-0002",
    active:    true,
    createdAt: Timestamp.now(),
  });

  await batch.commit();
}

async function seedServices(): Promise<void> {
  const batch = db.batch();

  batch.set(db.collection("services").doc(SERVICE_ID), {
    id:              SERVICE_ID,
    name:            "Cleaning",
    durationMinutes: 30,
    price:           500,
    description:     "Standard tooth cleaning",
    active:          true,
  });

  batch.set(db.collection("services").doc(SERVICE_INACTIVE_ID), {
    id:              SERVICE_INACTIVE_ID,
    name:            "Discontinued",
    durationMinutes: 60,
    price:           0,
    description:     "No longer offered",
    active:          false,
  });

  await batch.commit();
}

async function seedClinicSettings(): Promise<void> {
  await db.collection("clinicSettings").doc("main").set({
    slotDurationMinutes: 30,
    workingHours: {
      monday:    { open: "09:00", close: "17:00", isOpen: true },
      tuesday:   { open: "09:00", close: "17:00", isOpen: true },
      wednesday: { open: "09:00", close: "17:00", isOpen: true },
      thursday:  { open: "09:00", close: "17:00", isOpen: true },
      friday:    { open: "09:00", close: "17:00", isOpen: true },
      saturday:  { open: null, close: null, isOpen: false },
      sunday:    { open: null, close: null, isOpen: false },
    },
    holidays: [],
    reminderHoursBefore: 24,
    clinicName: "Test Clinic",
    clinicPhone: "555-0000",
    clinicAddress: "123 Test St",
  });
}

async function clearCollection(collectionName: string): Promise<void> {
  const snap = await db.collection(collectionName).get();
  const batch = db.batch();
  snap.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
}

// ---------- Request factory ----------

/**
 * Builds a minimal mock CallableRequest for the given UID and data payload.
 * Enough for the handler to pass its auth check.
 */
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
        email:           "test@clinic.test",
        email_verified:  true,
      },
    },
    data,
    rawRequest: {} as any, // not used by the handler
    instanceIdToken: undefined,
    app: undefined,
  } as unknown as CallableRequest<unknown>;
}

/** A valid, complete payload for a 09:00 slot on BASE_DATE. */
function validPayload(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    firstName:           "Jane",
    lastName:            "Smith",
    phoneNumber:         "555-9999",
    serviceId:           SERVICE_ID,
    appointmentDateTime: BASE_ISO,
    notes:               "Walk-in patient",
    ...overrides,
  };
}

// ---------- snapToSlot unit tests (pure logic, no emulator) ----------

describe("snapToSlot — slot boundary rounding", () => {
  const toHHmm = (d: Date) =>
    `${d.getUTCHours().toString().padStart(2, "0")}:${d.getUTCMinutes().toString().padStart(2, "0")}`;

  test("rounds DOWN when minutes are less than half a slot (09:07 → 09:00)", () => {
    const input = new Date("2026-09-01T09:07:00.000Z");
    expect(toHHmm(snapToSlot(input, 30))).toBe("09:00");
  });

  test("rounds UP when minutes are more than half a slot (09:17 → 09:30)", () => {
    const input = new Date("2026-09-01T09:17:00.000Z");
    expect(toHHmm(snapToSlot(input, 30))).toBe("09:30");
  });

  test("rounds UP crossing hour boundary (09:46 → 10:00)", () => {
    const input = new Date("2026-09-01T09:46:00.000Z");
    expect(toHHmm(snapToSlot(input, 30))).toBe("10:00");
  });

  test("returns same time when already on a boundary (09:30 → 09:30)", () => {
    const input = new Date("2026-09-01T09:30:00.000Z");
    expect(toHHmm(snapToSlot(input, 30))).toBe("09:30");
  });

  test("exact midpoint (09:15) rounds UP to 09:30", () => {
    // remainder == half — the condition is `remainder < half`, so equals rounds up
    const input = new Date("2026-09-01T09:15:00.000Z");
    expect(toHHmm(snapToSlot(input, 30))).toBe("09:30");
  });

  test("works with 20-minute slot duration (09:07 → 09:00, 09:12 → 09:20)", () => {
    expect(toHHmm(snapToSlot(new Date("2026-09-01T09:07:00.000Z"), 20))).toBe("09:00");
    expect(toHHmm(snapToSlot(new Date("2026-09-01T09:12:00.000Z"), 20))).toBe("09:20");
  });
});

// ---------- Happy path ----------

describe("createWalkInAppointment — happy path", () => {
  test("creates appointment for a valid slot and returns appointmentId + confirmed", async () => {
    const result = await createWalkInAppointmentHandler(
      makeRequest(STAFF_UID, validPayload())
    );

    expect(result.status).toBe("confirmed");
    expect(typeof result.appointmentId).toBe("string");
    expect(result.appointmentId.length).toBeGreaterThan(0);
  });

  test("created document has all required fields with correct values", async () => {
    const result = await createWalkInAppointmentHandler(
      makeRequest(STAFF_UID, validPayload())
    );

    const snap = await db.collection("appointments").doc(result.appointmentId).get();
    expect(snap.exists).toBe(true);

    const data = snap.data()!;

    // Patient-app-owned fields must be null for walk-ins
    expect(data.userId).toBeNull();
    expect(data.userEmail).toBeNull();

    // Walk-in identification fields
    expect(data.bookingSource).toBe("staff_walkin");
    expect(data.createdBy).toBe(STAFF_UID);
    expect(data.status).toBe("confirmed");

    // Payment/reminder defaults
    expect(data.paid).toBe(false);
    expect(data.reminderSent).toBe(false);

    // Patient info — passed through as-is
    expect(data.firstName).toBe("Jane");
    expect(data.lastName).toBe("Smith");
    expect(data.phoneNumber).toBe("555-9999");

    // Server-derived time fields
    expect(data.date).toBe(BASE_DATE);
    expect(data.startTime).toBe("09:00");
    expect(data.endTime).toBe("09:30"); // 30 min service

    // Service linkage
    expect(data.serviceId).toBe(SERVICE_ID);
    expect(data.serviceName).toBe("Cleaning");
    expect(data.reason).toBe("Cleaning"); // legacy field, populated for compat

    // No image
    expect(data.imageUrl).toBeNull();
    expect(data.analysisResults).toBeNull();

    // Timestamps set
    expect(data.createdAt).toBeTruthy();
    expect(data.updatedAt).toBeTruthy();
  });

  test("admin role also succeeds", async () => {
    const result = await createWalkInAppointmentHandler(
      makeRequest(ADMIN_UID, validPayload())
    );
    expect(result.status).toBe("confirmed");
  });

  test("optional fields (notes, imageUrl) accept null/undefined gracefully", async () => {
    const payload = validPayload();
    delete (payload as any).notes;
    delete (payload as any).imageUrl;

    const result = await createWalkInAppointmentHandler(
      makeRequest(STAFF_UID, payload)
    );

    const data = (await db.collection("appointments").doc(result.appointmentId).get()).data()!;
    expect(data.notes).toBeNull();
    expect(data.imageUrl).toBeNull();
  });

  test("imageUrl is stored when provided", async () => {
    const result = await createWalkInAppointmentHandler(
      makeRequest(STAFF_UID, validPayload({ imageUrl: "https://res.cloudinary.com/test/image/upload/v1/photo.jpg" }))
    );

    const data = (await db.collection("appointments").doc(result.appointmentId).get()).data()!;
    expect(data.imageUrl).toBe("https://res.cloudinary.com/test/image/upload/v1/photo.jpg");
  });
});

// ---------- Auth guard ----------

describe("createWalkInAppointment — auth guard", () => {
  test("throws permission-denied when caller is not authenticated", async () => {
    const unauthRequest = {
      auth: null,
      data: validPayload(),
      rawRequest: {},
    } as unknown as CallableRequest<unknown>;

    await expect(
      createWalkInAppointmentHandler(unauthRequest)
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  test("throws permission-denied when caller has no users/{uid} doc", async () => {
    await expect(
      createWalkInAppointmentHandler(makeRequest("nonexistent-uid", validPayload()))
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  test("throws permission-denied when caller role is not staff or admin", async () => {
    // Seed a user with a hypothetical non-staff role
    await db.collection("users").doc(PATIENT_UID).set({
      uid:    PATIENT_UID,
      role:   "patient", // not a valid staff role
      active: true,
    });

    await expect(
      createWalkInAppointmentHandler(makeRequest(PATIENT_UID, validPayload()))
    ).rejects.toMatchObject({ code: "permission-denied" });
  });
});

// ---------- Input validation ----------

describe("createWalkInAppointment — input validation", () => {
  const requiredFields = [
    "firstName",
    "lastName",
    "phoneNumber",
    "serviceId",
    "appointmentDateTime",
  ];

  for (const field of requiredFields) {
    test(`throws invalid-argument when ${field} is missing`, async () => {
      const payload = validPayload();
      delete (payload as any)[field];

      await expect(
        createWalkInAppointmentHandler(makeRequest(STAFF_UID, payload))
      ).rejects.toMatchObject({ code: "invalid-argument" });
    });

    test(`throws invalid-argument when ${field} is empty string`, async () => {
      await expect(
        createWalkInAppointmentHandler(makeRequest(STAFF_UID, validPayload({ [field]: "  " })))
      ).rejects.toMatchObject({ code: "invalid-argument" });
    });
  }

  test("throws invalid-argument when appointmentDateTime is not a valid ISO string", async () => {
    await expect(
      createWalkInAppointmentHandler(
        makeRequest(STAFF_UID, validPayload({ appointmentDateTime: "not-a-date" }))
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  test("throws invalid-argument when appointmentDateTime is a number (wrong type)", async () => {
    await expect(
      createWalkInAppointmentHandler(
        makeRequest(STAFF_UID, validPayload({ appointmentDateTime: 1234567890 }))
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });
});

// ---------- Service lookup ----------

describe("createWalkInAppointment — service lookup", () => {
  test("throws not-found when serviceId does not exist", async () => {
    await expect(
      createWalkInAppointmentHandler(
        makeRequest(STAFF_UID, validPayload({ serviceId: "does-not-exist" }))
      )
    ).rejects.toMatchObject({ code: "not-found" });
  });

  test("throws failed-precondition when service is inactive", async () => {
    await expect(
      createWalkInAppointmentHandler(
        makeRequest(STAFF_UID, validPayload({ serviceId: SERVICE_INACTIVE_ID }))
      )
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });
});

// ---------- Slot conflict (sequential) ----------

describe("createWalkInAppointment — slot conflict (sequential)", () => {
  test("throws already-exists when exact same slot is already booked", async () => {
    // First booking succeeds
    await createWalkInAppointmentHandler(makeRequest(STAFF_UID, validPayload()));

    // Second booking for the exact same slot must fail
    await expect(
      createWalkInAppointmentHandler(makeRequest(STAFF_UID, validPayload()))
    ).rejects.toMatchObject({ code: "already-exists" });
  });

  test("throws already-exists when a non-boundary time snaps into a booked slot", async () => {
    // Book 09:00–09:30 (service is 30 min)
    await createWalkInAppointmentHandler(makeRequest(STAFF_UID, validPayload()));

    // Send 09:10, which snaps DOWN to 09:00 (10 min < half of 30 = 15 → round down).
    // The resulting 09:00–09:30 booking conflicts with the existing one.
    await expect(
      createWalkInAppointmentHandler(
        makeRequest(STAFF_UID, validPayload({ appointmentDateTime: "2026-09-01T09:10:00.000Z" }))
      )
    ).rejects.toMatchObject({ code: "already-exists" });
  });


  test("succeeds for a non-overlapping slot on the same date", async () => {
    // Book 09:00–09:30
    await createWalkInAppointmentHandler(makeRequest(STAFF_UID, validPayload()));

    // Book 09:30–10:00 — immediately after, no overlap
    const result = await createWalkInAppointmentHandler(
      makeRequest(STAFF_UID, validPayload({ appointmentDateTime: "2026-09-01T09:30:00.000Z" }))
    );
    expect(result.status).toBe("confirmed");
  });

  test("succeeds for the same slot on a different date", async () => {
    // Book 09:00–09:30 on BASE_DATE (2026-09-01)
    await createWalkInAppointmentHandler(makeRequest(STAFF_UID, validPayload()));

    // Book the same time on the following day — no conflict
    const result = await createWalkInAppointmentHandler(
      makeRequest(STAFF_UID, validPayload({ appointmentDateTime: "2026-09-02T09:00:00.000Z" }))
    );
    expect(result.status).toBe("confirmed");
  });

  test("cancelled appointment does not block the slot", async () => {
    // Book and then manually cancel (seed a cancelled doc directly)
    await db.collection("appointments").doc("cancelled-appt").set({
      id:                  "cancelled-appt",
      userId:              null,
      userEmail:           null,
      firstName:           "Old",
      lastName:            "Patient",
      phoneNumber:         "000",
      serviceId:           SERVICE_ID,
      serviceName:         "Cleaning",
      reason:              "Cleaning",
      date:                BASE_DATE,
      startTime:           "09:00",
      endTime:             "09:30",
      appointmentDateTime: Timestamp.fromDate(new Date(BASE_ISO)),
      notes:               null,
      imageUrl:            null,
      analysisResults:     null,
      status:              "cancelled", // <-- cancelled — should NOT block the slot
      bookingSource:       "staff_walkin",
      createdBy:           STAFF_UID,
      paid:                false,
      reminderSent:        false,
      createdAt:           Timestamp.now(),
      updatedAt:           Timestamp.now(),
    });

    // The slot at 09:00 should now be free to book
    const result = await createWalkInAppointmentHandler(
      makeRequest(STAFF_UID, validPayload())
    );
    expect(result.status).toBe("confirmed");
  });
});

// ---------- Concurrency test — the critical double-booking proof ----------

describe("createWalkInAppointment — concurrency (double-booking prevention)", () => {
  /**
   * This test fires two simultaneous requests for the exact same time slot
   * and asserts that the Firestore transaction ensures exactly one succeeds
   * and exactly one fails with "already-exists".
   *
   * Note on Node.js concurrency: JavaScript is single-threaded, but the two
   * calls below yield to the event loop at each `await` point — including the
   * Firestore network I/O to the emulator — which means the two transaction
   * executions genuinely interleave at the I/O boundaries.
   *
   * In a real distributed environment (two separate Cloud Function instances)
   * Firestore's optimistic-concurrency transaction mechanism provides the same
   * guarantee. This test validates the logical correctness of the transaction
   * pattern; the emulator's single-node Firestore faithfully enforces the same
   * read-check-then-write transaction semantics.
   */
  test(
    "only one of two simultaneous requests for the same slot succeeds",
    async () => {
      // Fire both requests at the same time — do NOT await individually
      const [r1, r2] = await Promise.allSettled([
        createWalkInAppointmentHandler(makeRequest(STAFF_UID, validPayload())),
        createWalkInAppointmentHandler(makeRequest(ADMIN_UID, validPayload())),
      ]);

      const fulfilled = [r1, r2].filter((r) => r.status === "fulfilled");
      const rejected  = [r1, r2].filter((r) => r.status === "rejected");

      // Exactly one must have succeeded
      expect(fulfilled).toHaveLength(1);

      // Exactly one must have failed with the correct error code
      expect(rejected).toHaveLength(1);
      const rejectedReason = (rejected[0] as PromiseRejectedResult).reason as { code: string; message: string };
      expect(rejectedReason.code).toBe("already-exists");
      expect(rejectedReason.message).toContain("Slot no longer available");

      // Verify exactly one appointment document was written to Firestore
      const snap = await db
        .collection("appointments")
        .where("date", "==", BASE_DATE)
        .where("startTime", "==", "09:00")
        .get();

      expect(snap.size).toBe(1);
      expect(snap.docs[0].data().status).toBe("confirmed");
      expect(snap.docs[0].data().bookingSource).toBe("staff_walkin");
    },
    30_000 // generous timeout for emulator round-trips
  );

  test(
    "three concurrent requests for the same slot: exactly one succeeds",
    async () => {
      const results = await Promise.allSettled([
        createWalkInAppointmentHandler(makeRequest(STAFF_UID, validPayload())),
        createWalkInAppointmentHandler(makeRequest(ADMIN_UID, validPayload())),
        createWalkInAppointmentHandler(makeRequest(STAFF_UID, validPayload())),
      ]);

      const fulfilled = results.filter((r) => r.status === "fulfilled");
      const rejected  = results.filter((r) => r.status === "rejected");

      expect(fulfilled).toHaveLength(1);
      expect(rejected).toHaveLength(2);

      // Every rejection must be the correct error
      for (const r of rejected) {
        expect((r as PromiseRejectedResult).reason.code).toBe("already-exists");
      }

      // Still exactly one document in Firestore
      const snap = await db
        .collection("appointments")
        .where("date", "==", BASE_DATE)
        .where("startTime", "==", "09:00")
        .get();

      expect(snap.size).toBe(1);
    },
    30_000
  );

  test(
    "two concurrent requests for DIFFERENT slots both succeed",
    async () => {
      const [r1, r2] = await Promise.allSettled([
        createWalkInAppointmentHandler(
          makeRequest(STAFF_UID, validPayload({ appointmentDateTime: "2026-09-01T09:00:00.000Z" }))
        ),
        createWalkInAppointmentHandler(
          makeRequest(ADMIN_UID, validPayload({ appointmentDateTime: "2026-09-01T10:00:00.000Z" }))
        ),
      ]);

      expect(r1.status).toBe("fulfilled");
      expect(r2.status).toBe("fulfilled");

      // Two distinct documents created
      const snap = await db
        .collection("appointments")
        .where("date", "==", BASE_DATE)
        .get();

      expect(snap.size).toBe(2);
    },
    30_000
  );
});
