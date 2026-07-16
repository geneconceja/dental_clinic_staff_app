/**
 * createWalkInAppointment.ts
 * Dental Clinic Staff/Admin App — Cloud Functions
 *
 * Callable Cloud Function that allows staff/admin to book a walk-in appointment
 * directly. Implements the contract defined in docs/functions-api-contract.md.
 *
 * Key guarantees:
 *   - Auth guard: caller must have users/{uid} with role in ['staff','admin']
 *   - endTime, startTime, date are all derived server-side; the client cannot inject them
 *   - appointmentDateTime is snapped to the nearest slotDurationMinutes boundary (from
 *     clinicSettings/main) before processing — ensures walk-in slots align with the
 *     patient app's discrete slot grid, preventing cross-app availability disagreement
 *   - Slot-conflict check + document creation run inside a single Firestore transaction
 *   - Created document is walk-in-correct: userId/userEmail null, bookingSource "staff_walkin"
 *   - imageUrl is stored if provided; image analysis is not triggered for walk-ins
 */

import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { initializeApp, getApps } from "firebase-admin/app";
import * as logger from "firebase-functions/logger";
import { Appointment, Service, StaffUser, ClinicSettings } from "./schema-types";

// Ensure the Admin SDK is initialised exactly once (safe to call multiple times).
if (getApps().length === 0) {
  initializeApp();
}

// ---------- Input type ----------

export interface CreateWalkInAppointmentInput {
  firstName: string;
  lastName: string;
  phoneNumber: string;
  serviceId: string;
  /** ISO 8601 timestamp string, e.g. "2026-09-01T09:00:00.000Z" */
  appointmentDateTime: string;
  notes?: string;
  /** Cloudinary URL — optional, provided if staff attached a photo */
  imageUrl?: string;
}

// ---------- Output type ----------

export interface CreateWalkInAppointmentOutput {
  appointmentId: string;
  status: "confirmed";
}

// ---------- Helper: "HH:mm" formatting ----------

/**
 * Returns the "HH:mm" representation of a Date in 24-hour UTC time.
 * All times in this system are stored as "HH:mm" strings in the clinic's
 * local (wall-clock) time — but appointmentDateTime is received as an ISO
 * string from the client. We treat the ISO string as already expressing
 * the local appointment time (the Flutter client is responsible for sending
 * the correct local-time ISO string). We extract HH:mm from it directly
 * rather than converting to a different timezone.
 */
function toHHmm(date: Date): string {
  const h = date.getUTCHours().toString().padStart(2, "0");
  const m = date.getUTCMinutes().toString().padStart(2, "0");
  return `${h}:${m}`;
}

/** Adds `minutes` to a Date object and returns a new Date. */
function addMinutes(date: Date, minutes: number): Date {
  return new Date(date.getTime() + minutes * 60_000);
}

/** Returns "YYYY-MM-DD" from a Date (UTC). */
function toDateString(date: Date): string {
  const y = date.getUTCFullYear();
  const mo = (date.getUTCMonth() + 1).toString().padStart(2, "0");
  const d = date.getUTCDate().toString().padStart(2, "0");
  return `${y}-${mo}-${d}`;
}

// ---------- Helper: time-range overlap ----------

/**
 * Returns true when [aStart, aEnd) overlaps [bStart, bEnd).
 * Times are "HH:mm" strings compared lexicographically (safe for 24-hour time).
 */
function timesOverlap(
  aStart: string,
  aEnd: string,
  bStart: string,
  bEnd: string
): boolean {
  return aStart < bEnd && aEnd > bStart;
}

// ---------- Helper: slot snapping ----------

/**
 * Snaps a Date to the nearest slot boundary.
 *
 * Example with slotDurationMinutes = 30:
 *   09:07 → 09:00  (7 minutes from :00, 23 from :30 — closer to :00)
 *   09:17 → 09:30  (17 minutes from :00, 13 to :30 — closer to :30)
 *   09:46 → 10:00  (16 minutes past :30 — closer to :00 of next hour)
 *
 * The seconds and milliseconds of the input are ignored; only HH:mm matters.
 * The returned Date is a new object aligned to a UTC slot boundary.
 */
export function snapToSlot(date: Date, slotDurationMinutes: number): Date {
  const totalMinutes = date.getUTCHours() * 60 + date.getUTCMinutes();
  const remainder    = totalMinutes % slotDurationMinutes;
  const half         = slotDurationMinutes / 2;

  const snappedMinutes =
    remainder < half
      ? totalMinutes - remainder                        // round down
      : totalMinutes + (slotDurationMinutes - remainder); // round up

  // Build a new Date at the snapped minute offset within the same UTC day
  const snapped = new Date(date);
  snapped.setUTCHours(0, 0, 0, 0);
  snapped.setUTCMinutes(snappedMinutes);
  return snapped;
}

// ---------- Input validation ----------

function validateInput(data: unknown): CreateWalkInAppointmentInput {
  const d = data as Record<string, unknown>;

  const requiredStrings: (keyof CreateWalkInAppointmentInput)[] = [
    "firstName",
    "lastName",
    "phoneNumber",
    "serviceId",
    "appointmentDateTime",
  ];

  for (const field of requiredStrings) {
    if (typeof d[field] !== "string" || (d[field] as string).trim() === "") {
      throw new HttpsError(
        "invalid-argument",
        `Missing or empty required field: ${field}`
      );
    }
  }

  // Validate appointmentDateTime is a parseable ISO 8601 string
  const dt = new Date(d.appointmentDateTime as string);
  if (isNaN(dt.getTime())) {
    throw new HttpsError(
      "invalid-argument",
      "appointmentDateTime must be a valid ISO 8601 timestamp string"
    );
  }

  return {
    firstName: (d.firstName as string).trim(),
    lastName: (d.lastName as string).trim(),
    phoneNumber: (d.phoneNumber as string).trim(),
    serviceId: (d.serviceId as string).trim(),
    appointmentDateTime: d.appointmentDateTime as string,
    notes: typeof d.notes === "string" ? d.notes.trim() || undefined : undefined,
    imageUrl: typeof d.imageUrl === "string" ? d.imageUrl.trim() || undefined : undefined,
  };
}

// ---------- The exported handler (also exported for direct testing) ----------

/**
 * The core implementation, extracted so Jest tests can call it directly
 * without going through the HTTPS callable wrapper.
 */
export async function createWalkInAppointmentHandler(
  request: CallableRequest<unknown>
): Promise<CreateWalkInAppointmentOutput> {
  const db = getFirestore();

  // ------------------------------------------------------------------
  // Step 1: Auth guard — caller must be a staff or admin user
  // ------------------------------------------------------------------
  if (!request.auth) {
    throw new HttpsError(
      "permission-denied",
      "Caller must be authenticated"
    );
  }

  const callerUid = request.auth.uid;

  const staffDocSnap = await db.collection("users").doc(callerUid).get();
  if (!staffDocSnap.exists) {
    throw new HttpsError(
      "permission-denied",
      "Caller does not have a staff account"
    );
  }

  const staffData = staffDocSnap.data() as StaffUser;
  if (!["staff", "admin"].includes(staffData.role)) {
    throw new HttpsError(
      "permission-denied",
      "Caller role is not staff or admin"
    );
  }

  // ------------------------------------------------------------------
  // Step 2: Input validation
  // ------------------------------------------------------------------
  const input = validateInput(request.data);

  // ------------------------------------------------------------------
  // Step 3: Service lookup + server-side time computation
  // ------------------------------------------------------------------
  const serviceSnap = await db.collection("services").doc(input.serviceId).get();
  if (!serviceSnap.exists) {
    throw new HttpsError(
      "not-found",
      `Service not found: ${input.serviceId}`
    );
  }

  const service = serviceSnap.data() as Service;
  if (!service.active) {
    throw new HttpsError(
      "failed-precondition",
      `Service is inactive: ${service.name}`
    );
  }

  // Derive times entirely server-side
  // ------------------------------------------------------------------
  // Step 3b: Fetch clinicSettings for slot boundary alignment
  // ------------------------------------------------------------------
  const settingsSnap = await db.collection("clinicSettings").doc("main").get();
  const slotDurationMinutes: number =
    settingsSnap.exists
      ? ((settingsSnap.data() as ClinicSettings).slotDurationMinutes ?? 30)
      : 30;

  // Snap to the nearest standard slot boundary so walk-in times always align
  // with the patient app's discrete slot grid.
  const rawStart       = new Date(input.appointmentDateTime);
  const appointmentStart = snapToSlot(rawStart, slotDurationMinutes);
  const appointmentEnd   = addMinutes(appointmentStart, service.durationMinutes);
  const startTime        = toHHmm(appointmentStart);
  const endTime          = toHHmm(appointmentEnd);
  const date             = toDateString(appointmentStart);
  const appointmentDateTime = Timestamp.fromDate(appointmentStart);

  if (startTime !== toHHmm(rawStart)) {
    logger.info("createWalkInAppointment: snapped to slot boundary", {
      requested: toHHmm(rawStart),
      snappedTo: startTime,
      slotDurationMinutes,
    });
  }

  logger.info("createWalkInAppointment: validated", {
    callerUid,
    serviceId: input.serviceId,
    date,
    startTime,
    endTime,
  });

  // ------------------------------------------------------------------
  // Step 4: Firestore transaction — slot-conflict check + document creation
  // ------------------------------------------------------------------
  const newAppointmentRef = db.collection("appointments").doc();

  await db.runTransaction(async (txn) => {
    // Query existing appointments for the same date with active statuses.
    // We must do ALL reads before any writes inside the transaction.
    const existingQuery = db
      .collection("appointments")
      .where("date", "==", date)
      .where("status", "in", ["pending", "confirmed"]);

    const existingSnap = await txn.get(existingQuery);

    // Check each existing appointment for a time-range overlap
    for (const doc of existingSnap.docs) {
      const existing = doc.data() as Appointment;
      if (timesOverlap(startTime, endTime, existing.startTime, existing.endTime)) {
        logger.warn("createWalkInAppointment: slot conflict", {
          requested: { startTime, endTime },
          conflictsWith: doc.id,
          existing: { startTime: existing.startTime, endTime: existing.endTime },
        });
        throw new HttpsError(
          "already-exists",
          "Slot no longer available"
        );
      }
    }

    // No conflict — create the appointment document
    const newAppointment: Omit<Appointment, "id"> = {
      userId:               null,
      userEmail:            null,
      firstName:            input.firstName,
      lastName:             input.lastName,
      phoneNumber:          input.phoneNumber,
      serviceId:            input.serviceId,
      serviceName:          service.name,
      reason:               service.name, // legacy field — kept for read-compat with any UI that reads `reason`
      appointmentDateTime:  appointmentDateTime,
      date:                 date,
      startTime:            startTime,
      endTime:              endTime,
      notes:                input.notes ?? null,
      imageUrl:             input.imageUrl ?? null,
      analysisResults:      null,
      status:               "confirmed",
      bookingSource:        "staff_walkin",
      createdBy:            callerUid,
      paid:                 false,
      reminderSent:         false,
      createdAt:            FieldValue.serverTimestamp() as FirebaseFirestore.Timestamp,
      updatedAt:            FieldValue.serverTimestamp() as FirebaseFirestore.Timestamp,
    };

    txn.set(newAppointmentRef, { id: newAppointmentRef.id, ...newAppointment });
  });

  logger.info("createWalkInAppointment: success", {
    appointmentId: newAppointmentRef.id,
    callerUid,
    date,
    startTime,
    endTime,
  });

  return {
    appointmentId: newAppointmentRef.id,
    status: "confirmed",
  };
}

// ---------- The exported callable Cloud Function ----------

export const createWalkInAppointment = onCall(
  { maxInstances: 10 },
  createWalkInAppointmentHandler
);
