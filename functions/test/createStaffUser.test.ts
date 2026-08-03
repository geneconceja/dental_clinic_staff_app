/**
 * functions/test/createStaffUser.test.ts
 *
 * Integration tests for the createStaffUser Cloud Function handler.
 * Runs against the Firebase emulator suite (Firestore + Auth emulators).
 */

import { initializeApp, getApps, App } from "firebase-admin/app";
import { getFirestore, Firestore, Timestamp } from "firebase-admin/firestore";
import { CallableRequest } from "firebase-functions/v2/https";



const PROJECT_ID = "oralscope-78cda";

let adminApp: App;
let db: Firestore;

// Import handler AFTER env setup
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { createStaffUserHandler } = require("../src/createStaffUser") as {
  createStaffUserHandler: (
    req: CallableRequest<unknown>
  ) => Promise<{ uid: string; status: string }>;
};

const ADMIN_UID = "test-create-admin-uid";
const STAFF_UID = "test-create-staff-uid";

beforeAll(async () => {
  if (getApps().length === 0) {
    adminApp = initializeApp({ projectId: PROJECT_ID });
  } else {
    adminApp = getApps()[0]!;
  }
  db = getFirestore(adminApp);
});

beforeEach(async () => {
  await seedCallerUsers();
});

afterEach(async () => {
  await clearCollection("users");
  await clearCollection("activity_logs");
});

async function seedCallerUsers(): Promise<void> {
  const batch = db.batch();

  batch.set(db.collection("users").doc(ADMIN_UID), {
    uid: ADMIN_UID,
    role: "admin",
    name: "Admin User",
    email: "admin-create@clinic.test",
    phone: "555-0100",
    active: true,
    createdAt: Timestamp.now(),
  });

  batch.set(db.collection("users").doc(STAFF_UID), {
    uid: STAFF_UID,
    role: "staff",
    name: "Staff User",
    email: "staff-create@clinic.test",
    phone: "555-0101",
    active: true,
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

function makeRequest(callerUid: string, data: unknown): CallableRequest<unknown> {
  return {
    auth: {
      uid: callerUid,
      token: {
        uid: callerUid,
        aud: PROJECT_ID,
        auth_time: Date.now() / 1000,
        exp: Date.now() / 1000 + 3600,
        firebase: { identities: {}, sign_in_provider: "custom" },
        iat: Date.now() / 1000,
        iss: `https://securetoken.google.com/${PROJECT_ID}`,
        sub: callerUid,
        email: "caller@clinic.test",
        email_verified: true,
      },
    },
    data,
    rawRequest: {} as any,
    instanceIdToken: undefined,
    app: undefined,
  } as unknown as CallableRequest<unknown>;
}

describe("createStaffUser — permissions and validations", () => {
  test("throws permission-denied if caller is unauthenticated", async () => {
    const unauthReq = {
      auth: null,
      data: {
        email: "newstaff@clinic.test",
        password: "Password123!",
        name: "New Staff",
        phone: "555-9999",
        role: "staff",
      },
    } as unknown as CallableRequest<unknown>;

    await expect(createStaffUserHandler(unauthReq)).rejects.toMatchObject({
      code: "permission-denied",
    });
  });

  test("throws permission-denied if caller is a regular staff user", async () => {
    const req = makeRequest(STAFF_UID, {
      email: "newstaff@clinic.test",
      password: "Password123!",
      name: "New Staff",
      phone: "555-9999",
      role: "staff",
    });

    await expect(createStaffUserHandler(req)).rejects.toMatchObject({
      code: "permission-denied",
    });
  });

  test("throws invalid-argument for weak password", async () => {
    const req = makeRequest(ADMIN_UID, {
      email: "newstaff@clinic.test",
      password: "123", // short password
      name: "New Staff",
      phone: "555-9999",
      role: "staff",
    });

    await expect(createStaffUserHandler(req)).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  test("throws invalid-argument for missing name or email", async () => {
    const req = makeRequest(ADMIN_UID, {
      email: "notanemail",
      password: "Password123!",
      name: "",
      phone: "555-9999",
      role: "staff",
    });

    await expect(createStaffUserHandler(req)).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });
});

describe("createStaffUser — happy path", () => {
  test("admin can create a new staff account successfully", async () => {
    const newEmail = `staff-${Date.now()}@clinic.test`;
    const req = makeRequest(ADMIN_UID, {
      email: newEmail,
      password: "Password123!",
      name: "Dr. Jane Smith",
      phone: "555-7788",
      role: "staff",
    });

    const res = await createStaffUserHandler(req);
    expect(res.status).toBe("created");
    expect(res.uid).toBeDefined();

    // Verify Firestore users/{uid} document
    const userDoc = await db.collection("users").doc(res.uid).get();
    expect(userDoc.exists).toBe(true);
    expect(userDoc.data()?.email).toBe(newEmail);
    expect(userDoc.data()?.role).toBe("staff");
    expect(userDoc.data()?.name).toBe("Dr. Jane Smith");
    expect(userDoc.data()?.active).toBe(true);

    // Verify activity log
    const logs = await db
      .collection("activity_logs")
      .where("action", "==", "STAFF_USER_CREATED")
      .where("targetUid", "==", res.uid)
      .get();
    expect(logs.docs.length).toBe(1);
    expect(logs.docs[0].data().performedBy).toBe(ADMIN_UID);
  });
});
