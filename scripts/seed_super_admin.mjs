// Bootstrap a super-admin account on a fresh project.
//
// Usage:
//   GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json \
//   FIREBASE_PROJECT_ID=alrasikhoon-57151 \
//   SUPER_ADMIN_USERNAME=admin \
//   SUPER_ADMIN_PASSWORD=changeme123 \
//   SUPER_ADMIN_NAME='مدير النظام' \
//   node seed_super_admin.mjs
//
// Creates the Firebase Auth account '<username>@alrasikhoon.local'
// and writes /users/<uid> with role=super_admin.

import admin from 'firebase-admin';

const SYNTHESIZED_DOMAIN = 'alrasikhoon.local';

function requireEnv(name) {
  const value = process.env[name];
  if (!value) {
    console.error(`Missing required env var: ${name}`);
    process.exit(1);
  }
  return value;
}

async function main() {
  const projectId = requireEnv('FIREBASE_PROJECT_ID');
  const username = requireEnv('SUPER_ADMIN_USERNAME').trim().toLowerCase();
  const password = requireEnv('SUPER_ADMIN_PASSWORD');
  const name = requireEnv('SUPER_ADMIN_NAME');

  admin.initializeApp({ projectId });

  const email = `${username}@${SYNTHESIZED_DOMAIN}`;

  console.log(`Creating Firebase Auth account ${email} on ${projectId}...`);
  const userRecord = await admin.auth().createUser({ email, password });
  const uid = userRecord.uid;

  console.log(`Setting role=super_admin custom claim on ${uid}...`);
  await admin.auth().setCustomUserClaims(uid, { role: 'super_admin' });

  console.log(`Writing /users/${uid}...`);
  await admin.firestore().collection('users').doc(uid).set({
    username,
    email,
    name,
    role: 'super_admin',
    auth_provider: 'email_password',
    is_active: true,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log('Done. Super-admin can now sign in with:');
  console.log(`  username: ${username}`);
  console.log(`  password: ${password}`);
}

main().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
