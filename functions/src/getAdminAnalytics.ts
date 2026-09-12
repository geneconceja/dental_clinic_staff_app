/**
 * getAdminAnalytics.ts
 * Dental Clinic Staff/Admin App — Cloud Functions
 *
 * Callable Cloud Function that computes analytics for the admin dashboard.
 * Returns all 6 analytics widgets in a single response object.
 *
 * Auth guard: caller must be an admin (role === "admin").
 *
 * Metrics returned:
 *   1. Today's appointments    — total count, upcoming vs completed breakdown
 *   2. Trend data              — appointments per day for the current week + month totals
 *   3. No-show rate            — % of appointments marked "no-show" for the current month
 *   4. New vs returning        — split based on isFirstVisit flag on completed appointments
 *   5. Revenue this month      — total revenue + per-week breakdown
 *   6. Top treatments          — top 3–5 services by booking count (month)
 */

import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { Appointment, StaffUser } from "./schema-types";

// ---------- Input / Output types ----------

export interface GetAdminAnalyticsInput {
  /** Optional: override "today" for testing — ISO date string "YYYY-MM-DD" */
  referenceDate?: string;
}

export interface TodayStats {
  total: number;
  upcoming: number;   // pending | confirmed
  completed: number;
  noShow: number;
  cancelled: number;
}

export interface DailyCount {
  date: string;   // "YYYY-MM-DD"
  count: number;
}

export interface WeeklyRevenue {
  weekLabel: string;  // e.g. "Week 1"
  revenue: number;
}

export interface TreatmentCount {
  serviceName: string;
  count: number;
}

export interface AdminAnalyticsResult {
  /** Metric 1 */
  today: TodayStats;
  /** Metric 2 — daily counts for the current week (Mon–Sun) */
  weeklyTrend: DailyCount[];
  /** Metric 2 — total appointments this month */
  monthTotal: number;
  /** Metric 3 */
  noShowRate: number;   // 0–100 (%)
  /** Metric 4 */
  newPatients: number;
  returningPatients: number;
  /** Metric 5 */
  revenueThisMonth: number;
  weeklyRevenue: WeeklyRevenue[];
  /** Metric 6 — top 3–5 treatments this month */
  topTreatments: TreatmentCount[];
  /** ISO timestamp of when this result was computed */
  computedAt: string;
}

// ---------- Helper utilities ----------

/**
 * Returns the start (00:00:00) of a given date as a JS Date.
 */
function startOfDay(date: Date): Date {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return d;
}

/**
 * Returns the end (23:59:59.999) of a given date as a JS Date.
 */
function endOfDay(date: Date): Date {
  const d = new Date(date);
  d.setHours(23, 59, 59, 999);
  return d;
}

/**
 * Returns the Monday of the week containing `date`.
 */
function startOfWeek(date: Date): Date {
  const d = new Date(date);
  const day = d.getDay(); // 0 = Sun
  const diff = day === 0 ? -6 : 1 - day;
  d.setDate(d.getDate() + diff);
  d.setHours(0, 0, 0, 0);
  return d;
}

/**
 * Returns the first day of the month containing `date`.
 */
function startOfMonth(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), 1, 0, 0, 0, 0);
}

/**
 * Returns the last moment of the month containing `date`.
 */
function endOfMonth(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth() + 1, 0, 23, 59, 59, 999);
}

/**
 * Formats a Date as "YYYY-MM-DD".
 */
function toDateString(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

/**
 * Derives which ISO week-of-month (1-based) a date falls in,
 * anchored to the first Monday on or before the 1st of the month.
 */
function weekOfMonth(date: Date, monthStart: Date): number {
  const diffMs = date.getTime() - monthStart.getTime();
  const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
  return Math.floor(diffDays / 7) + 1;
}

// ---------- Core handler (exported for testing) ----------

export async function getAdminAnalyticsHandler(
  request: CallableRequest<GetAdminAnalyticsInput>
): Promise<AdminAnalyticsResult> {
  try {
    // --- Auth guard ---
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }

    const db = getFirestore();
  const callerUid = request.auth.uid;

  // Verify admin role
  const callerDoc = await db.collection("users").doc(callerUid).get();
  if (!callerDoc.exists) {
    throw new HttpsError("not-found", "Caller user document not found.");
  }
  const callerData = callerDoc.data() as StaffUser;
  if (callerData.role !== "admin") {
    throw new HttpsError("permission-denied", "Admin role required to access analytics.");
  }

  // --- Reference date (default: today) ---
  let today: Date;
  if (request.data?.referenceDate) {
    today = new Date(`${request.data.referenceDate}T00:00:00`);
    if (isNaN(today.getTime())) {
      throw new HttpsError("invalid-argument", "referenceDate must be a valid ISO date string (YYYY-MM-DD).");
    }
  } else {
    today = new Date();
  }

  logger.info("getAdminAnalytics called", { callerUid, referenceDate: toDateString(today) });

  // --- Date boundaries ---
  const todayStart   = startOfDay(today);
  const todayEnd     = endOfDay(today);
  const weekStart    = startOfWeek(today);
  const monthStart   = startOfMonth(today);
  const monthEnd     = endOfMonth(today);

  // --- Fetch month's appointments in a single query ---
  // We fetch all appointments whose appointmentDateTime falls in [monthStart, monthEnd].
  // Today's and week's data are derived from this superset to minimise Firestore reads.
  const monthSnap = await db
    .collection("appointments")
    .where("appointmentDateTime", ">=", Timestamp.fromDate(monthStart))
    .where("appointmentDateTime", "<=", Timestamp.fromDate(monthEnd))
    .get();

  const monthAppointments = monthSnap.docs.map((d) => ({
    id: d.id,
    ...(d.data() as Omit<Appointment, "id">),
  }));

  logger.info(`Fetched ${monthAppointments.length} appointments for month`);

  // ── Metric 1: Today's appointments ────────────────────────────────────────

  const todayAppts = monthAppointments.filter((a) => {
    const dt = (a.appointmentDateTime as Timestamp).toDate();
    return dt >= todayStart && dt <= todayEnd;
  });

  const today_stats: TodayStats = {
    total:     todayAppts.length,
    upcoming:  todayAppts.filter((a) => a.status === "pending" || a.status === "confirmed").length,
    completed: todayAppts.filter((a) => a.status === "completed").length,
    noShow:    todayAppts.filter((a) => a.status === "no-show").length,
    cancelled: todayAppts.filter((a) => a.status === "cancelled").length,
  };

  // ── Metric 2: Weekly trend + month total ──────────────────────────────────

  // Build a map of date → count for the current week (Mon–Sun)
  const weekDays: DailyCount[] = [];
  for (let i = 0; i < 7; i++) {
    const day = new Date(weekStart);
    day.setDate(weekStart.getDate() + i);
    weekDays.push({ date: toDateString(day), count: 0 });
  }

  // Count each month appointment that falls within this week
  for (const appt of monthAppointments) {
    const dt = (appt.appointmentDateTime as Timestamp).toDate();
    const ds = toDateString(dt);
    const slot = weekDays.find((w) => w.date === ds);
    if (slot) slot.count++;
  }

  const monthTotal = monthAppointments.length;

  // ── Metric 3: No-show rate ────────────────────────────────────────────────

  const finalisedCount = monthAppointments.filter(
    (a) => a.status === "completed" || a.status === "no-show" || a.status === "cancelled"
  ).length;
  const noShowCount = monthAppointments.filter((a) => a.status === "no-show").length;
  const noShowRate = finalisedCount > 0
    ? Math.round((noShowCount / finalisedCount) * 100 * 10) / 10  // 1 decimal
    : 0;

  // ── Metric 4: New vs returning patients ───────────────────────────────────

  const completedWithVisitFlag = monthAppointments.filter(
    (a) => a.status === "completed" && a.isFirstVisit !== undefined
  );
  const newPatients       = completedWithVisitFlag.filter((a) => a.isFirstVisit === true).length;
  const returningPatients = completedWithVisitFlag.filter((a) => a.isFirstVisit === false).length;

  // ── Metric 5: Revenue this month + weekly breakdown ───────────────────────

  const completedPaid = monthAppointments.filter(
    (a) => a.status === "completed" && a.paid === true
  );

  const revenueThisMonth = completedPaid.reduce((sum, a) => sum + (a.price ?? 0), 0);

  // Bucket revenue into weeks (Week 1 … Week N)
  const revenueByWeek: Record<number, number> = {};
  for (const appt of completedPaid) {
    const dt   = (appt.appointmentDateTime as Timestamp).toDate();
    const week = weekOfMonth(dt, monthStart);
    revenueByWeek[week] = (revenueByWeek[week] ?? 0) + (appt.price ?? 0);
  }
  const weeklyRevenue: WeeklyRevenue[] = Object.entries(revenueByWeek)
    .sort(([a], [b]) => Number(a) - Number(b))
    .map(([wk, rev]) => ({ weekLabel: `Week ${wk}`, revenue: rev }));

  // ── Metric 6: Top treatments ──────────────────────────────────────────────

  const treatmentCounts: Record<string, number> = {};
  for (const appt of monthAppointments) {
    const name = appt.serviceName ?? "Unknown";
    treatmentCounts[name] = (treatmentCounts[name] ?? 0) + 1;
  }
  const topTreatments: TreatmentCount[] = Object.entries(treatmentCounts)
    .map(([serviceName, count]) => ({ serviceName, count }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 5);

  // ── Assemble result ───────────────────────────────────────────────────────

  const result: AdminAnalyticsResult = {
    today:           today_stats,
    weeklyTrend:     weekDays,
    monthTotal,
    noShowRate,
    newPatients,
    returningPatients,
    revenueThisMonth,
    weeklyRevenue,
    topTreatments,
    computedAt:      new Date().toISOString(),
  };

    logger.info("getAdminAnalytics result", result);
    return result;
  } catch (error: any) {
    logger.error("Error in getAdminAnalyticsHandler:", {
      message: error?.message || String(error),
      stack: error?.stack,
    });
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("internal", error?.message || "Internal function error");
  }
}

// ---------- Exported Cloud Function ----------

export const getAdminAnalytics = onCall<GetAdminAnalyticsInput>(
  { cors: true, region: "asia-southeast1" },
  getAdminAnalyticsHandler
);
