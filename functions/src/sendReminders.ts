/**
 * sendReminders.ts
 * Dental Clinic Staff/Admin App — Cloud Functions
 *
 * Scheduled Cloud Function that runs every hour and sends reminder emails to
 * patients with upcoming confirmed appointments within the clinic's configured
 * `reminderHoursBefore` window (read live from clinicSettings/main).
 *
 * Logic:
 *   1. Fetch clinicSettings/main → read reminderHoursBefore (default: 24).
 *   2. Compute the reminder window: [now, now + reminderHoursBefore hours].
 *   3. Query appointments where status == "confirmed", reminderSent == false,
 *      and appointmentDateTime falls within that window.
 *   4. For each: skip walk-ins (no userEmail), send reminder email, mark
 *      reminderSent = true on success.
 *
 * Walk-ins (userEmail == null) are silently skipped — no automated channel.
 * Email failures are logged but do not throw — the document keeps reminderSent
 * as false so it will be retried on the next hourly run.
 *
 * Email is sent via Resend (https://resend.com).
 * Requires RESEND_API_KEY in functions/.env (or Firebase Secrets for production).
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { getFirestore, Timestamp, FieldValue } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { Appointment, ClinicSettings } from "./schema-types";
import { sendBrevoEmail } from "./brevoService";

// ---------- Constants ----------

const CLINIC_NAME = "OralScope Dental Clinic";

/** Default fallback if reminderHoursBefore is missing from clinicSettings. */
const DEFAULT_REMINDER_HOURS = 24;

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

/** Builds the reminder email HTML body. */
function buildReminderEmailHtml(appt: Appointment, hoursAway: number): string {
  const patientName = `${appt.firstName} ${appt.lastName}`;
  const dateStr = formatDate(appt.date);
  const timeStr = `${formatTime(appt.startTime)} – ${formatTime(appt.endTime)}`;
  const service = appt.serviceName ?? appt.reason ?? "Dental appointment";
  const timePhrase = hoursAway <= 2
    ? "in a couple of hours"
    : hoursAway <= 6
      ? `in about ${Math.round(hoursAway)} hours`
      : "tomorrow";

  return `
    <div style="font-family: Arial, sans-serif; max-width: 560px; margin: 0 auto; color: #1a1a1a;">
      <div style="background: #1a7fe3; padding: 28px 32px; border-radius: 8px 8px 0 0;">
        <h1 style="margin: 0; color: #ffffff; font-size: 22px;">Appointment Reminder 🗓</h1>
      </div>
      <div style="background: #f9f9f9; padding: 28px 32px; border-radius: 0 0 8px 8px; border: 1px solid #e0e0e0;">
        <p style="margin-top: 0;">Hi <strong>${patientName}</strong>,</p>
        <p>This is a friendly reminder that you have an appointment at <strong>${CLINIC_NAME}</strong> <strong>${timePhrase}</strong>.</p>
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

// ---------- The exported scheduled function ----------

export const sendReminders = onSchedule(
  {
    schedule: "every 1 hours",
    maxInstances: 1, // Ensure only one instance runs at a time to prevent double-sends
  },
  async () => {
    const db = getFirestore();

    // ------------------------------------------------------------------
    // Step 1: Read reminderHoursBefore from clinicSettings
    // ------------------------------------------------------------------
    let reminderHours = DEFAULT_REMINDER_HOURS;

    try {
      const settingsSnap = await db.collection("clinicSettings").doc("main").get();
      if (settingsSnap.exists) {
        const settings = settingsSnap.data() as ClinicSettings;
        if (typeof settings.reminderHoursBefore === "number" && settings.reminderHoursBefore > 0) {
          reminderHours = settings.reminderHoursBefore;
        }
      }
    } catch (err: any) {
      logger.warn("sendReminders: could not read clinicSettings, using default", {
        defaultHours: reminderHours,
        error: err.message,
      });
    }

    logger.info("sendReminders: starting run", { reminderHours });

    // ------------------------------------------------------------------
    // Step 2: Compute the reminder window
    // ------------------------------------------------------------------
    const now = new Date();
    const windowEnd = new Date(now.getTime() + reminderHours * 60 * 60 * 1000);

    const nowTimestamp = Timestamp.fromDate(now);
    const windowEndTimestamp = Timestamp.fromDate(windowEnd);

    // ------------------------------------------------------------------
    // Step 3: Query confirmed, unsent appointments in the window
    // ------------------------------------------------------------------
    let appointments: (Appointment & { _docId: string })[] = [];

    try {
      const snap = await db
        .collection("appointments")
        .where("status", "==", "confirmed")
        .where("reminderSent", "==", false)
        .where("appointmentDateTime", ">=", nowTimestamp)
        .where("appointmentDateTime", "<=", windowEndTimestamp)
        .get();

      appointments = snap.docs.map((doc) => ({
        ...(doc.data() as Appointment),
        _docId: doc.id,
      }));
    } catch (err: any) {
      logger.error("sendReminders: failed to query appointments", {
        error: err.message,
      });
      return;
    }

    logger.info("sendReminders: appointments to remind", {
      count: appointments.length,
    });

    if (appointments.length === 0) return;

    // ------------------------------------------------------------------
    // Step 4: Send reminders
    // ------------------------------------------------------------------
    for (const appt of appointments) {
      const docId = appt._docId;

      // Skip walk-ins — no email channel
      if (!appt.userEmail || appt.bookingSource === "staff_walkin") {
        logger.info("sendReminders: skipping walk-in or no-email appointment", {
          appointmentId: docId,
        });
        continue;
      }

      // Compute how many hours away the appointment is (for dynamic email copy)
      const apptMs = (appt.appointmentDateTime as unknown as Timestamp).toMillis();
      const hoursAway = (apptMs - now.getTime()) / (1000 * 60 * 60);

      const subject = `Appointment reminder — ${CLINIC_NAME}`;
      const htmlContent = buildReminderEmailHtml(appt, hoursAway);
      const toName = `${appt.firstName} ${appt.lastName}`;

      const res = await sendBrevoEmail({
        toEmail: appt.userEmail,
        toName: toName,
        subject: subject,
        htmlContent: htmlContent,
      });

      if (res.success) {
        // Mark reminder as sent
        await db
          .collection("appointments")
          .doc(docId)
          .update({ reminderSent: true, updatedAt: FieldValue.serverTimestamp() });

        logger.info("sendReminders: reminder sent and marked", {
          appointmentId: docId,
          to: appt.userEmail,
        });
      } else {
        logger.error("sendReminders: Brevo dispatch error", {
          appointmentId: docId,
          error: res.error,
        });
        // Do NOT set reminderSent=true — retry on next run
      }
    }

    logger.info("sendReminders: run complete");
  }
);
