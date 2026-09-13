/**
 * authMiddleware.ts
 * Dental Clinic Staff/Admin App — Express Server
 *
 * Firebase ID-token verification middleware for the Render-hosted Express API.
 *
 * Flow:
 *   1. Reads "Authorization: Bearer <idToken>" header.
 *   2. Verifies token with firebase-admin; attaches decoded claims as `req.auth`.
 *   3. If `required` is true (default), rejects unauthenticated requests with 401.
 *   4. If `required` is false, allows the request to proceed even without a token.
 *
 * The attached `req.auth` object is shaped to match the `CallableRequest.auth`
 * interface expected by all existing handler functions, so they need zero changes.
 */

import { Request, Response, NextFunction, RequestHandler } from "express";
import { getAuth } from "firebase-admin/auth";
import { DecodedIdToken } from "firebase-admin/auth";

/**
 * Augment Express's Request so TypeScript knows about `req.auth`.
 */
declare global {
  namespace Express {
    interface Request {
      auth?: {
        uid: string;
        token: DecodedIdToken;
      };
    }
  }
}

/**
 * Returns an Express middleware that verifies the Firebase ID token.
 * @param required - When true (default), 401 is returned if the token is missing/invalid.
 */
export function verifyFirebaseToken(required = true): RequestHandler {
  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    const authHeader = req.headers["authorization"] ?? "";
    const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : null;

    if (!token) {
      if (required) {
        res.status(401).json({
          error: { status: "unauthenticated", message: "Missing Authorization header." },
        });
        return;
      }
      return next();
    }

    try {
      const decoded = await getAuth().verifyIdToken(token);
      req.auth = { uid: decoded.uid, token: decoded };
      next();
    } catch {
      res.status(401).json({
        error: { status: "unauthenticated", message: "Invalid or expired ID token." },
      });
    }
  };
}
