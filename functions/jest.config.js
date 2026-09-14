/**
 * jest.config.js
 * Dental Clinic Staff/Admin App — Jest Configuration
 *
 * Emulator environment variables are set here (earliest possible point) so
 * they are in place before firebase-admin initialises in any test or handler.
 *
 * globalSetup  → spawns Firebase emulators (auth + firestore) before any test
 * globalTeardown → shuts them down after all tests complete
 */

// Must be set before any firebase-admin import resolves.
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8085";
process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";
process.env.GCLOUD_PROJECT = "dental-clinic-ams";

module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",

  // Auto-launch emulators before the suite and shut them down after.
  globalSetup: "./test/globalSetup.js",
  globalTeardown: "./test/globalTeardown.js",

  // Match all .test.ts files under test/, but exclude the smoke/ subdirectory
  // (smoke scripts are standalone Node scripts, not Jest suites).
  testMatch: ["**/test/**/*.test.ts"],
  testPathIgnorePatterns: ["/node_modules/", "/test/smoke/"],

  testTimeout: 60000, // emulator cold-start adds latency on first run

  // Prevent Jest from hanging if emulator teardown is slow.
  forceExit: true,
};