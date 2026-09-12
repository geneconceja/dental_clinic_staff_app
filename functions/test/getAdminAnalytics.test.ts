/**
 * functions/test/getAdminAnalytics.test.ts
 *
 * Integration tests for the getAdminAnalytics Cloud Function handler.
 * Runs directly against the Firebase Firestore emulator — no HTTPS overhead.
 *
 * Run (with emulators already started):
 *   cd functions && npm test -- --testPathPattern=getAdminAnalytics
 */

import { initializeApp, getApps, App } from "firebase-admin/app";
import { getFirestore, Firestore, Timestamp } from "firebase-admin/firestore";
import { CallableRequest } from "firebase-functions/v2/https";

// ---------- Emulator setup (must be before any firebase-admin import) ----------

process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8085";
process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";

const PROJECT_ID = "oralscope-78cda";

let adminApp: App;
let db: Firestore;

// Import handler AFTER env vars are set
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { getAdminAnalyticsHandler } = require("../src/getAdminAnalytics") as {
  getAdminAnalyticsHandler: (
    req: CallableRequest<{ referenceDate?: string }>
  ) => Promise<import("../src/getAdminAnalytics").AdminAnalyticsResult>;
};

// ---------- Constants ----------

const ADMIN_UID = "analytics-test-admin";
const STAFF_UID = "analytics-test-staff";

/** Builds a minimal CallableRequest for the handler under test */
function makeRequest(
  uid: string,
  role: string,
  data: { referenceDate?: string } = {}
): CallableRequest<{ referenceDate?: string }> {
  return {
    auth: { uid, token: { role } } as unknown as CallableRequest<unknown>["auth"],
    data,
    acceptsStreaming: false,
    rawRequest: {} as unknown as CallableRequest<unknown>["rawRequest"],
  };
}

/** Builds a Firestore appointment document object */
function makeAppointment(
  overrides: Partial<{
    appointmentDateTime: Date;
    status: string;
    serviceName: string;
    price: number;
    paid: boolean;
    isFirstVisit: boolean;
  }> = {}
): Record<string, unknown> {
  const doc: Record<string, unknown> = {
    userId: null,
    userEmail: null,
    firstName: "Test",
    lastName: "Patient",
    phoneNumber: "09000000000",
    reason: "Checkup",
    date: "2026-09-01",
    appointmentDateTime: Timestamp.fromDate(
      overrides.appointmentDateTime ?? new Date("2026-09-12T09:00:00")
    ),
    startTime: "09:00",
    endTime:   "09:30",
    notes: null,
    imageUrl: null,
    analysisResults: null,
    status:      overrides.status      ?? "confirmed",
    serviceName: overrides.serviceName ?? "Teeth Cleaning",
    serviceId:   "service-cleaning",
    bookingSource: "staff_walkin",
    createdBy: STAFF_UID,
    paid:  overrides.paid  ?? false,
    reminderSent: false,
    price: overrides.price ?? 500,
    createdAt: Timestamp.now(),
  };
  // Only include optional analytics fields when explicitly set — Firestore rejects explicit `undefined`
  if (overrides.isFirstVisit !== undefined) {
    doc["isFirstVisit"] = overrides.isFirstVisit;
  }
  return doc;
}

// ---------- Setup / teardown ----------

beforeAll(async () => {
  if (getApps().length === 0) {
    adminApp = initializeApp({ projectId: PROJECT_ID });
  }
  db = getFirestore();

  // Seed admin and staff users
  await db.collection("users").doc(ADMIN_UID).set({
    uid: ADMIN_UID, role: "admin", name: "Test Admin",
    email: "admin@test.com", phone: "0900000001", active: true,
    createdAt: Timestamp.now(),
  });
  await db.collection("users").doc(STAFF_UID).set({
    uid: STAFF_UID, role: "staff", name: "Test Staff",
    email: "staff@test.com", phone: "0900000002", active: true,
    createdAt: Timestamp.now(),
  });
});

afterEach(async () => {
  // Clean appointments between tests
  const snap = await db.collection("appointments").get();
  const deletes = snap.docs.map((d) => d.ref.delete());
  await Promise.all(deletes);
});

afterAll(async () => {
  await db.collection("users").doc(ADMIN_UID).delete();
  await db.collection("users").doc(STAFF_UID).delete();
});

// ---------- Auth guard tests ----------

describe("auth guards", () => {
  it("throws unauthenticated when no auth", async () => {
    const req = { auth: null, data: {}, rawRequest: {} } as unknown as CallableRequest<{}>;
    await expect(getAdminAnalyticsHandler(req)).rejects.toMatchObject({ code: "unauthenticated" });
  });

  it("throws permission-denied for staff role", async () => {
    await expect(
      getAdminAnalyticsHandler(makeRequest(STAFF_UID, "staff"))
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("throws invalid-argument for a bad referenceDate", async () => {
    await expect(
      getAdminAnalyticsHandler(makeRequest(ADMIN_UID, "admin", { referenceDate: "not-a-date" }))
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });
});

// ---------- Metric 1: Today's stats ----------

describe("metric 1 — today stats", () => {
  const REF = "2026-09-12";

  it("counts zero when no appointments today", async () => {
    const result = await getAdminAnalyticsHandler(
      makeRequest(ADMIN_UID, "admin", { referenceDate: REF })
    );
    expect(result.today.total).toBe(0);
    expect(result.today.upcoming).toBe(0);
    expect(result.today.completed).toBe(0);
  });

  it("correctly buckets today appointments by status", async () => {
    const today = new Date("2026-09-12T09:00:00");
    await db.collection("appointments").add(makeAppointment({ appointmentDateTime: today, status: "confirmed" }));
    await db.collection("appointments").add(makeAppointment({ appointmentDateTime: today, status: "completed" }));
    await db.collection("appointments").add(makeAppointment({ appointmentDateTime: today, status: "no-show" }));
    // This one is in a different month — should NOT appear
    await db.collection("appointments").add(
      makeAppointment({ appointmentDateTime: new Date("2026-08-12T09:00:00"), status: "completed" })
    );

    const result = await getAdminAnalyticsHandler(
      makeRequest(ADMIN_UID, "admin", { referenceDate: REF })
    );

    expect(result.today.total).toBe(3);
    expect(result.today.upcoming).toBe(1);
    expect(result.today.completed).toBe(1);
    expect(result.today.noShow).toBe(1);
  });
});

// ---------- Metric 2: Weekly trend + month total ----------

describe("metric 2 — weekly trend & month total", () => {
  it("returns 7 entries in weeklyTrend (Mon–Sun)", async () => {
    const result = await getAdminAnalyticsHandler(
      makeRequest(ADMIN_UID, "admin", { referenceDate: "2026-09-12" })
    );
    expect(result.weeklyTrend).toHaveLength(7);
    // 2026-09-12 is a Saturday — week starts Monday 2026-09-07
    expect(result.weeklyTrend[0].date).toBe("2026-09-07");
    expect(result.weeklyTrend[6].date).toBe("2026-09-13");
  });

  it("counts appointments on the correct day in weeklyTrend", async () => {
    // Tuesday 2026-09-08
    await db.collection("appointments").add(
      makeAppointment({ appointmentDateTime: new Date("2026-09-08T10:00:00") })
    );
    await db.collection("appointments").add(
      makeAppointment({ appointmentDateTime: new Date("2026-09-08T14:00:00") })
    );

    const result = await getAdminAnalyticsHandler(
      makeRequest(ADMIN_UID, "admin", { referenceDate: "2026-09-12" })
    );

    const tuesday = result.weeklyTrend.find((d) => d.date === "2026-09-08");
    expect(tuesday?.count).toBe(2);
    expect(result.monthTotal).toBe(2);
  });
});

// ---------- Metric 3: No-show rate ----------

describe("metric 3 — no-show rate", () => {
  it("returns 0 when there are no finalised appointments", async () => {
    await db.collection("appointments").add(
      makeAppointment({ status: "confirmed" })
    );
    const result = await getAdminAnalyticsHandler(
      makeRequest(ADMIN_UID, "admin", { referenceDate: "2026-09-12" })
    );
    expect(result.noShowRate).toBe(0);
  });

  it("calculates no-show rate correctly", async () => {
    // 2 no-shows out of 4 finalised = 50%
    await db.collection("appointments").add(makeAppointment({ status: "no-show" }));
    await db.collection("appointments").add(makeAppointment({ status: "no-show" }));
    await db.collection("appointments").add(makeAppointment({ status: "completed" }));
    await db.collection("appointments").add(makeAppointment({ status: "cancelled" }));

    const result = await getAdminAnalyticsHandler(
      makeRequest(ADMIN_UID, "admin", { referenceDate: "2026-09-12" })
    );
    expect(result.noShowRate).toBe(50);
  });
});

// ---------- Metric 4: New vs returning ----------

describe("metric 4 — new vs returning patients", () => {
  it("counts new and returning patients correctly", async () => {
    await db.collection("appointments").add(
      makeAppointment({ status: "completed", isFirstVisit: true })
    );
    await db.collection("appointments").add(
      makeAppointment({ status: "completed", isFirstVisit: true })
    );
    await db.collection("appointments").add(
      makeAppointment({ status: "completed", isFirstVisit: false })
    );
    // Completed but no isFirstVisit flag (legacy) — should be excluded from split
    await db.collection("appointments").add(
      makeAppointment({ status: "completed" })
    );

    const result = await getAdminAnalyticsHandler(
      makeRequest(ADMIN_UID, "admin", { referenceDate: "2026-09-12" })
    );
    expect(result.newPatients).toBe(2);
    expect(result.returningPatients).toBe(1);
  });
});

// ---------- Metric 5: Revenue ----------

describe("metric 5 — revenue", () => {
  it("sums revenue only from completed + paid appointments", async () => {
    // Should count (completed + paid)
    await db.collection("appointments").add(
      makeAppointment({ status: "completed", paid: true, price: 500 })
    );
    await db.collection("appointments").add(
      makeAppointment({ status: "completed", paid: true, price: 800 })
    );
    // Should NOT count (completed but unpaid)
    await db.collection("appointments").add(
      makeAppointment({ status: "completed", paid: false, price: 300 })
    );
    // Should NOT count (cancelled)
    await db.collection("appointments").add(
      makeAppointment({ status: "cancelled", paid: true, price: 200 })
    );

    const result = await getAdminAnalyticsHandler(
      makeRequest(ADMIN_UID, "admin", { referenceDate: "2026-09-12" })
    );
    expect(result.revenueThisMonth).toBe(1300);
  });

  it("produces weekly revenue buckets", async () => {
    // Week 1: Sep 1–7 → ₱500
    await db.collection("appointments").add(
      makeAppointment({
        appointmentDateTime: new Date("2026-09-01T10:00:00"),
        status: "completed", paid: true, price: 500,
      })
    );
    // Week 2: Sep 8–14 → ₱800
    await db.collection("appointments").add(
      makeAppointment({
        appointmentDateTime: new Date("2026-09-10T10:00:00"),
        status: "completed", paid: true, price: 800,
      })
    );

    const result = await getAdminAnalyticsHandler(
      makeRequest(ADMIN_UID, "admin", { referenceDate: "2026-09-12" })
    );

    expect(result.weeklyRevenue.length).toBeGreaterThanOrEqual(2);
    const week1 = result.weeklyRevenue.find((w) => w.weekLabel === "Week 1");
    const week2 = result.weeklyRevenue.find((w) => w.weekLabel === "Week 2");
    expect(week1?.revenue).toBe(500);
    expect(week2?.revenue).toBe(800);
  });
});

// ---------- Metric 6: Top treatments ----------

describe("metric 6 — top treatments", () => {
  it("returns top 5 services sorted by count descending", async () => {
    const services = ["Cleaning", "Extraction", "Filling", "Whitening", "Braces", "Checkup"];
    // Cleaning: 4, Extraction: 3, Filling: 2, Whitening: 1, Braces: 1, Checkup: 1
    for (let i = 0; i < 4; i++)
      await db.collection("appointments").add(makeAppointment({ serviceName: "Cleaning" }));
    for (let i = 0; i < 3; i++)
      await db.collection("appointments").add(makeAppointment({ serviceName: "Extraction" }));
    for (let i = 0; i < 2; i++)
      await db.collection("appointments").add(makeAppointment({ serviceName: "Filling" }));
    await db.collection("appointments").add(makeAppointment({ serviceName: "Whitening" }));
    await db.collection("appointments").add(makeAppointment({ serviceName: "Braces" }));
    await db.collection("appointments").add(makeAppointment({ serviceName: "Checkup" }));

    const result = await getAdminAnalyticsHandler(
      makeRequest(ADMIN_UID, "admin", { referenceDate: "2026-09-12" })
    );

    expect(result.topTreatments).toHaveLength(5);
    expect(result.topTreatments[0].serviceName).toBe("Cleaning");
    expect(result.topTreatments[0].count).toBe(4);
    expect(result.topTreatments[1].serviceName).toBe("Extraction");
  });

  it("returns fewer than 5 when fewer services exist", async () => {
    await db.collection("appointments").add(makeAppointment({ serviceName: "Cleaning" }));
    await db.collection("appointments").add(makeAppointment({ serviceName: "Extraction" }));

    const result = await getAdminAnalyticsHandler(
      makeRequest(ADMIN_UID, "admin", { referenceDate: "2026-09-12" })
    );
    expect(result.topTreatments.length).toBeLessThanOrEqual(2);
  });
});
