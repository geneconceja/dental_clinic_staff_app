# Local Emulator Testing Guide

This guide provides step-by-step instructions for running and testing the entire Dental Clinic App locally using the **Firebase Local Emulator Suite**.

Running on the local emulator suite allows you to test **Flutter Web, Firestore, Authentication, and all Cloud Functions** locally with **zero cost, no credit card, and zero cloud dependencies**.

---

## 1. Architecture Overview

When running locally with `--dart-define=ENV=dev`:

```
┌─────────────────────────────────────────────────────────────┐
│                      Your Local Machine                     │
│                                                             │
│   Flutter Web App (Chrome)                                  │
│   http://localhost:<random-port>                            │
│           │                                                 │
│           ▼ (ENV=dev redirects SDKs to localhost)           │
│   ┌─────────────────────────────────────────────────────┐   │
│   │             Firebase Emulator Suite                 │   │
│   │                                                     │   │
│   │   • Auth Emulator       : localhost:9099            │   │
│   │   • Firestore Emulator  : localhost:8080            │   │
│   │   • Functions Emulator  : localhost:5001            │   │
│   │   • Hosting Emulator    : localhost:5000            │   │
│   │   • Emulator Web UI     : http://localhost:4000     │   │
│   └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

All network calls from `FirebaseAuth`, `FirebaseFirestore`, and `FirebaseFunctions` are intercepted and routed to the local emulator daemon.

---

## 2. Prerequisites

Ensure your system has the following installed:

1. **Node.js** (v18, v20, or v22)
2. **Java Runtime (JRE/JDK 11+)** *(Required by Firebase to run the Firestore emulator)*
   - Test by running: `java -version`
3. **Firebase CLI**:
   ```bash
   npm install -g firebase-tools
   ```
4. **Flutter SDK** (3.x stable)
   - Test by running: `flutter --version`

---

## 3. Environment Configuration

### Root `.env` (Flutter Web)
Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```
*(When running against the emulator, dummy values in `.env` are completely fine because all network requests are redirected to `localhost`).*

### Functions `.env` (Cloud Functions)
Copy `functions/.env.example` to `functions/.env`:
```bash
cp functions/.env.example functions/.env
```
*(Brevo API keys are optional for local testing; simulated email outputs are printed directly to the emulator console).*

---

## 4. Compile Cloud Functions

Before launching the emulator suite, compile the TypeScript source code:

```bash
cd functions
npm install
npm run build
cd ..
```

---

## 5. Launch the Emulator Suite

From the project root directory, run:

```bash
firebase emulators:start
```

Once started, the terminal displays the active ports:
* **Authentication**: `localhost:9099`
* **Cloud Functions**: `localhost:5001`
* **Firestore**: `localhost:8080`
* **Hosting**: `localhost:5000`
* **Emulator UI**: `http://localhost:4000`

> 💡 **Open [http://localhost:4000](http://localhost:4000)** in your browser to view the interactive web console.

---

## 6. Seed Test Data (In a Second Terminal)

In a **separate terminal window**, run the seeding script:

```bash
node scripts/seed-emulator.js
```

This populates Firestore and Authentication with:
* Clinic settings (business hours, operating capacity)
* Dental services (Cleaning, Extraction, Whitening, etc.)
* Realistic appointment records across various statuses
* **Pre-configured test accounts:**

| Role | Email | Password | Features to Test |
| :--- | :--- | :--- | :--- |
| **Admin** | `admin@clinic.test` | `password123` | Full dashboard, staff creation, clinic configuration |
| **Staff (Front Desk)** | `staff1@clinic.test` | `password123` | Appointment review, calendar view, walk-in booking |
| **Patient** | `patient1@clinic.test` | `password123` | Patient portal, appointment history, booking wizard |

---

## 7. Run the Flutter Web App

In the second terminal, run Flutter targeting Chrome in dev mode:

```bash
flutter pub get
flutter run -d chrome --dart-define=ENV=dev
```

### Why `--dart-define=ENV=dev` is Required:
In `lib/main.dart`:
```dart
const String _env = String.fromEnvironment('ENV', defaultValue: 'prod');

if (_env == 'dev') {
  await configureEmulators();
}
```
When `ENV=dev`, `configureEmulators()` binds the Firebase SDKs to ports `9099`, `8080`, and `5001`.

---

## 8. Verifying Cloud Functions Locally

Open the **Logs tab** at [http://localhost:4000/functions](http://localhost:4000/functions) or observe the first terminal:

1. **Walk-In Booking**:
   * Create an appointment via the staff portal.
   * Verify log: `Beginning execution of "createWalkInAppointment"`.
2. **Staff Account Creation**:
   * Log in as `admin@clinic.test`, navigate to Staff Management, and create a new account.
   * Verify log: `Beginning execution of "createStaffUser"`.
3. **Appointment Status Change & Brevo Notification**:
   * Change an appointment status to "Confirmed" or "Completed".
   * Verify log: `Beginning execution of "onAppointmentStatusChange"`.

---

## 9. Persisting Test Data (Optional)

By default, emulator data is cleared when the process stops. To save and reload data between sessions:

```bash
# Export state on exit and re-import on start:
firebase emulators:start --export-on-exit=./emulator-data --import=./emulator-data
```
