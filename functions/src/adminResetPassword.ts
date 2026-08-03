/**
 * adminResetPassword.ts
 * Dental Clinic Staff/Admin App — Cloud Functions
 *
 * Callable Cloud Function allowing Administrators to reset the password for
 * any staff or user account directly using the Firebase Admin SDK.
 */

import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import * as logger from "firebase-functions/logger";
import { UserDocument } from "./schema-types";

export interface AdminResetPasswordInput {
  targetUid: string;
  newPassword: string;
}

export interface AdminResetPasswordOutput {
  targetUid: string;
  status: "updated";
}

function validateInput(data: unknown): AdminResetPasswordInput {
  if (!data || typeof data !== "object") {
    throw new HttpsError("invalid-argument", "Input data must be an object");
  }

  const d = data as Record<string, unknown>;

  if (typeof d.targetUid !== "string" || d.targetUid.trim() === "") {
    throw new HttpsError("invalid-argument", "Target user ID is required");
  }

  if (typeof d.newPassword !== "string" || d.newPassword.length < 8) {
    throw new HttpsError(
      "invalid-argument",
      "New password must be at least 8 characters long"
    );
  }

  return {
    targetUid: d.targetUid.trim(),
    newPassword: d.newPassword,
  };
}

export async function adminResetPasswordHandler(
  request: CallableRequest<unknown>
): Promise<AdminResetPasswordOutput> {
  const db = getFirestore();
  const auth = getAuth();

  // Step 1: Auth guard — caller must be an admin
  if (!request.auth) {
    throw new HttpsError("permission-denied", "Caller must be authenticated");
  }

  const callerUid = request.auth.uid;
  const callerSnap = await db.collection("users").doc(callerUid).get();

  if (!callerSnap.exists) {
    throw new HttpsError("permission-denied", "Caller user profile not found");
  }

  const callerData = callerSnap.data() as UserDocument;
  if (callerData.role !== "admin") {
    throw new HttpsError(
      "permission-denied",
      "Only administrators can reset passwords"
    );
  }

  // Step 2: Input validation
  const input = validateInput(request.data);

  // Step 3: Verify target user exists in Firestore
  const targetSnap = await db.collection("users").doc(input.targetUid).get();
  if (!targetSnap.exists) {
    throw new HttpsError(
      "not-found",
      `Target user ${input.targetUid} not found`
    );
  }

  // Step 4: Reset password via Firebase Admin Auth SDK
  try {
    await auth.updateUser(input.targetUid, {
      password: input.newPassword,
    });
  } catch (error: any) {
    logger.error("adminResetPassword: Auth update failed", error);
    if (error.code === "auth/user-not-found") {
      throw new HttpsError("not-found", "Auth user not found");
    }
    if (error.code === "auth/weak-password") {
      throw new HttpsError("invalid-argument", "Password is too weak");
    }
    throw new HttpsError(
      "internal",
      `Failed to reset password: ${error.message || error}`
    );
  }

  // Step 5: Write activity audit log
  try {
    await db.collection("activity_logs").add({
      action: "STAFF_PASSWORD_RESET_BY_ADMIN",
      performedBy: callerUid,
      targetUid: input.targetUid,
      targetEmail: (targetSnap.data() as UserDocument).email ?? null,
      timestamp: FieldValue.serverTimestamp(),
    });
  } catch (error: any) {
    logger.warn("adminResetPassword: Audit log write failed", error);
  }

  logger.info("adminResetPassword: Password successfully reset", {
    targetUid: input.targetUid,
    callerUid,
  });

  return {
    targetUid: input.targetUid,
    status: "updated",
  };
}

export const adminResetPassword = onCall(
  { cors: true, maxInstances: 10 },
  adminResetPasswordHandler
);
