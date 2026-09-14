/**
 * scripts/seed-production.js
 * Dental Clinic Staff App — Production Database Seeder
 *
 * Populates the fresh production Firebase project (dental-clinic-ams) with:
 *   1. Clinic Settings (clinicSettings/main)
 *   2. Dental Services Catalog (services)
 *   3. Demo Accounts:
 *      - admin@clinic.test     / password123 (Admin)
 *      - staff1@clinic.test    / password123 (Staff)
 *      - patient1@clinic.test  / password123 (Patient)
 *   4. Realistic appointments (pending, confirmed, completed) across current dates
 *
 * Usage:
 *   node scripts/seed-production.js [path-to-service-account.json]
 */

const fs = require("fs");
const path = require("path");
const { initializeApp, cert, getApps } = require("firebase-admin/app");
const { getFirestore, Timestamp, FieldValue } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");

// Locate service account key
let keyPath = process.argv[2];
if (!keyPath) {
  const userDownloads = path.join(process.env.USERPROFILE || process.env.HOME, "Downloads");
  if (fs.existsSync(userDownloads)) {
    const files = fs.readdirSync(userDownloads).filter(f => f.startsWith("dental-clinic-ams-firebase-adminsdk") && f.endsWith(".json"));
    if (files.length > 0) {
      keyPath = path.join(userDownloads, files[0]);
    }
  }
}

if (!keyPath || !fs.existsSync(keyPath)) {
  console.error("Error: Could not locate service account key file for dental-clinic-ams.");
  console.error("Please provide the path as an argument: node scripts/seed-production.js <path-to-json>");
  process.exit(1);
}

console.log(`Using Service Account Key: ${keyPath}`);
const serviceAccount = JSON.parse(fs.readFileSync(keyPath, "utf8"));

if (getApps().length === 0) {
  initializeApp({
    credential: cert(serviceAccount),
    projectId: "dental-clinic-ams",
  });
}

const db = getFirestore();
const auth = getAuth();

async function seed() {
  console.log("\n🚀 Seeding dental-clinic-ams Production Database...\n");

  // 1. Clinic Settings
  const dayHoursOpen = { open: "09:00", close: "17:00", isOpen: true };
  const dayHoursClosed = { open: null, close: null, isOpen: false };

  await db.collection("clinicSettings").doc("main").set({
    clinicName: "OralScope Dental Clinic",
    clinicPhone: "09171234567",
    clinicAddress: "123 Healthcare Ave, Manila",
    slotDurationMinutes: 30,
    reminderHoursBefore: 24,
    holidays: ["2026-12-25", "2026-01-01"],
    workingHours: {
      monday: dayHoursOpen,
      tuesday: dayHoursOpen,
      wednesday: dayHoursOpen,
      thursday: dayHoursOpen,
      friday: dayHoursOpen,
      saturday: { open: "09:00", close: "13:00", isOpen: true },
      sunday: dayHoursClosed,
    },
  });
  console.log("✅ Created clinicSettings/main");

  // 2. Services
  const services = [
    { id: "svc-cleaning", name: "Teeth Cleaning & Polishing", durationMinutes: 30, price: 800, description: "Professional scaling, polishing, and plaque removal", active: true },
    { id: "svc-checkup", name: "Comprehensive Dental Check-up", durationMinutes: 20, price: 350, description: "Full oral examination and treatment planning", active: true },
    { id: "svc-filling", name: "Composite Tooth Filling", durationMinutes: 45, price: 1200, description: "Tooth-colored aesthetic restorative filling", active: true },
    { id: "svc-extraction", name: "Tooth Extraction", durationMinutes: 45, price: 1500, description: "Routine dental extraction with local anaesthetic", active: true },
    { id: "svc-whitening", name: "Laser Teeth Whitening", durationMinutes: 60, price: 3500, description: "In-office instant LED laser whitening treatment", active: true },
    { id: "svc-rootcanal", name: "Root Canal Therapy", durationMinutes: 90, price: 5000, description: "Endodontic therapy to eliminate pulp infection", active: true },
  ];

  for (const s of services) {
    await db.collection("services").doc(s.id).set(s);
  }
  console.log(`✅ Created ${services.length} dental services`);

  // 3. Auth Accounts & Users docs
  const accounts = [
    { email: "admin@clinic.test", password: "password123", role: "admin", name: "Dr. Santos (Admin)", phone: "09171234567" },
    { email: "staff1@clinic.test", password: "password123", role: "staff", name: "Maria (Front Desk)", phone: "09177654321" },
    { email: "patient1@clinic.test", password: "password123", role: "patient", name: "Juan Dela Cruz", phone: "09179998877" },
    { email: "patient2@clinic.test", password: "password123", role: "patient", name: "Maria Clara Santos", phone: "09171112233" },
    { email: "patient3@clinic.test", password: "password123", role: "patient", name: "Angelo Reyes", phone: "09172223344" },
    { email: "patient4@clinic.test", password: "password123", role: "patient", name: "Bea Alonzo", phone: "09173334455" },
  ];

  const uids = {};

  for (const acc of accounts) {
    let uid;
    try {
      const existing = await auth.getUserByEmail(acc.email);
      uid = existing.uid;
      // update password
      await auth.updateUser(uid, { password: acc.password, emailVerified: true });
      console.log(`ℹ️ Found existing auth user for ${acc.email} (${uid})`);
    } catch (e) {
      if (e.code === "auth/user-not-found") {
        const created = await auth.createUser({
          email: acc.email,
          password: acc.password,
          displayName: acc.name,
          emailVerified: true,
        });
        uid = created.uid;
        console.log(`✅ Created auth account for ${acc.email} (${uid})`);
      } else {
        throw e;
      }
    }

    uids[acc.email] = uid;
    uids[acc.role] = uid;
    const isPatient = acc.role === "patient";
    const nameParts = acc.name.split(" ");

    await db.collection("users").doc(uid).set({
      uid,
      email: acc.email,
      name: acc.name,
      phone: acc.phone,
      role: acc.role,
      active: true,
      ...(isPatient && {
        firstName: nameParts[0] || "Patient",
        lastName: nameParts.slice(1).join(" ") || "User",
        isVerified: true,
      }),
      createdAt: FieldValue.serverTimestamp(),
    });
    console.log(`✅ Provisioned users/${uid} (${acc.role} - ${acc.name})`);
  }

  // 4. Appointments across Timeline (for rich dashboard analytics & review queue)
  function createTimestamp(dateStr, timeStr) {
    return Timestamp.fromDate(new Date(`${dateStr}T${timeStr}:00+08:00`));
  }

  const demoAppointments = [
    // ---------------- Week 1 (Sept 1 - Sept 7) ----------------
    {
      id: "apt-w1-01",
      userId: uids["patient1@clinic.test"],
      userEmail: "patient1@clinic.test",
      firstName: "Juan",
      lastName: "Dela Cruz",
      phoneNumber: "09179998877",
      serviceId: "svc-checkup",
      serviceName: "Comprehensive Dental Check-up",
      reason: "Comprehensive Dental Check-up",
      price: 350,
      paid: true,
      isFirstVisit: true,
      date: "2026-09-02",
      startTime: "10:00",
      endTime: "10:20",
      appointmentDateTime: createTimestamp("2026-09-02", "10:00"),
      status: "completed",
      bookingSource: "patient_web",
      notes: "First time consultation and oral exam.",
      createdAt: createTimestamp("2026-08-28", "09:00"),
      updatedAt: createTimestamp("2026-09-02", "10:20"),
    },
    {
      id: "apt-w1-02",
      userId: uids["patient2@clinic.test"],
      userEmail: "patient2@clinic.test",
      firstName: "Maria Clara",
      lastName: "Santos",
      phoneNumber: "09171112233",
      serviceId: "svc-cleaning",
      serviceName: "Teeth Cleaning & Polishing",
      reason: "Teeth Cleaning & Polishing",
      price: 800,
      paid: true,
      isFirstVisit: true,
      date: "2026-09-04",
      startTime: "14:00",
      endTime: "14:30",
      appointmentDateTime: createTimestamp("2026-09-04", "14:00"),
      status: "completed",
      bookingSource: "patient_web",
      notes: "Semi-annual cleaning.",
      createdAt: createTimestamp("2026-09-01", "11:00"),
      updatedAt: createTimestamp("2026-09-04", "14:30"),
    },
    {
      id: "apt-w1-03",
      userId: null,
      userEmail: null,
      firstName: "Corazon",
      lastName: "Aquino",
      phoneNumber: "09181112233",
      serviceId: "svc-filling",
      serviceName: "Composite Tooth Filling",
      reason: "Composite Tooth Filling",
      price: 1200,
      paid: true,
      isFirstVisit: true,
      date: "2026-09-05",
      startTime: "11:00",
      endTime: "11:45",
      appointmentDateTime: createTimestamp("2026-09-05", "11:00"),
      status: "completed",
      bookingSource: "staff_walkin",
      notes: "Walk-in patient filling upper right premolar.",
      createdAt: createTimestamp("2026-09-05", "11:00"),
      updatedAt: createTimestamp("2026-09-05", "11:45"),
    },

    // ---------------- Week 2 (Sept 8 - Sept 13) ----------------
    {
      id: "apt-w2-01",
      userId: uids["patient3@clinic.test"],
      userEmail: "patient3@clinic.test",
      firstName: "Angelo",
      lastName: "Reyes",
      phoneNumber: "09172223344",
      serviceId: "svc-rootcanal",
      serviceName: "Root Canal Therapy",
      reason: "Root Canal Therapy",
      price: 5000,
      paid: true,
      isFirstVisit: true,
      date: "2026-09-08",
      startTime: "09:00",
      endTime: "10:30",
      appointmentDateTime: createTimestamp("2026-09-08", "09:00"),
      status: "completed",
      bookingSource: "patient_web",
      notes: "Lower molar root canal procedure completed successfully.",
      createdAt: createTimestamp("2026-09-03", "16:00"),
      updatedAt: createTimestamp("2026-09-08", "10:30"),
    },
    {
      id: "apt-w2-02",
      userId: null,
      userEmail: null,
      firstName: "Rodrigo",
      lastName: "Diaz",
      phoneNumber: "09193334455",
      serviceId: "svc-extraction",
      serviceName: "Tooth Extraction",
      reason: "Tooth Extraction",
      price: 1500,
      paid: true,
      isFirstVisit: true,
      date: "2026-09-09",
      startTime: "13:30",
      endTime: "14:15",
      appointmentDateTime: createTimestamp("2026-09-09", "13:30"),
      status: "completed",
      bookingSource: "staff_walkin",
      notes: "Emergency extraction for decayed wisdom tooth.",
      createdAt: createTimestamp("2026-09-09", "13:30"),
      updatedAt: createTimestamp("2026-09-09", "14:15"),
    },
    {
      id: "apt-w2-03",
      userId: uids["patient4@clinic.test"],
      userEmail: "patient4@clinic.test",
      firstName: "Bea",
      lastName: "Alonzo",
      phoneNumber: "09173334455",
      serviceId: "svc-cleaning",
      serviceName: "Teeth Cleaning & Polishing",
      reason: "Teeth Cleaning & Polishing",
      price: 800,
      paid: true,
      isFirstVisit: true,
      date: "2026-09-10",
      startTime: "10:00",
      endTime: "10:30",
      appointmentDateTime: createTimestamp("2026-09-10", "10:00"),
      status: "completed",
      bookingSource: "patient_web",
      notes: "Routine ultrasonic scaling.",
      createdAt: createTimestamp("2026-09-06", "14:00"),
      updatedAt: createTimestamp("2026-09-10", "10:30"),
    },
    {
      id: "apt-w2-04",
      userId: uids["patient1@clinic.test"],
      userEmail: "patient1@clinic.test",
      firstName: "Juan",
      lastName: "Dela Cruz",
      phoneNumber: "09179998877",
      serviceId: "svc-filling",
      serviceName: "Composite Tooth Filling",
      reason: "Composite Tooth Filling",
      price: 1200,
      paid: true,
      isFirstVisit: false,
      date: "2026-09-11",
      startTime: "15:00",
      endTime: "15:45",
      appointmentDateTime: createTimestamp("2026-09-11", "15:00"),
      status: "completed",
      bookingSource: "patient_web",
      notes: "Follow-up filling on molar.",
      createdAt: createTimestamp("2026-09-05", "10:00"),
      updatedAt: createTimestamp("2026-09-11", "15:45"),
    },
    {
      id: "apt-w2-05",
      userId: null,
      userEmail: null,
      firstName: "Ferdinand",
      lastName: "Marcos",
      phoneNumber: "09185556677",
      serviceId: "svc-checkup",
      serviceName: "Comprehensive Dental Check-up",
      reason: "Comprehensive Dental Check-up",
      price: 350,
      paid: false,
      date: "2026-09-12",
      startTime: "11:00",
      endTime: "11:20",
      appointmentDateTime: createTimestamp("2026-09-12", "11:00"),
      status: "no-show",
      bookingSource: "staff_walkin",
      notes: "Patient did not arrive for scheduled check-up slot.",
      createdAt: createTimestamp("2026-09-10", "09:00"),
      updatedAt: createTimestamp("2026-09-12", "11:30"),
    },

    // ---------------- Today: Sept 14, 2026 ----------------
    {
      id: "apt-completed-1",
      userId: uids["patient1@clinic.test"],
      userEmail: "patient1@clinic.test",
      firstName: "Juan",
      lastName: "Dela Cruz",
      phoneNumber: "09179998877",
      serviceId: "svc-cleaning",
      serviceName: "Teeth Cleaning & Polishing",
      reason: "Teeth Cleaning & Polishing",
      price: 800,
      paid: true,
      isFirstVisit: false,
      date: "2026-09-14",
      startTime: "09:00",
      endTime: "09:30",
      appointmentDateTime: createTimestamp("2026-09-14", "09:00"),
      status: "completed",
      bookingSource: "patient_web",
      notes: "Routine visit, regular checkup and cleaning completed.",
      createdAt: createTimestamp("2026-09-12", "10:00"),
      updatedAt: createTimestamp("2026-09-14", "09:30"),
    },
    {
      id: "apt-today-1",
      userId: null,
      userEmail: null,
      firstName: "Corazon",
      lastName: "Aquino",
      phoneNumber: "09181112233",
      serviceId: "svc-filling",
      serviceName: "Composite Tooth Filling",
      reason: "Composite Tooth Filling",
      price: 1200,
      paid: false,
      date: "2026-09-14",
      startTime: "11:00",
      endTime: "11:45",
      appointmentDateTime: createTimestamp("2026-09-14", "11:00"),
      status: "confirmed",
      bookingSource: "staff_walkin",
      notes: "Walk-in patient for lower molar filling.",
      createdAt: createTimestamp("2026-09-14", "08:30"),
      updatedAt: createTimestamp("2026-09-14", "08:30"),
    },
    {
      id: "apt-today-2",
      userId: uids["patient2@clinic.test"],
      userEmail: "patient2@clinic.test",
      firstName: "Maria Clara",
      lastName: "Santos",
      phoneNumber: "09171112233",
      serviceId: "svc-extraction",
      serviceName: "Tooth Extraction",
      reason: "Tooth Extraction",
      price: 1500,
      paid: true,
      isFirstVisit: false,
      date: "2026-09-14",
      startTime: "13:30",
      endTime: "14:15",
      appointmentDateTime: createTimestamp("2026-09-14", "13:30"),
      status: "completed",
      bookingSource: "patient_web",
      notes: "Extraction completed, prescription provided.",
      createdAt: createTimestamp("2026-09-11", "16:00"),
      updatedAt: createTimestamp("2026-09-14", "14:15"),
    },
    {
      id: "apt-today-3",
      userId: uids["patient4@clinic.test"],
      userEmail: "patient4@clinic.test",
      firstName: "Bea",
      lastName: "Alonzo",
      phoneNumber: "09173334455",
      serviceId: "svc-whitening",
      serviceName: "Laser Teeth Whitening",
      reason: "Laser Teeth Whitening",
      price: 3500,
      paid: false,
      date: "2026-09-14",
      startTime: "15:00",
      endTime: "16:00",
      appointmentDateTime: createTimestamp("2026-09-14", "15:00"),
      status: "confirmed",
      bookingSource: "patient_web",
      notes: "Afternoon laser whitening appointment.",
      createdAt: createTimestamp("2026-09-12", "11:00"),
      updatedAt: createTimestamp("2026-09-13", "17:00"),
    },
    {
      id: "apt-today-4",
      userId: null,
      userEmail: null,
      firstName: "Rodrigo",
      lastName: "Diaz",
      phoneNumber: "09193334455",
      serviceId: "svc-checkup",
      serviceName: "Comprehensive Dental Check-up",
      reason: "Comprehensive Dental Check-up",
      price: 350,
      paid: false,
      date: "2026-09-14",
      startTime: "16:30",
      endTime: "16:50",
      appointmentDateTime: createTimestamp("2026-09-14", "16:30"),
      status: "no-show",
      bookingSource: "staff_walkin",
      notes: "Patient failed to arrive for afternoon checkup.",
      createdAt: createTimestamp("2026-09-14", "10:00"),
      updatedAt: createTimestamp("2026-09-14", "16:55"),
    },

    // ---------------- Week 3 (Sept 15 - Sept 21) ----------------
    {
      id: "apt-pending-1",
      userId: uids["patient1@clinic.test"],
      userEmail: "patient1@clinic.test",
      firstName: "Juan",
      lastName: "Dela Cruz",
      phoneNumber: "09179998877",
      serviceId: "svc-whitening",
      serviceName: "Laser Teeth Whitening",
      reason: "Laser Teeth Whitening",
      price: 3500,
      paid: false,
      date: "2026-09-15",
      startTime: "14:00",
      endTime: "15:00",
      appointmentDateTime: createTimestamp("2026-09-15", "14:00"),
      status: "pending",
      bookingSource: "patient_web",
      notes: "Requested afternoon slot for laser whitening.",
      createdAt: createTimestamp("2026-09-13", "14:00"),
      updatedAt: createTimestamp("2026-09-13", "14:00"),
    },
    {
      id: "apt-w3-01",
      userId: uids["patient3@clinic.test"],
      userEmail: "patient3@clinic.test",
      firstName: "Angelo",
      lastName: "Reyes",
      phoneNumber: "09172223344",
      serviceId: "svc-checkup",
      serviceName: "Comprehensive Dental Check-up",
      reason: "Comprehensive Dental Check-up",
      price: 350,
      paid: false,
      date: "2026-09-15",
      startTime: "09:30",
      endTime: "09:50",
      appointmentDateTime: createTimestamp("2026-09-15", "09:30"),
      status: "confirmed",
      bookingSource: "patient_web",
      notes: "Post-root canal follow-up examination.",
      createdAt: createTimestamp("2026-09-12", "15:00"),
      updatedAt: createTimestamp("2026-09-13", "09:00"),
    },
    {
      id: "apt-w3-02",
      userId: uids["patient2@clinic.test"],
      userEmail: "patient2@clinic.test",
      firstName: "Maria Clara",
      lastName: "Santos",
      phoneNumber: "09171112233",
      serviceId: "svc-cleaning",
      serviceName: "Teeth Cleaning & Polishing",
      reason: "Teeth Cleaning & Polishing",
      price: 800,
      paid: false,
      date: "2026-09-16",
      startTime: "10:00",
      endTime: "10:30",
      appointmentDateTime: createTimestamp("2026-09-16", "10:00"),
      status: "confirmed",
      bookingSource: "patient_web",
      notes: "Regular hygiene appointment.",
      createdAt: createTimestamp("2026-09-13", "11:00"),
      updatedAt: createTimestamp("2026-09-13", "16:00"),
    },
    {
      id: "apt-w3-03",
      userId: null,
      userEmail: null,
      firstName: "Corazon",
      lastName: "Aquino",
      phoneNumber: "09181112233",
      serviceId: "svc-filling",
      serviceName: "Composite Tooth Filling",
      reason: "Composite Tooth Filling",
      price: 1200,
      paid: false,
      date: "2026-09-17",
      startTime: "11:00",
      endTime: "11:45",
      appointmentDateTime: createTimestamp("2026-09-17", "11:00"),
      status: "pending",
      bookingSource: "staff_walkin",
      notes: "Second filling appointment request.",
      createdAt: createTimestamp("2026-09-14", "12:00"),
      updatedAt: createTimestamp("2026-09-14", "12:00"),
    },
    {
      id: "apt-w3-04",
      userId: uids["patient4@clinic.test"],
      userEmail: "patient4@clinic.test",
      firstName: "Bea",
      lastName: "Alonzo",
      phoneNumber: "09173334455",
      serviceId: "svc-whitening",
      serviceName: "Laser Teeth Whitening",
      reason: "Laser Teeth Whitening",
      price: 3500,
      paid: false,
      date: "2026-09-18",
      startTime: "15:00",
      endTime: "16:00",
      appointmentDateTime: createTimestamp("2026-09-18", "15:00"),
      status: "confirmed",
      bookingSource: "patient_web",
      notes: "Follow-up whitening touch-up session.",
      createdAt: createTimestamp("2026-09-13", "18:00"),
      updatedAt: createTimestamp("2026-09-14", "09:00"),
    },

    // ---------------- Week 4 (Sept 22 - Sept 30) ----------------
    {
      id: "apt-w4-01",
      userId: uids["patient3@clinic.test"],
      userEmail: "patient3@clinic.test",
      firstName: "Angelo",
      lastName: "Reyes",
      phoneNumber: "09172223344",
      serviceId: "svc-cleaning",
      serviceName: "Teeth Cleaning & Polishing",
      reason: "Teeth Cleaning & Polishing",
      price: 800,
      paid: false,
      date: "2026-09-22",
      startTime: "10:00",
      endTime: "10:30",
      appointmentDateTime: createTimestamp("2026-09-22", "10:00"),
      status: "pending",
      bookingSource: "patient_web",
      notes: "Routine cleaning booking for late September.",
      createdAt: createTimestamp("2026-09-14", "14:00"),
      updatedAt: createTimestamp("2026-09-14", "14:00"),
    },
  ];

  for (const apt of demoAppointments) {
    const { id, ...data } = apt;
    await db.collection("appointments").doc(id).set(data);
  }
  console.log(`✅ Created ${demoAppointments.length} realistic timeline appointments across September`);

  console.log("\n🎉 Production database seeding completed successfully!\n");
}

seed().catch(err => {
  console.error("Seeding failed:", err);
  process.exit(1);
});
