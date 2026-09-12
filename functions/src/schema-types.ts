/**
 * schema-types.ts
 * Dental Clinic Appointment System — Staff/Admin App
 *
 * Single source of truth for Firestore document shapes. Import these in
 * Cloud Functions code. For Flutter/Dart, keep the equivalent model classes
 * in lib/core/models/ manually in sync with this file until/unless a shared
 * codegen step is set up — there is currently no automated sync between this
 * file and Dart models, so changes here must be mirrored by hand.
 *
 * IMPORTANT: fields marked "PATIENT-APP-OWNED" must never be renamed, removed,
 * or have their meaning changed from this app's code — that schema is
 * controlled by the separate patient app. Only "ADDITIVE (this app)" fields
 * may be freely modified here.
 */

// ---------- Enums ----------

export type AppointmentStatus =
  | "pending"
  | "confirmed"
  | "cancelled"
  | "completed"
  | "no-show";

export type BookingSource = "patient_app" | "patient_web" | "staff_walkin";

export type UserRole = "patient" | "staff" | "admin";
export type StaffRole = "staff" | "admin";

// ---------- users/{uid} — patient/staff/admin accounts ----------

export interface UserDocument {
  uid: string;
  role: UserRole;
  name: string;
  email: string;
  phone: string;
  active: boolean;
  createdAt: FirebaseFirestore.Timestamp;
}

export type StaffUser = UserDocument;

// ---------- services/{serviceId} ----------

export interface Service {
  id: string;
  name: string;
  durationMinutes: number;
  price: number;
  description: string;
  active: boolean;
}

// ---------- clinicSettings/main ----------

export interface DayHours {
  open: string | null;  // "HH:mm" or null if closed
  close: string | null;
  isOpen: boolean;
}

export interface ClinicSettings {
  workingHours: {
    monday: DayHours;
    tuesday: DayHours;
    wednesday: DayHours;
    thursday: DayHours;
    friday: DayHours;
    saturday: DayHours;
    sunday: DayHours;
  };
  holidays: string[]; // ["YYYY-MM-DD", ...]
  slotDurationMinutes: number;
  reminderHoursBefore: number;
  clinicName: string;
  clinicPhone: string;
  clinicAddress: string;
}

// ---------- analysisResults (embedded, not a top-level collection) ----------

/**
 * Resolved 2026-07-16 (see decisions-log.md #3):
 * The patient app stores analysisResults as an array of tag+confidence objects:
 *   [{ tag: string, confidence: number }, ...]
 * This aligns the TypeScript schema with the actual patient app payload.
 */
export interface AnalysisTag {
  tag: string;
  confidence: number; // 0.0–1.0 (raw model output)
}

/**
 * Convenience alias. The full analysisResults field on Appointment is either
 * null (no analysis performed) or an array of AnalysisTag objects.
 */
export type AnalysisResults = AnalysisTag[];

// ---------- appointments/{appointmentId} ----------

export interface Appointment {
  id: string;

  // PATIENT-APP-OWNED — do not rename/remove/repurpose
  userId: string | null;          // null for staff_walkin
  userEmail: string | null;       // null for staff_walkin
  firstName: string;
  lastName: string;
  phoneNumber: string;
  reason: string;                 // legacy freeform field, still written by patient app
  date: string;                   // "YYYY-MM-DD" — redundant with appointmentDateTime, see decisions-log.md
  appointmentDateTime: FirebaseFirestore.Timestamp;
  startTime: string;               // "HH:mm"
  endTime: string;                 // "HH:mm"
  notes: string | null;
  imageUrl: string | null;         // Cloudinary URL
  analysisResults: AnalysisResults | null; // null or AnalysisTag[]
  status: AppointmentStatus;
  createdAt: FirebaseFirestore.Timestamp;

  // NOT YET IN PATIENT-APP SCHEMA — populated only when serviceId linkage is adopted
  serviceId?: string;
  serviceName?: string;

  // ADDITIVE (this app) — safe to modify/extend
  bookingSource: BookingSource;
  createdBy: string | null;        // staff uid, present only when bookingSource == "staff_walkin"
  paid: boolean;
  reminderSent: boolean;
  updatedAt?: FirebaseFirestore.Timestamp;

  /**
   * Snapshot of Service.price at time of booking/completion.
   * Stored here so historical revenue remains accurate if service prices change later.
   * Written by createWalkInAppointment and updateAppointmentStatus (on 'completed').
   * May be absent on legacy appointments booked before this field was introduced — treat as 0.
   */
  price?: number;

  /**
   * True if this is the patient's first completed appointment.
   * Set server-side by updateAppointmentStatus when status transitions to 'completed'
   * and no prior completed appointment exists for the same userId or phoneNumber.
   * Walk-in patients (userId == null) are matched by phoneNumber.
   * Absent on legacy appointments — analytics should treat missing as unknown (exclude from split).
   */
  isFirstVisit?: boolean;
}

// ---------- Helper: default bookingSource for legacy records ----------

/**
 * Existing documents written before `bookingSource` existed won't have the
 * field. Use this when reading, rather than assuming every doc has it.
 */
export function resolveBookingSource(data: Partial<Appointment>): BookingSource {
  return data.bookingSource ?? "patient_app";
}

// ---------- analytics_summaries/{YYYY-MM} (optional pre-aggregated cache) ----------

/**
 * Written exclusively by Cloud Functions (Admin SDK) — never by the client.
 * If present, the getAdminAnalytics function may return this cached document
 * instead of re-scanning all appointments for closed months.
 * Client read access is restricted to admin role via firestore.rules.
 */
export interface AnalyticsSummary {
  /** "YYYY-MM" — the month this summary covers */
  month: string;

  totalAppointments: number;
  completedCount: number;
  noShowCount: number;
  cancelledCount: number;

  /** Sum of price on all completed + paid appointments in the month */
  totalRevenue: number;

  /** New vs. returning patient counts (only appointments with isFirstVisit set) */
  newPatients: number;
  returningPatients: number;

  /** Top-5 services by booking count: { serviceName, count } */
  topTreatments: Array<{ serviceName: string; count: number }>;

  /** ISO timestamp of when this summary was last computed */
  computedAt: FirebaseFirestore.Timestamp;
}