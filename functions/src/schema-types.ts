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

export type BookingSource = "patient_app" | "staff_walkin";

export type StaffRole = "staff" | "admin";

// ---------- users/{uid} — staff/admin accounts only ----------

export interface StaffUser {
  uid: string;
  role: StaffRole;
  name: string;
  email: string;
  phone: string;
  active: boolean;
  createdAt: FirebaseFirestore.Timestamp;
}

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
}

// ---------- Helper: default bookingSource for legacy records ----------

/**
 * Existing documents written before `bookingSource` existed won't have the
 * field. Use this when reading, rather than assuming every doc has it.
 */
export function resolveBookingSource(data: Partial<Appointment>): BookingSource {
  return data.bookingSource ?? "patient_app";
}