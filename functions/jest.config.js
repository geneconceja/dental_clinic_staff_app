module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  testMatch: ["**/test/**/*.test.ts"],
  testTimeout: 20000, // rules-unit-testing + emulator round trips can be slow
};