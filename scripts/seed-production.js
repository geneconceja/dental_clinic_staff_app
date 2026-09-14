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
        firstName: nameParts[0] || "Juan",
        lastName: nameParts.slice(1).join(" ") || "Dela Cruz",
        isVerified: true,
      }),
      createdAt: FieldValue.serverTimestamp(),
    });
    console.log(`✅ Provisioned users/${uid} (${acc.role})`);
  }

  // 4. Appointments across Timeline (for rich dashboard analytics & review queue)
  const today = new Date();
  const todayStr = today.toISOString().split("T")[0];

  const yesterday = new Date(today);
  yesterday.setDate(today.getDate() - 1);
  const yesterdayStr = yesterday.toISOString().split("T")[0];

  const tomorrow = new Date(today);
  tomorrow.setDate(today.getDate() + 1);
  const tomorrowStr = tomorrow.toISOString().split("T")[0];

  const demoAppointments = [
    // Completed yesterday (contributes to revenue & past history)
    {
      id: "apt-completed-1",
      userId: uids.patient,
      userEmail: "patient1@clinic.test",
      userName: "Juan Dela Cruz",
      userPhone: "09179998877",
      serviceId: "svc-cleaning",
      serviceName: "Teeth Cleaning & Polishing",
      servicePrice: 800,
      serviceDurationMinutes: 30,
      date: yesterdayStr,
      time: "10:00",
      dateTime: `${yesterdayStr}T10:00:00.000Z`,
      endTime: `${yesterdayStr}T10:30:00.000Z`,
      status: "completed",
      bookingSource: "patient_portal",
      notes: "Routine visit, regular checkup completed.",
      createdAt: Timestamp.fromDate(yesterday),
      updatedAt: Timestamp.fromDate(yesterday),
    },
    // Confirmed today
    {
      id: "apt-today-1",
      userId: null,
      userEmail: null,
      userName: "Corazon Aquino",
      userPhone: "09181112233",
      serviceId: "svc-filling",
      serviceName: "Composite Tooth Filling",
      servicePrice: 1200,
      serviceDurationMinutes: 45,
      date: todayStr,
      time: "11:00",
      dateTime: `${todayStr}T11:00:00.000Z`,
      endTime: `${todayStr}T11:45:00.000Z`,
      status: "confirmed",
      bookingSource: "staff_walkin",
      notes: "Walk-in patient for lower molar filling.",
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    },
    // Pending in Review Queue (for Staff to review)
    {
      id: "apt-pending-1",
      userId: uids.patient,
      userEmail: "patient1@clinic.test",
      userName: "Juan Dela Cruz",
      userPhone: "09179998877",
      serviceId: "svc-whitening",
      serviceName: "Laser Teeth Whitening",
      servicePrice: 3500,
      serviceDurationMinutes: 60,
      date: tomorrowStr,
      time: "14:00",
      dateTime: `${tomorrowStr}T14:00:00.000Z`,
      endTime: `${tomorrowStr}T15:00:00.000Z`,
      status: "pending",
      bookingSource: "patient_portal",
      notes: "Requested afternoon slot for laser whitening.",
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    },
  ];

  for (const apt of demoAppointments) {
    const { id, ...data } = apt;
    await db.collection("appointments").doc(id).set(data);
  }
  console.log(`✅ Created ${demoAppointments.length} sample appointments (Completed, Confirmed, Pending Review)`);

  console.log("\n🎉 Production database seeding completed successfully!\n");
}

seed().catch(err => {
  console.error("Seeding failed:", err);
  process.exit(1);
});
