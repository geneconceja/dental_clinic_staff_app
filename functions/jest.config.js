// Set emulator environment variables before any tests or imports load.
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";
process.env.GCLOUD_PROJECT = "oralscope-78cda";

module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  // Match all .test.ts files under test/, but exclude the smoke/ subdirectory
  // (smoke scripts are standalone Node scripts, not Jest suites).
  testMatch: ["**/test/**/*.test.ts"],
  testPathIgnorePatterns: ["/node_modules/", "/test/smoke/"],
  testTimeout: 30000, // concurrency tests + emulator round-trips need up to 30s
};