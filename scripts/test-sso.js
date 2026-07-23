/**
 * test-sso.js
 * Quick test script to generate an SSO token for testing Phase 7.
 * Run via: node scripts/test-sso.js
 */

const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');

process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';

initializeApp({ projectId: 'oralscope-78cda' });

async function run() {
  const db = getFirestore();
  const auth = getAuth();

  const user = await auth.getUserByEmail('patient1@clinic.test');
  console.log(`Found test patient account: ${user.email} (UID: ${user.uid})`);

  const ssoToken = `sso_test_${Date.now()}`;
  const now = new Date();
  const expiresAtDate = new Date(now.getTime() + 5 * 60 * 1000); // 5 mins

  await db.collection('sso_tokens').doc(ssoToken).set({
    uid: user.uid,
    used: false,
    targetPath: '/patient/book',
    createdAt: FieldValue.serverTimestamp(),
    expiresAt: Timestamp.fromDate(expiresAtDate),
  });

  console.log('\n======================================================');
  console.log('✅ Generated Test Mobile-to-Web SSO Link:');
  console.log(`http://localhost:5000/#/sso?token=${ssoToken}&target=/patient/book`);
  console.log('======================================================\n');
  console.log('Copy the URL above and paste it into an Incognito browser window!');
}

run().catch(console.error);
