/**
 * consumeSsoToken.ts
 * Dental Clinic Staff/Admin App — Cloud Functions
 *
 * Callable Cloud Function invoked by the Web app upon receiving a mobile
 * SSO token handoff link (/#/sso?token=sso_code_xyz123).
 * Validates token expiration & atomic single-use status, marks token used,
 * and returns a Firebase Custom Auth Token for web client sign-in.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";

interface ConsumeSsoTokenData {
  ssoToken: string;
}

interface ConsumeSsoTokenResponse {
  customToken: string;
  targetPath: string;
}

export const consumeSsoToken = onCall<ConsumeSsoTokenData>(
  { cors: [/localhost/, /127\.0\.0\.1/, "*"] },
  async (request): Promise<ConsumeSsoTokenResponse> => {
    const ssoToken = request.data?.ssoToken;
    if (!ssoToken || typeof ssoToken !== "string" || ssoToken.trim().length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "The ssoToken argument must be a non-empty string."
      );
    }

    const db = getFirestore();
    const tokenDocRef = db.collection("sso_tokens").doc(ssoToken.trim());

    let uidToAuth: string = "";
    let targetPathToRedirect: string = "/patient/dashboard";

    // Atomically validate and consume token inside a Firestore Transaction
    await db.runTransaction(async (transaction) => {
      const docSnap = await transaction.get(tokenDocRef);

      if (!docSnap.exists) {
        throw new HttpsError(
          "not-found",
          "The provided SSO token was not found or is invalid."
        );
      }

      const data = docSnap.data();
      if (!data) {
        throw new HttpsError("not-found", "SSO token data is empty.");
      }

      if (data.used === true) {
        throw new HttpsError(
          "failed-precondition",
          "This SSO token has already been used. Please request a new link."
        );
      }

      const expiresAt = data.expiresAt instanceof Timestamp
        ? data.expiresAt.toDate()
        : new Date(data.expiresAt);

      if (new Date() > expiresAt) {
        throw new HttpsError(
          "deadline-exceeded",
          "This SSO token has expired. Please request a new link."
        );
      }

      uidToAuth = data.uid;
      targetPathToRedirect = data.targetPath || "/patient/dashboard";

      // Mark token used atomically to prevent replay attacks
      transaction.update(tokenDocRef, {
        used: true,
        consumedAt: FieldValue.serverTimestamp(),
      });
    });

    // Create Firebase Custom Auth Token for Web sign-in
    try {
      const customToken = await getAuth().createCustomToken(uidToAuth);
      return {
        customToken: customToken,
        targetPath: targetPathToRedirect,
      };
    } catch (error) {
      throw new HttpsError(
        "internal",
        `Failed to generate custom auth token: ${(error as Error).message}`
      );
    }
  }
);
