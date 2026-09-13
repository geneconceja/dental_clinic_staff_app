/**
 * patch-emulator-compat.js
 *
 * Fixes an incompatibility between firebase-tools (CLI emulator) and
 * firebase-functions v7 where the emulator runtime attempts to invoke
 * functions.config() during worker initialization. In v7, that method
 * threw a fatal error, crashing the emulator worker on every function call.
 */
const fs = require('fs');
const path = require('path');

const target = path.join(__dirname, 'node_modules', 'firebase-functions', 'lib', 'v1', 'config.js');

if (fs.existsSync(target)) {
  let content = fs.readFileSync(target, 'utf8');
  if (content.includes('throw new Error("functions.config()')) {
    content = content.replace(
      /throw new Error\("functions\.config\(\)[\s\S]*?"\);/,
      'return {};'
    );
    fs.writeFileSync(target, content, 'utf8');
    console.log('[patch-emulator-compat] Patched firebase-functions config() for emulator compatibility.');
  }
}
