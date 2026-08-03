/**
 * test/globalTeardown.js
 * Dental Clinic Staff/Admin App — Jest Global Teardown
 *
 * Terminates the Firebase emulator process that was started in globalSetup.js
 * after all test suites have finished. Uses SIGTERM on POSIX and taskkill on
 * Windows to ensure the child process (and its Java subprocess) are cleaned up.
 */

"use strict";

const { execSync } = require("child_process");

module.exports = async function globalTeardown() {
  console.log("\n[globalTeardown] Stopping Firebase emulators…");

  const emulator = global.__EMULATOR_PROCESS__;
  const pid = global.__EMULATOR_PID__;

  if (!emulator || !pid) {
    console.warn("[globalTeardown] No emulator process reference found. Nothing to stop.");
    return;
  }

  try {
    if (process.platform === "win32") {
      // On Windows, kill the entire process tree (includes Java subprocess)
      execSync(`taskkill /PID ${pid} /T /F`, { stdio: "ignore" });
    } else {
      // On POSIX, SIGTERM the process group
      process.kill(-pid, "SIGTERM");
    }
    console.log(`[globalTeardown] Emulator process (PID ${pid}) terminated.`);
  } catch (err) {
    // Process may have already exited — not a fatal error
    console.warn(`[globalTeardown] Could not kill emulator process: ${err.message}`);
  }
};
