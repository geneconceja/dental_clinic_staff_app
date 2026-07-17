/**
 * scripts/seed-emulator.js
 *
 * Populates the Firebase emulator suite with realistic test data:
 * services, clinicSettings, staff/admin auth users, and appointments
 * covering both bookingSource values plus a legacy record with no
 * bookingSource set (to test the resolveBookingSource() fallback).
 *
 * Usage:
 *   1. Start the emulators first: firebase emulators:start
 *   2. In a second terminal:      node scripts/seed-emulator.js
 *
 * Requires: npm install firebase-admin --save-dev (run from repo root)
 */

// Using the MODULAR admin API (firebase-admin v10+) instead of the legacy
// namespaced `admin.firestore()` style — this is more robust across package
// versions and avoids "admin.firestore is not a function" errors caused by
// partial installs or version mismatches with the legacy compat layer.
const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getFirestore, Timestamp, FieldValue } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");

// Point the Admin SDK at the local emulators, NOT production.
// These must match the ports in firebase.json / emulators:start output.
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";

initializeApp({ projectId: "oralscope-78cda" });

const db = getFirestore();
const auth = getAuth();

async function seed() {
  console.log("Seeding emulator data...\n");

  // ---------- 1. Staff/Admin Auth users + matching users/{uid} docs ----------

  const staffAccounts = [
    { email: "admin@clinic.test", password: "password123", role: "admin", name: "Dr. Santos (Admin)" },
    { email: "staff1@clinic.test", password: "password123", role: "staff", name: "Maria (Front Desk)" },
    { email: "staff2@clinic.test", password: "password123", role: "staff", name: "Jun (Front Desk)" },
  ];

  const staffUids = {};

  for (const account of staffAccounts) {
    let uid;
    try {
      const userRecord = await auth.getUserByEmail(account.email);
      uid = userRecord.uid;
      console.log(`Found existing auth account for ${account.email} (${uid})`);
    } catch (e) {
      if (e.code === 'auth/user-not-found') {
        const userRecord = await auth.createUser({
          email: account.email,
          password: account.password,
          displayName: account.name,
        });
        uid = userRecord.uid;
        console.log(`Created new auth account for ${account.role} user: ${account.email} (${uid})`);
      } else {
        throw e;
      }
    }

    staffUids[account.role + "_" + account.email] = uid;

    await db.collection("users").doc(uid).set({
      uid: uid,
      role: account.role,
      name: account.name,
      email: account.email,
      phone: "09171234567",
      active: true,
      createdAt: FieldValue.serverTimestamp(),
    });
    console.log(`Created/updated users/${uid} doc for ${account.email}`);
  }

  // ---------- 2. Services ----------

  const services = [
    { id: "svc-cleaning", name: "Teeth Cleaning", durationMinutes: 30, price: 800, description: "Routine dental cleaning", active: true },
    { id: "svc-checkup", name: "Follow-up Consultation", durationMinutes: 20, price: 300, description: "Follow-up visit", active: true },
    { id: "svc-extraction", name: "Tooth Extraction", durationMinutes: 45, price: 1500, description: "Simple tooth extraction", active: true },
  ];

  for (const service of services) {
    await db.collection("services").doc(service.id).set(service);
    console.log(`Created service: ${service.name}`);
  }

  // ---------- 3. Clinic Settings ----------

  const dayHoursOpen = { open: "09:00", close: "17:00", isOpen: true };
  const dayHoursClosed = { open: null, close: null, isOpen: false };

  await db.collection("clinicSettings").doc("main").set({
    workingHours: {
      monday: dayHoursOpen,
      tuesday: dayHoursOpen,
      wednesday: dayHoursOpen,
      thursday: dayHoursOpen,
      friday: dayHoursOpen,
      saturday: { open: "09:00", close: "12:00", isOpen: true },
      sunday: dayHoursClosed,
    },
    holidays: ["2026-12-25", "2026-01-01"],
    slotDurationMinutes: 30,
    reminderHoursBefore: 24,
    clinicName: "Cardenas Family Dental Clinic",
    clinicPhone: "09171234567",
    clinicAddress: "123 Rizal St, Cagayan",
  });

  console.log("Created clinicSettings/main");

  // ---------- 4. Appointments ----------

  const now = Timestamp.now();
  const staffAdminUid = staffUids["admin_admin@clinic.test"];

  // Helpers for today-dated appointments
  const todayDate = new Date();
  const pad = (n) => String(n).padStart(2, "0");
  const todayStr = `${todayDate.getFullYear()}-${pad(todayDate.getMonth() + 1)}-${pad(todayDate.getDate())}`;
  const todayAt = (hhmm) => {
    const [h, m] = hhmm.split(":").map(Number);
    const d = new Date(todayDate);
    d.setHours(h, m, 0, 0);
    return d;
  };

  const appointments = [
    // Patient-app booking, pending
    {
      id: "appt-001",
      userId: "simulated-patient-uid-001",
      userEmail: "jin.cardenas@example.com",
      firstName: "Jin",
      lastName: "Cardenas",
      phoneNumber: "12121212",
      reason: "Follow-up consultation",
      date: "2026-08-15",
      appointmentDateTime: Timestamp.fromDate(new Date("2026-08-15T08:00:00+08:00")),
      startTime: "08:00",
      endTime: "08:20",
      notes: "Patient reports mild sensitivity",
      imageUrl: null,
      analysisResults: null,
      status: "pending",
      bookingSource: "patient_app",
      createdBy: null,
      paid: false,
      reminderSent: false,
      createdAt: now,
    },

    // Patient-app booking, confirmed, WITH an image + analysis result
    {
      id: "appt-002",
      userId: "simulated-patient-uid-002",
      userEmail: "anna.reyes@example.com",
      firstName: "Anna",
      lastName: "Reyes",
      phoneNumber: "09181111111",
      reason: "Teeth Cleaning",
      date: "2026-08-16",
      appointmentDateTime: Timestamp.fromDate(new Date("2026-08-16T09:00:00+08:00")),
      startTime: "09:00",
      endTime: "09:30",
      notes: null,
      imageUrl: "https://res.cloudinary.com/demo/image/upload/sample-tooth.jpg",
      analysisResults: {
        diseaseLabel: "Early-stage caries",
        confidencePercentage: 78,
      },
      status: "confirmed",
      bookingSource: "patient_app",
      createdBy: null,
      paid: false,
      reminderSent: false,
      createdAt: now,
    },

    // Staff-booked walk-in, confirmed, no image
    {
      id: "appt-003",
      userId: null,
      userEmail: null,
      firstName: "Pedro",
      lastName: "Dela Cruz",
      phoneNumber: "09221234567",
      reason: "Tooth Extraction",
      date: "2026-08-15",
      appointmentDateTime: Timestamp.fromDate(new Date("2026-08-15T10:00:00+08:00")),
      startTime: "10:00",
      endTime: "10:45",
      notes: "Walk-in, referred by Anna Reyes",
      imageUrl: null,
      analysisResults: null,
      status: "confirmed",
      bookingSource: "staff_walkin",
      createdBy: staffAdminUid,
      paid: true,
      reminderSent: false,
      createdAt: now,
    },

    // Legacy-style record: NO bookingSource field at all
    // (tests resolveBookingSource() fallback defaulting to "patient_app")
    {
      id: "appt-004-legacy",
      userId: "simulated-patient-uid-legacy",
      userEmail: "legacy.patient@example.com",
      firstName: "Legacy",
      lastName: "Record",
      phoneNumber: "09991234567",
      reason: "Teeth Cleaning",
      date: "2026-08-10",
      appointmentDateTime: Timestamp.fromDate(new Date("2026-08-10T14:00:00+08:00")),
      startTime: "14:00",
      endTime: "14:30",
      notes: null,
      imageUrl: null,
      analysisResults: null,
      status: "completed",
      // bookingSource intentionally omitted
      createdAt: Timestamp.fromDate(new Date("2026-07-01T00:00:00+08:00")),
    },

    // Cancelled appointment, for testing filters
    {
      id: "appt-005",
      userId: "simulated-patient-uid-003",
      userEmail: "carlos.tan@example.com",
      firstName: "Carlos",
      lastName: "Tan",
      phoneNumber: "09171112222",
      reason: "Follow-up Consultation",
      date: "2026-08-20",
      appointmentDateTime: Timestamp.fromDate(new Date("2026-08-20T11:00:00+08:00")),
      startTime: "11:00",
      endTime: "11:20",
      notes: null,
      imageUrl: null,
      analysisResults: null,
      status: "cancelled",
      bookingSource: "patient_app",
      createdBy: null,
      paid: false,
      reminderSent: false,
      createdAt: now,
    },

    // TODAY appointments — so the Dashboard shows data right after seeding
    {
      id: "appt-today-001",
      userId: "simulated-patient-uid-today",
      userEmail: "maria.santos@example.com",
      firstName: "Maria",
      lastName: "Santos",
      phoneNumber: "09201234567",
      serviceId: "svc-cleaning",
      serviceName: "Teeth Cleaning",
      reason: "Teeth Cleaning",
      date: todayStr,
      appointmentDateTime: Timestamp.fromDate(todayAt("09:00")),
      startTime: "09:00",
      endTime: "09:30",
      notes: "Routine cleaning",
      imageUrl: null,
      analysisResults: null,
      status: "confirmed",
      bookingSource: "patient_app",
      createdBy: null,
      paid: false,
      reminderSent: false,
      createdAt: now,
    },
    {
      id: "appt-today-002",
      userId: null,
      userEmail: null,
      firstName: "Roberto",
      lastName: "Cruz",
      phoneNumber: "09301234567",
      serviceId: "svc-extraction",
      serviceName: "Tooth Extraction",
      reason: "Tooth Extraction",
      date: todayStr,
      appointmentDateTime: Timestamp.fromDate(todayAt("10:00")),
      startTime: "10:00",
      endTime: "10:45",
      notes: "Walk-in, upper right molar",
      imageUrl: null,
      analysisResults: null,
      status: "confirmed",
      bookingSource: "staff_walkin",
      createdBy: staffAdminUid,
      paid: true,
      reminderSent: false,
      createdAt: now,
    },
    {
      id: "appt-today-003",
      userId: "simulated-patient-uid-today2",
      userEmail: "grace.lim@example.com",
      firstName: "Grace",
      lastName: "Lim",
      phoneNumber: "09111234567",
      serviceId: "svc-checkup",
      serviceName: "Follow-up Consultation",
      reason: "Follow-up Consultation",
      date: todayStr,
      appointmentDateTime: Timestamp.fromDate(todayAt("14:00")),
      startTime: "14:00",
      endTime: "14:20",
      notes: null,
      imageUrl: null,
      analysisResults: null,
      status: "pending",
      bookingSource: "patient_app",
      createdBy: null,
      paid: false,
      reminderSent: false,
      createdAt: now,
    },
  ];

  for (const appt of appointments) {
    const { id, ...data } = appt;
    await db.collection("appointments").doc(id).set(data);
    console.log(`Created appointment: ${id} (${data.status}, ${data.bookingSource ?? "no bookingSource"})`);
  }

  console.log("\nSeeding complete.");
  console.log("Staff login credentials (emulator only):");
  staffAccounts.forEach((a) => console.log(`  ${a.email} / ${a.password} (${a.role})`));
}

seed()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("Seeding failed:", err);
    process.exit(1);
  });