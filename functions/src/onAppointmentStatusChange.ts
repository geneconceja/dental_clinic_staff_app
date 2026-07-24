/**
 * onAppointmentStatusChange.ts
 * Dental Clinic Staff/Admin App — Cloud Functions
 *
 * Firestore-triggered function that fires whenever an appointments/{id}
 * document is updated. If the `status` field changed, sends a transactional
 * email to the patient (patient-app bookings only — walk-ins have no email).
 *
 * Transitions that trigger an email:
 *   pending  → confirmed  → "Your appointment is confirmed"
 *   *        → cancelled  → "Your appointment has been cancelled"
 *
 * Walk-ins (bookingSource == "staff_walkin" or userEmail == null) are silently
 * skipped — there is no automated channel to reach walk-in patients.
 *
 * Email is sent via Brevo (https://brevo.com).
 * Requires BREVO_API_KEY in functions/.env (or Firebase Secrets for production).
 */

import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import { Appointment } from "./schema-types";
import { sendBrevoEmail } from "./brevoService";

// ---------- Constants ----------

const CLINIC_NAME = "OralScope Dental Clinic";

// ---------- Helpers ----------

/** Formats "HH:mm" (24h) as "h:mm AM/PM" for email display. */
function formatTime(hhmm: string): string {
  const [hourStr, minuteStr] = hhmm.split(":");
  const hour = parseInt(hourStr, 10);
  const ampm = hour >= 12 ? "PM" : "AM";
  const hour12 = hour % 12 === 0 ? 12 : hour % 12;
  return `${hour12}:${minuteStr} ${ampm}`;
}

/** Formats "YYYY-MM-DD" as "Monday, January 1, 2026". */
function formatDate(yyyymmdd: string): string {
  const date = new Date(`${yyyymmdd}T00:00:00`);
  return date.toLocaleDateString("en-US", {
    weekday: "long",
    year: "numeric",
    month: "long",
    day: "numeric",
  });
}

/** Builds the confirmation email HTML body. */
function buildConfirmedEmailHtml(appt: Appointment): string {
  const patientName = `${appt.firstName} ${appt.lastName}`;
  const dateStr = formatDate(appt.date);
  const timeStr = `${formatTime(appt.startTime)} – ${formatTime(appt.endTime)}`;
  const service = appt.serviceName ?? appt.reason ?? "Dental appointment";

  return `
    <div style="font-family: Arial, sans-serif; max-width: 560px; margin: 0 auto; color: #1a1a1a;">
      <div style="background: #1a7fe3; padding: 28px 32px; border-radius: 8px 8px 0 0;">
        <h1 style="margin: 0; color: #ffffff; font-size: 22px;">Appointment Confirmed ✓</h1>
      </div>
      <div style="background: #f9f9f9; padding: 28px 32px; border-radius: 0 0 8px 8px; border: 1px solid #e0e0e0;">
        <p style="margin-top: 0;">Hi <strong>${patientName}</strong>,</p>
        <p>Your appointment at <strong>${CLINIC_NAME}</strong> has been confirmed. Here are your details:</p>
        <table style="width: 100%; border-collapse: collapse; margin: 20px 0;">
          <tr>
            <td style="padding: 10px 12px; background: #fff; border: 1px solid #e0e0e0; font-weight: bold; width: 35%;">Service</td>
            <td style="padding: 10px 12px; background: #fff; border: 1px solid #e0e0e0;">${service}</td>
          </tr>
          <tr>
            <td style="padding: 10px 12px; background: #f4f4f4; border: 1px solid #e0e0e0; font-weight: bold;">Date</td>
            <td style="padding: 10px 12px; background: #f4f4f4; border: 1px solid #e0e0e0;">${dateStr}</td>
          </tr>
          <tr>
            <td style="padding: 10px 12px; background: #fff; border: 1px solid #e0e0e0; font-weight: bold;">Time</td>
            <td style="padding: 10px 12px; background: #fff; border: 1px solid #e0e0e0;">${timeStr}</td>
          </tr>
        </table>
        <p>Please arrive 5–10 minutes early. If you need to reschedule or cancel, please contact us as soon as possible.</p>
        <p style="margin-bottom: 0; color: #555; font-size: 13px;">This is an automated message from ${CLINIC_NAME}. Please do not reply to this email.</p>
      </div>
    </div>
  `;
}

/** Builds the cancellation email HTML body. */
function buildCancelledEmailHtml(appt: Appointment): string {
  const patientName = `${appt.firstName} ${appt.lastName}`;
  const dateStr = formatDate(appt.date);
  const timeStr = `${formatTime(appt.startTime)} – ${formatTime(appt.endTime)}`;
  const reason = (appt as any).cancellationReason ?? null;

  return `
    <div style="font-family: Arial, sans-serif; max-width: 560px; margin: 0 auto; color: #1a1a1a;">
      <div style="background: #d9534f; padding: 28px 32px; border-radius: 8px 8px 0 0;">
        <h1 style="margin: 0; color: #ffffff; font-size: 22px;">Appointment Cancelled</h1>
      </div>
      <div style="background: #f9f9f9; padding: 28px 32px; border-radius: 0 0 8px 8px; border: 1px solid #e0e0e0;">
        <p style="margin-top: 0;">Hi <strong>${patientName}</strong>,</p>
        <p>Your appointment at <strong>${CLINIC_NAME}</strong> scheduled for <strong>${dateStr}</strong> at <strong>${timeStr}</strong> has been cancelled.</p>
        ${reason ? `<p><strong>Reason:</strong> ${reason}</p>` : ""}
        <p>To reschedule, please contact us or book a new appointment through the OralScope patient portal.</p>
        <p style="margin-bottom: 0; color: #555; font-size: 13px;">This is an automated message from ${CLINIC_NAME}. Please do not reply to this email.</p>
      </div>
    </div>
  `;
}

// ---------- The exported trigger ----------

export const onAppointmentStatusChange = onDocumentUpdated(
  {
    document: "appointments/{appointmentId}",
    maxInstances: 10,
  },
  async (event) => {
    const before = event.data?.before.data() as Appointment | undefined;
    const after = event.data?.after.data() as Appointment | undefined;

    if (!before || !after) {
      logger.warn("onAppointmentStatusChange: missing before/after snapshots");
      return;
    }

    // Exit early if status did not change
    if (before.status === after.status) return;

    const appointmentId = event.params.appointmentId;
    const { status: newStatus, userEmail, bookingSource } = after;

    logger.info("onAppointmentStatusChange: status changed", {
      appointmentId,
      from: before.status,
      to: newStatus,
      bookingSource,
      hasEmail: !!userEmail,
    });

    // Only notify patient bookings with an email
    if (!userEmail || bookingSource === "staff_walkin") {
      logger.info("onAppointmentStatusChange: skipping — walk-in or no email", {
        appointmentId,
      });
      return;
    }

    // Only notify on confirmed or cancelled transitions
    if (newStatus !== "confirmed" && newStatus !== "cancelled") {
      logger.info("onAppointmentStatusChange: no email needed for status", {
        newStatus,
      });
      return;
    }

    const subject =
      newStatus === "confirmed"
        ? `Your appointment is confirmed — ${CLINIC_NAME}`
        : `Your appointment has been cancelled — ${CLINIC_NAME}`;

    const htmlContent =
      newStatus === "confirmed"
        ? buildConfirmedEmailHtml(after)
        : buildCancelledEmailHtml(after);

    const toName = `${after.firstName} ${after.lastName}`;

    await sendBrevoEmail({
      toEmail: userEmail,
      toName: toName,
      subject: subject,
      htmlContent: htmlContent,
    });
  }
);
