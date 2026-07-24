/**
 * generateSsoToken.ts
 * Dental Clinic Staff/Admin App — Cloud Functions
 *
 * Callable Cloud Function invoked by the mobile launcher app (or client)
 * to generate a 5-minute single-use SSO token for Web Portal handoff.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { randomUUID } from "crypto";

interface GenerateSsoTokenData {
  targetPath?: string;
}

interface GenerateSsoTokenResponse {
  ssoToken: string;
  expiresAt: string;
  targetPath: string;
}

export const generateSsoToken = onCall<GenerateSsoTokenData>(
  { cors: true },
  async (request): Promise<GenerateSsoTokenResponse> => {
    // 1. Verify caller authentication
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "The function must be called by an authenticated user."
      );
    }

    const uid = request.auth.uid;
    const targetPath = request.data?.targetPath && request.data.targetPath.startsWith("/patient")
      ? request.data.targetPath
      : "/patient/dashboard";

    const db = getFirestore();
    const ssoToken = `sso_${randomUUID().replace(/-/g, "")}`;
    const now = new Date();
    const expiresAtDate = new Date(now.getTime() + 5 * 60 * 1000); // 5-minute TTL

    const tokenDocRef = db.collection("sso_tokens").doc(ssoToken);

    await tokenDocRef.set({
      uid: uid,
      used: false,
      targetPath: targetPath,
      createdAt: FieldValue.serverTimestamp(),
      expiresAt: Timestamp.fromDate(expiresAtDate),
    });

    return {
      ssoToken: ssoToken,
      expiresAt: expiresAtDate.toISOString(),
      targetPath: targetPath,
    };
  }
);
