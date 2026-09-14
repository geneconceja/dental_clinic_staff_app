/**
 * server.ts
 * Dental Clinic Staff/Admin App — Express HTTP Server
 *
 * This file is the entry point for the Render-hosted backend. It wraps all
 * existing Firebase callable handlers into standard Express REST endpoints so
 * they can run on any Node.js host (without Firebase Cloud Functions runtime).
 *
 * Design principles:
 *   - Zero duplication: all business logic lives in the original *Handler exports.
 *   - HttpsError mapping: Firebase error codes map to proper HTTP status codes.
 *   - Dual-mode admin init: uses FIREBASE_SERVICE_ACCOUNT_KEY env var in prod;
 *     falls back to Application Default Credentials (ADC) for local dev / CI.
 *   - CORS: only allows requests from the live web app and localhost origins.
 *   - Health check: GET /health returns 200 {"status":"ok"} for Render uptime checks.
 */

import "dotenv/config";
import express, { Request, Response, NextFunction } from "express";
import cors from "cors";
import { initializeApp, getApps, cert } from "firebase-admin/app";
import { HttpsError } from "firebase-functions/v2/https";

// ------------------------------------------------------------------
// Firebase Admin initialisation
// Must happen before any handler import that uses firebase-admin SDKs.
// ------------------------------------------------------------------

if (getApps().length === 0) {
  const serviceAccountEnv = process.env.FIREBASE_SERVICE_ACCOUNT_KEY;
  if (serviceAccountEnv) {
    // Production (Render): key is injected as a JSON string env var.
    const serviceAccount = JSON.parse(serviceAccountEnv);
    initializeApp({ credential: cert(serviceAccount) });
  } else {
    // Local dev / CI: use Application Default Credentials
    // (works when GOOGLE_APPLICATION_CREDENTIALS is set or inside GCP).
    initializeApp();
  }
}

// ------------------------------------------------------------------
// Handler imports (after admin init)
// ------------------------------------------------------------------

import { getAdminAnalyticsHandler } from "./getAdminAnalytics";
import { createWalkInAppointmentHandler } from "./createWalkInAppointment";
import { updateAppointmentStatusHandler } from "./updateAppointmentStatus";
import { createStaffUserHandler } from "./createStaffUser";
import { adminResetPasswordHandler } from "./adminResetPassword";
import { verifyFirebaseToken } from "./middleware/authMiddleware";

// ------------------------------------------------------------------
// Express app setup
// ------------------------------------------------------------------

const app = express();
app.use(express.json());

// CORS — allow the live web app and local dev origins.
const allowedOrigins = [
  "https://dental-clinic-ams.web.app",
  "https://dental-clinic-ams.firebaseapp.com",
  "https://oralscope-78cda.web.app",
  "https://oralscope-78cda.firebaseapp.com",
  "http://localhost:3000",
  "http://localhost:5000",
  "http://localhost:5173",
];

app.use(
  cors({
    origin: (origin, callback) => {
      // Allow requests with no Origin header (e.g., curl, Postman, mobile apps).
      if (!origin || allowedOrigins.includes(origin)) {
        callback(null, true);
      } else {
        callback(new Error(`CORS: origin '${origin}' not allowed`));
      }
    },
    methods: ["GET", "POST", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  })
);

// ------------------------------------------------------------------
// Helper: map Firebase HttpsError codes → HTTP status codes
// ------------------------------------------------------------------

const httpsErrorToStatus: Record<string, number> = {
  "ok": 200,
  "cancelled": 499,
  "unknown": 500,
  "invalid-argument": 400,
  "deadline-exceeded": 504,
  "not-found": 404,
  "already-exists": 409,
  "permission-denied": 403,
  "resource-exhausted": 429,
  "failed-precondition": 400,
  "aborted": 409,
  "out-of-range": 400,
  "unimplemented": 501,
  "internal": 500,
  "unavailable": 503,
  "data-loss": 500,
  "unauthenticated": 401,
};

/**
 * Wraps an existing CallableRequest-style handler into an Express route.
 *
 * Extracts `data` from `req.body.data` (matching the Firebase callable
 * on-wire format), injects `req.auth` for authentication, and maps
 * HttpsError instances to proper HTTP error responses.
 */
function callableHandler(
  handler: (req: { auth?: { uid: string; token: unknown }; data: unknown }) => Promise<unknown>
) {
  return async (req: Request, res: Response): Promise<void> => {
    try {
      const data = req.body?.data ?? req.body ?? {};
      const result = await handler({ auth: req.auth, data });
      res.status(200).json({ result });
    } catch (err: unknown) {
      if (err instanceof HttpsError) {
        const status = httpsErrorToStatus[err.code] ?? 500;
        res.status(status).json({
          error: { status: err.code, message: err.message },
        });
      } else {
        console.error("[server] Unexpected error:", err);
        res.status(500).json({
          error: { status: "internal", message: "An unexpected error occurred." },
        });
      }
    }
  };
}

// ------------------------------------------------------------------
// Routes
// ------------------------------------------------------------------

// Root endpoint — friendly status check
app.get("/", (_req: Request, res: Response) => {
  res.status(200).json({
    service: "Dental Clinic Backend API",
    status: "online",
    healthCheck: "/health",
    timestamp: new Date().toISOString(),
  });
});

// Health check — no auth required; Render pings this to keep the service warm.
app.get("/health", (_req: Request, res: Response) => {
  res.status(200).json({ status: "ok", timestamp: new Date().toISOString() });
});

// All /api/* routes require a valid Firebase ID token (injected by verifyFirebaseToken).
const authRequired = verifyFirebaseToken(true);

app.post("/api/getAdminAnalytics",         authRequired, callableHandler(getAdminAnalyticsHandler as Parameters<typeof callableHandler>[0]));
app.post("/api/createWalkInAppointment",   authRequired, callableHandler(createWalkInAppointmentHandler as Parameters<typeof callableHandler>[0]));
app.post("/api/updateAppointmentStatus",   authRequired, callableHandler(updateAppointmentStatusHandler as Parameters<typeof callableHandler>[0]));
app.post("/api/createStaffUser",           authRequired, callableHandler(createStaffUserHandler as Parameters<typeof callableHandler>[0]));
app.post("/api/adminResetPassword",        authRequired, callableHandler(adminResetPasswordHandler as Parameters<typeof callableHandler>[0]));

// ------------------------------------------------------------------
// 404 fallback
// ------------------------------------------------------------------

app.use((_req: Request, res: Response) => {
  res.status(404).json({ error: { status: "not-found", message: "Route not found." } });
});

// ------------------------------------------------------------------
// Global error handler (catches CORS and other middleware errors)
// ------------------------------------------------------------------

// eslint-disable-next-line @typescript-eslint/no-unused-vars
app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
  console.error("[server] Middleware error:", err.message);
  res.status(500).json({ error: { status: "internal", message: err.message } });
});

// ------------------------------------------------------------------
// Start listening
// ------------------------------------------------------------------

const PORT = parseInt(process.env.PORT ?? "8080", 10);
app.listen(PORT, () => {
  console.log(`[server] Dental Clinic backend running on port ${PORT}`);
  console.log(`[server] Health check: http://localhost:${PORT}/health`);
});

export default app;
