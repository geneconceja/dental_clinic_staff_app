/**
 * createStaffUser.ts
 * Dental Clinic Staff/Admin App — Cloud Functions
 *
 * Callable Cloud Function allowing Admin users to create new staff or admin
 * accounts. Uses Firebase Admin SDK to create the Firebase Auth user and seed
 * the corresponding users/{uid} Firestore document without interrupting the
 * active Admin auth session on the client.
 */

import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import * as logger from "firebase-functions/logger";
import { UserDocument, StaffRole } from "./schema-types";

export interface CreateStaffUserInput {
  email: string;
  password: string;
  name: string;
  phone: string;
  role: StaffRole;
}

export interface CreateStaffUserOutput {
  uid: string;
  status: "created";
}

function validateInput(data: unknown): CreateStaffUserInput {
  if (!data || typeof data !== "object") {
    throw new HttpsError("invalid-argument", "Input data must be an object");
  }

  const d = data as Record<string, unknown>;

  if (typeof d.email !== "string" || !d.email.includes("@")) {
    throw new HttpsError("invalid-argument", "Valid email address is required");
  }

  if (typeof d.password !== "string" || d.password.length < 8) {
    throw new HttpsError(
      "invalid-argument",
      "Password must be at least 8 characters long"
    );
  }

  if (typeof d.name !== "string" || d.name.trim() === "") {
    throw new HttpsError("invalid-argument", "Name is required");
  }

  if (typeof d.phone !== "string" || d.phone.trim() === "") {
    throw new HttpsError("invalid-argument", "Phone number is required");
  }

  if (typeof d.role !== "string" || !["staff", "admin"].includes(d.role)) {
    throw new HttpsError("invalid-argument", "Role must be 'staff' or 'admin'");
  }

  return {
    email: d.email.trim().toLowerCase(),
    password: d.password,
    name: d.name.trim(),
    phone: d.phone.trim(),
    role: d.role as StaffRole,
  };
}

export async function createStaffUserHandler(
  request: CallableRequest<unknown>
): Promise<CreateStaffUserOutput> {
  const db = getFirestore();
  const auth = getAuth();

  // Step 1: Auth guard — caller must be authenticated & an admin
  if (!request.auth) {
    throw new HttpsError("permission-denied", "Caller must be authenticated");
  }

  const callerUid = request.auth.uid;
  const callerDocSnap = await db.collection("users").doc(callerUid).get();

  if (!callerDocSnap.exists) {
    throw new HttpsError(
      "permission-denied",
      "Caller user profile not found"
    );
  }

  const callerData = callerDocSnap.data() as UserDocument;
  if (callerData.role !== "admin") {
    throw new HttpsError(
      "permission-denied",
      "Only administrators can create staff accounts"
    );
  }

  // Step 2: Validate input
  const input = validateInput(request.data);

  // Step 3: Create Firebase Auth User
  let userRecord;
  try {
    userRecord = await auth.createUser({
      email: input.email,
      password: input.password,
      displayName: input.name,
    });
  } catch (error: any) {
    logger.error("createStaffUser: Failed to create Auth user", error);
    if (error.code === "auth/email-already-exists") {
      throw new HttpsError(
        "already-exists",
        "The email address is already registered"
      );
    }
    if (error.code === "auth/invalid-email") {
      throw new HttpsError("invalid-argument", "The email address is invalid");
    }
    if (error.code === "auth/weak-password") {
      throw new HttpsError("invalid-argument", "The password is too weak");
    }
    throw new HttpsError(
      "internal",
      `Failed to create auth account: ${error.message || error}`
    );
  }

  // Step 4: Write users/{uid} document in Firestore
  const newStaffDoc: UserDocument = {
    uid: userRecord.uid,
    role: input.role,
    name: input.name,
    email: input.email,
    phone: input.phone,
    active: true,
    createdAt: FieldValue.serverTimestamp() as any,
  };

  // Step 4a: Write user profile (critical — throw on failure)
  try {
    await db.collection("users").doc(userRecord.uid).set(newStaffDoc);
  } catch (error: any) {
    logger.error("createStaffUser: Firestore profile write failed", error);
    throw new HttpsError(
      "internal",
      "Failed to write user profile to database"
    );
  }

  // Step 4b: Audit log (non-critical — warn on failure, do not surface to client)
  try {
    await db.collection("activity_logs").add({
      action: "STAFF_USER_CREATED",
      performedBy: callerUid,
      targetUid: userRecord.uid,
      targetEmail: input.email,
      targetRole: input.role,
      timestamp: FieldValue.serverTimestamp(),
    });
  } catch (error: any) {
    logger.warn("createStaffUser: Audit log write failed", error);
  }

  logger.info("createStaffUser: Successfully created user", {
    newUid: userRecord.uid,
    role: input.role,
    callerUid,
  });

  return {
    uid: userRecord.uid,
    status: "created",
  };
}

export const createStaffUser = onCall(
  { cors: true, maxInstances: 10 },
  createStaffUserHandler
);
