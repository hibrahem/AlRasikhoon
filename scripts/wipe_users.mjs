// Wipe Firestore /users and the Firebase Auth user pool. DESTRUCTIVE.
// Refuses to run against production unless --i-know-what-im-doing is set.
//
// Usage:
//   GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json \
//   FIREBASE_PROJECT_ID=alrasikhoon-dev \
//   node wipe_users.mjs --confirm
//
// Add --i-know-what-im-doing to allow running against the production
// project (currently 'alrasikhoon-57151'). Without that flag, the script
// hard-stops if it detects the prod project ID.

import admin from 'firebase-admin';

const PROD_PROJECT_ID = 'alrasikhoon-57151';

function requireEnv(name) {
  const value = process.env[name];
  if (!value) {
    console.error(`Missing required env var: ${name}`);
    process.exit(1);
  }
  return value;
}

async function deleteCollectionInBatches(firestore, path) {
  const ref = firestore.collection(path);
  let total = 0;
  while (true) {
    const snap = await ref.limit(400).get();
    if (snap.empty) break;
    const batch = firestore.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    total += snap.size;
    console.log(`  deleted ${total} docs from /${path}`);
  }
  return total;
}

async function deleteAllAuthUsers(auth) {
  let total = 0;
  let pageToken;
  while (true) {
    const result = await auth.listUsers(1000, pageToken);
    if (result.users.length === 0) break;
    const uids = result.users.map((u) => u.uid);
    await auth.deleteUsers(uids);
    total += uids.length;
    console.log(`  deleted ${total} Firebase Auth users`);
    pageToken = result.pageToken;
    if (!pageToken) break;
  }
  return total;
}

async function main() {
  const args = process.argv.slice(2);
  if (!args.includes('--confirm')) {
    console.error('Refusing to run without --confirm');
    process.exit(2);
  }

  const projectId = requireEnv('FIREBASE_PROJECT_ID');
  if (
    projectId === PROD_PROJECT_ID &&
    !args.includes('--i-know-what-im-doing')
  ) {
    console.error(
      `Refusing to run against production project '${PROD_PROJECT_ID}'.`,
    );
    console.error(
      'Pass --i-know-what-im-doing if you really mean it.',
    );
    process.exit(3);
  }

  admin.initializeApp({ projectId });

  console.log(`Wiping users on ${projectId}...`);
  const userDocs = await deleteCollectionInBatches(admin.firestore(), 'users');
  const authUsers = await deleteAllAuthUsers(admin.auth());

  console.log(`Done. Removed ${userDocs} Firestore docs, ${authUsers} Auth users.`);
  console.log('Run seed_super_admin.mjs to re-bootstrap.');
}

main().catch((err) => {
  console.error('Wipe failed:', err);
  process.exit(1);
});
