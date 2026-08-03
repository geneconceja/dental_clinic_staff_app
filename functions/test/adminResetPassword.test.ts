/**
 * functions/test/adminResetPassword.test.ts
 *
 * Integration tests for the adminResetPassword Cloud Function handler.
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
const { adminResetPasswordHandler } = require("../src/adminResetPassword") as {
  adminResetPasswordHandler: (
    req: CallableRequest<unknown>
  ) => Promise<{ targetUid: string; status: string }>;
};

const ADMIN_UID = "test-reset-admin-uid";
const STAFF_UID = "test-reset-staff-uid";
const TARGET_UID = "test-reset-target-uid";

beforeAll(async () => {
  if (getApps().length === 0) {
    adminApp = initializeApp({ projectId: PROJECT_ID });
  } else {
    adminApp = getApps()[0]!;
  }
  db = getFirestore(adminApp);
});

beforeEach(async () => {
  await seedUsers();
});

afterEach(async () => {
  await clearCollection("users");
  await clearCollection("activity_logs");
});

async function seedUsers(): Promise<void> {
  const batch = db.batch();

  batch.set(db.collection("users").doc(ADMIN_UID), {
    uid: ADMIN_UID,
    role: "admin",
    name: "Admin User",
    email: "admin-reset@clinic.test",
    phone: "555-0100",
    active: true,
    createdAt: Timestamp.now(),
  });

  batch.set(db.collection("users").doc(STAFF_UID), {
    uid: STAFF_UID,
    role: "staff",
    name: "Staff User",
    email: "staff-reset@clinic.test",
    phone: "555-0101",
    active: true,
    createdAt: Timestamp.now(),
  });

  batch.set(db.collection("users").doc(TARGET_UID), {
    uid: TARGET_UID,
    role: "staff",
    name: "Target Staff User",
    email: "target-reset@clinic.test",
    phone: "555-0102",
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

describe("adminResetPassword — permissions and validations", () => {
  test("throws permission-denied if caller is unauthenticated", async () => {
    const unauthReq = {
      auth: null,
      data: { targetUid: TARGET_UID, newPassword: "NewPassword123!" },
    } as unknown as CallableRequest<unknown>;

    await expect(adminResetPasswordHandler(unauthReq)).rejects.toMatchObject({
      code: "permission-denied",
    });
  });

  test("throws permission-denied if caller is a regular staff user", async () => {
    const req = makeRequest(STAFF_UID, {
      targetUid: TARGET_UID,
      newPassword: "NewPassword123!",
    });

    await expect(adminResetPasswordHandler(req)).rejects.toMatchObject({
      code: "permission-denied",
    });
  });

  test("throws invalid-argument for short password", async () => {
    const req = makeRequest(ADMIN_UID, {
      targetUid: TARGET_UID,
      newPassword: "123", // short password
    });

    await expect(adminResetPasswordHandler(req)).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  test("throws not-found if target UID does not exist in Firestore", async () => {
    const req = makeRequest(ADMIN_UID, {
      targetUid: "non-existent-uid",
      newPassword: "NewPassword123!",
    });

    await expect(adminResetPasswordHandler(req)).rejects.toMatchObject({
      code: "not-found",
    });
  });
});

describe("adminResetPassword — happy path", () => {
  test("admin can reset a target staff member's password successfully", async () => {
    // Seed an Auth user in the emulator so auth.updateUser() has a real record
    const { getAuth } = require("firebase-admin/auth");
    const auth = getAuth();
    await auth.createUser({
      uid: TARGET_UID,
      email: "target-reset@clinic.test",
      password: "OriginalPass123!",
    });

    const req = makeRequest(ADMIN_UID, {
      targetUid: TARGET_UID,
      newPassword: "NewPassword456!",
    });

    const res = await adminResetPasswordHandler(req);
    expect(res.status).toBe("updated");
    expect(res.targetUid).toBe(TARGET_UID);

    // Verify audit log entry was written
    const logs = await db
      .collection("activity_logs")
      .where("action", "==", "STAFF_PASSWORD_RESET_BY_ADMIN")
      .where("targetUid", "==", TARGET_UID)
      .get();
    expect(logs.docs.length).toBe(1);
    expect(logs.docs[0].data().performedBy).toBe(ADMIN_UID);

    // Cleanup Auth user created for this test
    await auth.deleteUser(TARGET_UID).catch(() => {});
  });
});
