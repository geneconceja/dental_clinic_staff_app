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
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8085";
process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";

initializeApp({ projectId: "dental-clinic-ams" });

const db = getFirestore();
const auth = getAuth();

async function seed() {
  console.log("Seeding emulator data...\n");

  // ---------- 1. Staff/Admin Auth users + matching users/{uid} docs ----------

  const staffAccounts = [
    { email: "admin@clinic.test", password: "password123", role: "admin", name: "Dr. Santos (Admin)" },
    { email: "staff1@clinic.test", password: "password123", role: "staff", name: "Maria (Front Desk)" },
    { email: "staff2@clinic.test", password: "password123", role: "staff", name: "Jun (Front Desk)" },
    { email: "patient1@clinic.test", password: "password123", role: "patient", name: "Patient 1" },
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
          // Pre-verify email so the patient portal is immediately accessible
          // without manual steps in the Emulator UI.
          emailVerified: account.role === 'patient',
        });
        uid = userRecord.uid;
        console.log(`Created new auth account for ${account.role} user: ${account.email} (${uid})`);
      } else {
        throw e;
      }
    }

    staffUids[account.role + "_" + account.email] = uid;

    // Build the Firestore user doc. Patient accounts include extra fields
    // (firstName, lastName, isVerified) used by the patient portal and router.
    const isPatient = account.role === 'patient';
    const nameParts = account.name.split(' ');
    await db.collection("users").doc(uid).set({
      uid: uid,
      role: account.role,
      name: account.name,
      ...(isPatient && {
        firstName: nameParts[0] ?? account.name,
        lastName: nameParts.slice(1).join(' ') || '1',
        // true = bypass email verification gate in the router
        isVerified: true,
      }),
      email: account.email,
      phone: isPatient ? "09170000001" : "09171234567",
      active: true,
      createdAt: FieldValue.serverTimestamp(),
    });
    console.log(`Created/updated users/${uid} doc for ${account.email}`);
  }

  // ---------- 2. Services ----------

  const services = [
    { id: "svc-cleaning", name: "Teeth Cleaning", durationMinutes: 30, price: 800, description: "Routine dental cleaning and polishing", active: true },
    { id: "svc-checkup", name: "Follow-up Consultation", durationMinutes: 20, price: 300, description: "General dental check-up and consultation", active: true },
    { id: "svc-extraction", name: "Tooth Extraction", durationMinutes: 45, price: 1500, description: "Simple tooth extraction procedure", active: true },
    { id: "svc-filling", name: "Dental Filling", durationMinutes: 45, price: 1200, description: "Composite tooth-colored restoration", active: true },
    { id: "svc-whitening", name: "Teeth Whitening", durationMinutes: 60, price: 2500, description: "In-office professional teeth whitening", active: true },
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
  const patient1Uid = staffUids["patient_patient1@clinic.test"];

  // Clear existing appointments so no legacy/August appointments linger
  const existingAppts = await db.collection("appointments").get();
  for (const doc of existingAppts.docs) {
    await doc.ref.delete();
  }
  if (existingAppts.size > 0) {
    console.log(`Cleared ${existingAppts.size} existing appointment(s).`);
  }

  const appointments = [
    // -----------------------------------------------------------------------
    // SEPTEMBER 2026 (Sept 14 - Sept 30)
    // -----------------------------------------------------------------------

    // Week 1: Sept 14 - Sept 20
    {
      id: "appt-001",
      userId: patient1Uid,
      userEmail: "patient1@clinic.test",
      firstName: "Patient",
      lastName: "1",
      phoneNumber: "09170000001",
      serviceId: "svc-cleaning",
      serviceName: "Teeth Cleaning",
      reason: "Teeth Cleaning",
      date: "2026-09-14",
      appointmentDateTime: Timestamp.fromDate(new Date("2026-09-14T09:00:00+08:00")),
      startTime: "09:00",
      endTime: "09:30",
      notes: "Routine semi-annual dental cleaning; Resend notification test ready",
      imageUrl: null,
      analysisResults: null,
      status: "pending",
      bookingSource: "patient_app",
      createdBy: null,
      paid: false,
      reminderSent: false,
      createdAt: now,
      updatedAt: now,
    },
    {
      id: "appt-002",
      userId: null,
      userEmail: null,
      firstName: "Patient",
      lastName: "2",
      phoneNumber: "09170000002",
      serviceId: "svc-extraction",
      serviceName: "Tooth Extraction",
      reason: "Tooth Extraction",
      date: "2026-09-14",
      appointmentDateTime: Timestamp.fromDate(new Date("2026-09-14T10:00:00+08:00")),
      startTime: "10:00",
      endTime: "10:45",
      notes: "Walk-in patient; lower left molar extraction completed",
      imageUrl: null,
      analysisResults: null,
      status: "completed",
      bookingSource: "staff_walkin",
      createdBy: staffAdminUid,
      price: 1500,
      isFirstVisit: true,
      paid: true,
      reminderSent: false,
      createdAt: now,
      updatedAt: now,
    },
    {
      id: "appt-003",
      userId: "simulated-patient-uid-003",
      userEmail: "patient3@example.com",
      firstName: "Patient",
      lastName: "3",
      phoneNumber: "09170000003",
      serviceId: "svc-checkup",
      serviceName: "Follow-up Consultation",
      reason: "Follow-up Consultation",
      date: "2026-09-14",
      appointmentDateTime: Timestamp.fromDate(new Date("2026-09-14T14:00:00+08:00")),
      startTime: "14:00",
      endTime: "14:20",
      notes: "Post-treatment checkup",
      imageUrl: null,
      analysisResults: null,
      status: "confirmed",
      bookingSource: "patient_app",
      createdBy: null,
      paid: false,
      reminderSent: false,
      createdAt: now,
      updatedAt: now,
    },
    {
      id: "appt-004",
      userId: null,
      userEmail: null,
      firstName: "Patient",
      lastName: "4",
      phoneNumber: "09170000004",
      serviceId: "svc-filling",
      serviceName: "Dental Filling",
      reason: "Dental Filling",
      date: "2026-09-15",
      appointmentDateTime: Timestamp.fromDate(new Date("2026-09-15T09:30:00+08:00")),
      startTime: "09:30",
      endTime: "10:15",
      notes: "Walk-in; composite filling upper premolar",
      imageUrl: null,
      analysisResults: null,
      status: "completed",
      bookingSource: "staff_walkin",
      createdBy: staffAdminUid,
      price: 1200,
      isFirstVisit: false,
      paid: true,
      reminderSent: false,
      createdAt: now,
      updatedAt: now,
    },
    {
      id: "appt-005",
      userId: "simulated-patient-uid-005",
      userEmail: "patient5@example.com",
      firstName: "Patient",
      lastName: "5",
      phoneNumber: "09170000005",
      serviceId: "svc-whitening",
      serviceName: "Teeth Whitening",
      reason: "Teeth Whitening",
      date: "2026-09-15",
      appointmentDateTime: Timestamp.fromDate(new Date("2026-09-15T11:00:00+08:00")),
      startTime: "11:00",
      endTime: "12:00",
      notes: "In-office laser whitening session",
      imageUrl: null,
      analysisResults: null,
      status: "confirmed",
      bookingSource: "patient_app",
      createdBy: null,
      paid: false,
      reminderSent: false,
      createdAt: now,
      updatedAt: now,
    },
    {
      id: "appt-006",
      userId: "simulated-patient-uid-006",
      userEmail: "patient6@example.com",
      firstName: "Patient",
      lastName: "6",
      phoneNumber: "09170000006",
      serviceId: "svc-cleaning",
      serviceName: "Teeth Cleaning",
      reason: "Teeth Cleaning",
      date: "2026-09-16",
      appointmentDateTime: Timestamp.fromDate(new Date("2026-09-16T10:00:00+08:00")),
      startTime: "10:00",
      endTime: "10:30",
      notes: "Did not show up; phone unreachable",
      imageUrl: null,
      analysisResults: null,
      status: "no-show",
      bookingSource: "patient_app",
      createdBy: null,
      paid: false,
      reminderSent: false,
      createdAt: now,
      updatedAt: now,
    },
    {
      id: "appt-007",
      userId: null,
      userEmail: null,
      firstName: "Patient",
      lastName: "7",
      phoneNumber: "09170000007",
      serviceId: "svc-extraction",
      serviceName: "Tooth Extraction",
      reason: "Tooth Extraction",
      date: "2026-09-16",
      appointmentDateTime: Timestamp.fromDate(new Date("2026-09-16T14:00:00+08:00")),
      startTime: "14:00",
      endTime: "14:45",
      notes: "Walk-in scheduled for afternoon extraction",
      imageUrl: null,
      analysisResults: null,
      status: "confirmed",
      bookingSource: "staff_walkin",
      createdBy: staffAdminUid,
      paid: false,
      reminderSent: false,
      createdAt: now,
      updatedAt: now,
    },
    {
      id: "appt-008",
      userId: "simulated-patient-uid-008",
      userEmail: "patient8@example.com",
      firstName: "Patient",
      lastName: "8",
      phoneNumber: "09170000008",
      serviceId: "svc-checkup",
      serviceName: "Follow-up Consultation",
      reason: "Follow-up Consultation",
      date: "2026-09-17",
      appointmentDateTime: Timestamp.fromDate(new Date("2026-09-17T09:00:00+08:00")),
      startTime: "09:00",
      endTime: "09:20",
      notes: "Cancelled by patient via phone call",
      cancellationReason: "Schedule conflict with work",
      imageUrl: null,
      analysisResults: null,
      status: "cancelled",
      bookingSource: "patient_app",
      createdBy: null,
      paid: false,
      reminderSent: false,
      createdAt: now,
      updatedAt: now,
    },
    {
      id: "appt-009",
      userId: "simulated-patient-uid-009",
      userEmail: "patient9@example.com",
      firstName: "Patient",
      lastName: "9",
      phoneNumber: "09170000009",
      serviceId: "svc-filling",
      serviceName: "Dental Filling",
      reason: "Dental Filling",
      date: "2026-09-18",
      appointmentDateTime: Timestamp.fromDate(new Date("2026-09-18T10:30:00+08:00")),
      startTime: "10:30",
      endTime: "11:15",
      notes: "AI scan shows early caries on lower right molar",
      imageUrl: "https://res.cloudinary.com/demo/image/upload/sample-tooth.jpg",
      analysisResults: [
        { tag: "Early-stage caries", confidence: 0.88 },
      ],
      status: "confirmed",
      bookingSource: "patient_app",
      createdBy: null,
      paid: false,
      reminderSent: false,
      createdAt: now,
      updatedAt: now,
    },
    {
      id: "appt-010",
      userId: null,
      userEmail: null,
      firstName: "Patient",
      lastName: "10",
      phoneNumber: "09170000010",
      serviceId: "svc-whitening",
      serviceName: "Teeth Whitening",
      reason: "Teeth Whitening",
      date: "2026-09-19",
      appointmentDateTime: Timestamp.fromDate(new Date("2026-09-19T09:30:00+08:00")),
      startTime: "09:30",
      endTime: "10:30",
      notes: "Walk-in Saturday morning appointment; procedure successful",
      imageUrl: null,
      analysisResults: null,
      status: "completed",
      bookingSource: "staff_walkin",
      createdBy: staffAdminUid,
      price: 2500,
      isFirstVisit: true,
      paid: true,
      reminderSent: false,
      createdAt: now,
      updatedAt: now,
    },

    // Week 2: Sept 21 - Sept 27
    {
      id: "appt-011",
      userId: "simulated-patient-uid-011",
      userEmail: "patient11@example.com",
      firstName: "Patient",
      lastName: "11",
      phoneNumber: "09170000011",
      serviceId: "svc-cleaning",
      serviceName: "Teeth Cleaning",
      reason: "Teeth Cleaning",
      date: "2026-09-21",
      appointmentDateTime: Timestamp.fromDate(new Date("2026-09-21T09:00:00+08:00")),
      startTime: "09:00",
      endTime: "09:30",
      notes: "Routine cleaning, returning patient",
      imageUrl: null,
      analysisResults: null,
      status: "completed",
      bookingSource: "patient_app",
      createdBy: null,
      price: 800,
      isFirstVisit: false,
      paid: true,
      reminderSent: false,
      createdAt: now,
      updatedAt: now,
    },
    {
      id: "appt-012",
      userId: null,
      userEmail: null,
      firstName: "Patient",
      lastName: "12",
      phoneNumber: "09170000012",
      serviceId: "svc-extraction",
      serviceName: "Tooth Extraction",
      reason: "Tooth Extraction",
      date: "2026-09-22",
      appointmentDateTime: Timestamp.fromDate(new Date("2026-09-22T11:00:00+08:00")),
      startTime: "11:00",
      endTime: "11:45",
      notes: "Walk-in pending confirmation with dentist",
      imageUrl: null,
      analysisResults: null,
      status: "pending",
      bookingSource: "staff_walkin",
      createdBy: staffAdminUid,
      paid: false,
      reminderSent: false,
      createdAt: now,
      updatedAt: now,
    },
    {
      id: "appt-013",
      userId: "simulated-patient-uid-013",
      userEmail: "patient13@example.com",
      firstName: "Patient",
      lastName: "13",
      phoneNumber: "09170000013",
      serviceId: "svc-filling",
      serviceName: "Dental Filling",
      reason: "Dental Filling",
      date: "2026-09-23",
      appointmentDateTime: Timestamp.fromDate(new Date("2026-09-23T13:30:00+08:00")),
      startTime: "13:30",
      endTime: "14:15",
      notes: "First time filling, patient completed successfully",
      imageUrl: null,
      analysisResults: null,
      status: "completed",
      bookingSource: "patient_app",
      createdBy: null,
      price: 1200,
      isFirstVisit: true,
      paid: true,
      reminderSent: false,
      createdAt: now,
      updatedAt: now,
    },
    {
      id: "appt-014",
      userId: "simulated-patient-uid-014",
      userEmail: "patient14@example.com",
      firstName: "Patient",
      lastName: "14",
      phoneNumber: "09170000014",
      serviceId: "svc-checkup",
      serviceName: "Follow-up Consultation",
      reason: "Follow-up Consultation",
      date: "2026-09-25",
      appointmentDateTime: Timestamp.fromDate(new Date("2026-09-25T15:00:00+08:00")),
      startTime: "15:00",
      endTime: "15:20",
      notes: "Consultation on orthodontic options",
      imageUrl: null,
      analysisResults: null,
      status: "confirmed",
      bookingSource: "patient_app",
      createdBy: null,
      paid: false,
      reminderSent: false,
      createdAt: now,
      updatedAt: now,
    },

    // Week 3: Sept 28 - Sept 30
    {
      id: "appt-015",
      userId: null,
      userEmail: null,
      firstName: "Patient",
      lastName: "15",
      phoneNumber: "09170000015",
      serviceId: "svc-whitening",
      serviceName: "Teeth Whitening",
      reason: "Teeth Whitening",
      date: "2026-09-29",
      appointmentDateTime: Timestamp.fromDate(new Date("2026-09-29T10:00:00+08:00")),
      startTime: "10:00",
      endTime: "11:00",
      notes: "Walk-in whitening, second visit",
      imageUrl: null,
      analysisResults: null,
      status: "completed",
      bookingSource: "staff_walkin",
      createdBy: staffAdminUid,
      price: 2500,
      isFirstVisit: false,
      paid: true,
      reminderSent: false,
      createdAt: now,
      updatedAt: now,
    },
    {
      id: "appt-016",
      userId: "simulated-patient-uid-016",
      userEmail: "patient16@example.com",
      firstName: "Patient",
      lastName: "16",
      phoneNumber: "09170000016",
      serviceId: "svc-cleaning",
      serviceName: "Teeth Cleaning",
      reason: "Teeth Cleaning",
      date: "2026-09-30",
      appointmentDateTime: Timestamp.fromDate(new Date("2026-09-30T14:00:00+08:00")),
      startTime: "14:00",
      endTime: "14:30",
      notes: "End-of-month routine booking",
      imageUrl: null,
      analysisResults: null,
      status: "pending",
      bookingSource: "patient_app",
      createdBy: null,
      paid: false,
      reminderSent: false,
      createdAt: now,
      updatedAt: now,
    },

    // -----------------------------------------------------------------------
    // OCTOBER 2026
    // -----------------------------------------------------------------------
    {
      id: "appt-017",
      userId: "simulated-patient-uid-017",
      userEmail: "patient17@example.com",
      firstName: "Patient",
      lastName: "17",
      phoneNumber: "09170000017",
      serviceId: "svc-filling",
      serviceName: "Dental Filling",
      reason: "Dental Filling",
      date: "2026-10-06",
      appointmentDateTime: Timestamp.fromDate(new Date("2026-10-06T09:30:00+08:00")),
      startTime: "09:30",
      endTime: "10:15",
      notes: "Upcoming filling session",
      imageUrl: null,
      analysisResults: null,
      status: "confirmed",
      bookingSource: "patient_app",
      createdBy: null,
      paid: false,
      reminderSent: false,
      createdAt: now,
      updatedAt: now,
    },
    {
      id: "appt-018",
      userId: null,
      userEmail: null,
      firstName: "Patient",
      lastName: "18",
      phoneNumber: "09170000018",
      serviceId: "svc-extraction",
      serviceName: "Tooth Extraction",
      reason: "Tooth Extraction",
      date: "2026-10-15",
      appointmentDateTime: Timestamp.fromDate(new Date("2026-10-15T11:00:00+08:00")),
      startTime: "11:00",
      endTime: "11:45",
      notes: "Staff walk-in scheduled extraction",
      imageUrl: null,
      analysisResults: null,
      status: "pending",
      bookingSource: "staff_walkin",
      createdBy: staffAdminUid,
      paid: false,
      reminderSent: false,
      createdAt: now,
      updatedAt: now,
    },
    {
      id: "appt-019",
      userId: "simulated-patient-uid-019",
      userEmail: "patient19@example.com",
      firstName: "Patient",
      lastName: "19",
      phoneNumber: "09170000019",
      serviceId: "svc-cleaning",
      serviceName: "Teeth Cleaning",
      reason: "Teeth Cleaning",
      date: "2026-10-23",
      appointmentDateTime: Timestamp.fromDate(new Date("2026-10-23T14:00:00+08:00")),
      startTime: "14:00",
      endTime: "14:30",
      notes: "Confirmed patient app booking",
      imageUrl: null,
      analysisResults: null,
      status: "confirmed",
      bookingSource: "patient_app",
      createdBy: null,
      paid: false,
      reminderSent: false,
      createdAt: now,
      updatedAt: now,
    },

    // -----------------------------------------------------------------------
    // NOVEMBER 2026
    // -----------------------------------------------------------------------
    {
      id: "appt-020",
      userId: null,
      userEmail: null,
      firstName: "Patient",
      lastName: "20",
      phoneNumber: "09170000020",
      serviceId: "svc-whitening",
      serviceName: "Teeth Whitening",
      reason: "Teeth Whitening",
      date: "2026-11-04",
      appointmentDateTime: Timestamp.fromDate(new Date("2026-11-04T10:00:00+08:00")),
      startTime: "10:00",
      endTime: "11:00",
      notes: "Pre-booked staff walk-in whitening session",
      imageUrl: null,
      analysisResults: null,
      status: "confirmed",
      bookingSource: "staff_walkin",
      createdBy: staffAdminUid,
      paid: false,
      reminderSent: false,
      createdAt: now,
      updatedAt: now,
    },
    {
      id: "appt-021",
      userId: "simulated-patient-uid-021",
      userEmail: "patient21@example.com",
      firstName: "Patient",
      lastName: "21",
      phoneNumber: "09170000021",
      serviceId: "svc-checkup",
      serviceName: "Follow-up Consultation",
      reason: "Follow-up Consultation",
      date: "2026-11-18",
      appointmentDateTime: Timestamp.fromDate(new Date("2026-11-18T15:00:00+08:00")),
      startTime: "15:00",
      endTime: "15:20",
      notes: "Routine consultation request",
      imageUrl: null,
      analysisResults: null,
      status: "pending",
      bookingSource: "patient_app",
      createdBy: null,
      paid: false,
      reminderSent: false,
      createdAt: now,
      updatedAt: now,
    },

    // -----------------------------------------------------------------------
    // DECEMBER 2026 (up to Dec 31)
    // -----------------------------------------------------------------------
    {
      id: "appt-022",
      userId: "simulated-patient-uid-022",
      userEmail: "patient22@example.com",
      firstName: "Patient",
      lastName: "22",
      phoneNumber: "09170000022",
      serviceId: "svc-cleaning",
      serviceName: "Teeth Cleaning",
      reason: "Teeth Cleaning",
      date: "2026-12-08",
      appointmentDateTime: Timestamp.fromDate(new Date("2026-12-08T09:00:00+08:00")),
      startTime: "09:00",
      endTime: "09:30",
      notes: "Holiday season dental cleaning",
      imageUrl: null,
      analysisResults: null,
      status: "confirmed",
      bookingSource: "patient_app",
      createdBy: null,
      paid: false,
      reminderSent: false,
      createdAt: now,
      updatedAt: now,
    },
    {
      id: "appt-023",
      userId: null,
      userEmail: null,
      firstName: "Patient",
      lastName: "23",
      phoneNumber: "09170000023",
      serviceId: "svc-filling",
      serviceName: "Dental Filling",
      reason: "Dental Filling",
      date: "2026-12-17",
      appointmentDateTime: Timestamp.fromDate(new Date("2026-12-17T13:30:00+08:00")),
      startTime: "13:30",
      endTime: "14:15",
      notes: "Walk-in request for filling",
      imageUrl: null,
      analysisResults: null,
      status: "pending",
      bookingSource: "staff_walkin",
      createdBy: staffAdminUid,
      paid: false,
      reminderSent: false,
      createdAt: now,
      updatedAt: now,
    },
    {
      id: "appt-024",
      userId: "simulated-patient-uid-024",
      userEmail: "patient24@example.com",
      firstName: "Patient",
      lastName: "24",
      phoneNumber: "09170000024",
      serviceId: "svc-extraction",
      serviceName: "Tooth Extraction",
      reason: "Tooth Extraction",
      date: "2026-12-28",
      appointmentDateTime: Timestamp.fromDate(new Date("2026-12-28T10:00:00+08:00")),
      startTime: "10:00",
      endTime: "10:45",
      notes: "Year-end wisdom tooth consultation and extraction",
      imageUrl: null,
      analysisResults: null,
      status: "confirmed",
      bookingSource: "patient_app",
      createdBy: null,
      paid: false,
      reminderSent: false,
      createdAt: now,
      updatedAt: now,
    },
  ];

  for (const appt of appointments) {
    const { id, ...data } = appt;
    await db.collection("appointments").doc(id).set(data);
    console.log(`Created appointment: ${id} (${data.status}, ${data.bookingSource}, ${data.date})`);
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