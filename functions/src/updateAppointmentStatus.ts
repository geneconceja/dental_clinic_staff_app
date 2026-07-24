/**
 * updateAppointmentStatus.ts
 * Dental Clinic Staff/Admin App — Cloud Functions
 *
 * Callable Cloud Function that allows staff/admin to update the status of an
 * appointment. Implements the contract defined in docs/functions-api-contract.md.
 *
 * Key guarantees:
 *   - Auth guard: caller must have users/{uid} with role in ['staff','admin']
 *   - Fetches the appointment and validates the state transition securely in a transaction
 *   - Enforces transition matrix:
 *       pending   -> confirmed, cancelled
 *       confirmed -> cancelled, completed, no-show
 *   - Only updates status-related metadata (status, cancellationReason, updatedAt)
 */

import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { Appointment, StaffUser, AppointmentStatus } from "./schema-types";

// ---------- Input type ----------

export interface UpdateAppointmentStatusInput {
  appointmentId: string;
  newStatus: AppointmentStatus;
  cancellationReason?: string;
}

// ---------- Output type ----------

export interface UpdateAppointmentStatusOutput {
  success: boolean;
  appointmentId: string;
  newStatus: AppointmentStatus;
}

// ---------- Valid Transitions Matrix ----------

const VALID_TRANSITIONS: Record<AppointmentStatus, AppointmentStatus[]> = {
  pending: ["confirmed", "cancelled"],
  confirmed: ["cancelled", "completed", "no-show"],
  cancelled: [], // terminal state
  completed: [], // terminal state
  "no-show": [], // terminal state
};

function isValidTransition(current: AppointmentStatus, next: AppointmentStatus): boolean {
  const allowed = VALID_TRANSITIONS[current];
  return allowed ? allowed.includes(next) : false;
}

// ---------- The exported handler ----------

export async function updateAppointmentStatusHandler(
  request: CallableRequest<unknown>
): Promise<UpdateAppointmentStatusOutput> {
  try {
    logger.info(">>> UPDATE APPOINTMENT STATUS ENTERED", {
      authUid: request.auth?.uid,
      authEmail: request.auth?.token.email,
      data: request.data,
    });

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
    const d = request.data as Record<string, unknown>;
    const appointmentId = d.appointmentId;
    const newStatus = d.newStatus as AppointmentStatus;
    const cancellationReason = d.cancellationReason;

    if (typeof appointmentId !== "string" || appointmentId.trim() === "") {
      throw new HttpsError(
        "invalid-argument",
        "Missing or empty required field: appointmentId"
      );
    }

    const allowedStatuses: AppointmentStatus[] = ["confirmed", "cancelled", "completed", "no-show"];
    if (!allowedStatuses.includes(newStatus)) {
      throw new HttpsError(
        "invalid-argument",
        `Invalid newStatus: ${newStatus}`
      );
    }

    if (cancellationReason !== undefined && typeof cancellationReason !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "cancellationReason must be a string if provided"
      );
    }

    logger.info("updateAppointmentStatus: validated", {
      callerUid,
      appointmentId,
      newStatus,
    });

    // ------------------------------------------------------------------
    // Step 3: Transaction — get, validate transition, and update
    // ------------------------------------------------------------------
    const appointmentRef = db.collection("appointments").doc(appointmentId);

    await db.runTransaction(async (txn) => {
      const docSnap = await txn.get(appointmentRef);
      if (!docSnap.exists) {
        throw new HttpsError(
          "not-found",
          `Appointment not found: ${appointmentId}`
        );
      }

      const appointment = docSnap.data() as Appointment;
      const currentStatus = appointment.status;

      // Check transition validity
      if (!isValidTransition(currentStatus, newStatus)) {
        logger.warn("updateAppointmentStatus: invalid status transition attempted", {
          appointmentId,
          currentStatus,
          attemptedStatus: newStatus,
        });
        throw new HttpsError(
          "failed-precondition",
          `Invalid status transition from '${currentStatus}' to '${newStatus}'`
        );
      }

      // Update metadata
      const updateData: Record<string, any> = {
        status: newStatus,
        updatedAt: FieldValue.serverTimestamp(),
      };

      if (newStatus === "cancelled") {
        updateData.cancellationReason = cancellationReason ? cancellationReason.trim() : "Cancelled by staff";
      }

      txn.update(appointmentRef, updateData);
    });

    logger.info("updateAppointmentStatus: success", {
      appointmentId,
      newStatus,
      callerUid,
    });

    return {
      success: true,
      appointmentId,
      newStatus,
    };
  } catch (error: any) {
    logger.error("Crashed in updateAppointmentStatusHandler:", {
      message: error?.message || String(error),
      stack: error?.stack,
    });
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("internal", error?.message || "Internal function error");
  }
}

// ---------- The exported callable Cloud Function ----------

export const updateAppointmentStatus = onCall(
  { cors: true, maxInstances: 10 },
  updateAppointmentStatusHandler
);
