/**
 * test/globalSetup.js
 * Dental Clinic Staff/Admin App — Jest Global Setup
 *
 * Spawns the Firebase emulator suite (Auth + Firestore only) before the test
 * run begins and waits until both emulator ports are accepting connections.
 * Stores the child process PID in global.__EMULATOR_PID__ so globalTeardown
 * can shut it down cleanly after all tests finish.
 *
 * Ports must match firebase.json:
 *   Auth     → 9099
 *   Firestore → 8080
 */

"use strict";

const { spawn } = require("child_process");
const net = require("net");
const path = require("path");

// Project root is two levels up from functions/test/
const PROJECT_ROOT = path.resolve(__dirname, "..", "..");
const PROJECT_ID = "oralscope-78cda";

const EMULATOR_PORTS = [
  { name: "Firestore", port: 8080 },
  { name: "Auth", port: 9099 },
];

const READY_TIMEOUT_MS = 60_000;
const POLL_INTERVAL_MS = 500;

/**
 * Polls a TCP port until it accepts a connection or the timeout is reached.
 */
function waitForPort(port, timeoutMs) {
  return new Promise((resolve, reject) => {
    const deadline = Date.now() + timeoutMs;

    function attempt() {
      const socket = net.connect(port, "127.0.0.1");
      socket.once("connect", () => {
        socket.destroy();
        resolve();
      });
      socket.once("error", () => {
        socket.destroy();
        if (Date.now() >= deadline) {
          reject(new Error(`Port ${port} did not become ready within ${timeoutMs}ms`));
        } else {
          setTimeout(attempt, POLL_INTERVAL_MS);
        }
      });
    }

    attempt();
  });
}

module.exports = async function globalSetup() {
  console.log("\n[globalSetup] Starting Firebase emulators (auth, firestore)…");

  // Use npx on Windows to resolve the firebase binary reliably.
  const isWindows = process.platform === "win32";
  const cmd = isWindows ? "cmd" : "firebase";
  const args = isWindows
    ? ["/c", "firebase", "emulators:start", "--only", "auth,firestore", `--project=${PROJECT_ID}`]
    : ["emulators:start", "--only", "auth,firestore", `--project=${PROJECT_ID}`];

  const emulator = spawn(cmd, args, {
    cwd: PROJECT_ROOT,
    stdio: "pipe", // capture output so it doesn't pollute test output
    detached: false,
  });

  // Surface emulator errors to help debug startup failures
  emulator.stderr.on("data", (data) => {
    const msg = data.toString().trim();
    if (msg) process.stderr.write(`  [emulator stderr] ${msg}\n`);
  });

  emulator.on("error", (err) => {
    console.error("[globalSetup] Failed to spawn emulator process:", err.message);
  });

  // Persist PID so globalTeardown can kill it
  global.__EMULATOR_PID__ = emulator.pid;
  global.__EMULATOR_PROCESS__ = emulator;

  // Wait for all required ports to be ready
  console.log(`[globalSetup] Waiting for emulator ports: ${EMULATOR_PORTS.map((p) => p.port).join(", ")}…`);
  await Promise.all(
    EMULATOR_PORTS.map(({ name, port }) =>
      waitForPort(port, READY_TIMEOUT_MS).then(() =>
        console.log(`[globalSetup] ✓ ${name} emulator ready on :${port}`)
      )
    )
  );

  console.log("[globalSetup] All emulators ready. Starting test suite.\n");
};
