// Delete every Firebase Auth user (and their /users/{uid} Firestore doc)
// EXCEPT the super-admin account(s). DESTRUCTIVE and irreversible.
//
// Preserves any user whose uid is in PRESERVE_UIDS or whose custom claim
// role === 'super_admin'. Requires --confirm; requires --i-know-what-im-doing
// to run against production.
//
// Usage:
//   node delete_users_except_admin.mjs --confirm --i-know-what-im-doing
//
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const require = createRequire(join(here, 'package.json'));
const admin = require('firebase-admin');

const PROD_PROJECT_ID = 'alrasikhoon-57151';
// Super-admin to keep: admin@alrasikhoon.local (محمد الجبلاوي)
const PRESERVE_UIDS = new Set(['dYP8antMcJWMYtn9dARCKY76NZg2']);

const args = new Set(process.argv.slice(2));
if (!args.has('--confirm')) {
  console.error('Refusing to run without --confirm');
  process.exit(2);
}

const serviceAccount = require(join(here, 'service-account.json'));
const projectId = serviceAccount.project_id;
if (projectId === PROD_PROJECT_ID && !args.has('--i-know-what-im-doing')) {
  console.error(`Refusing to run against production '${PROD_PROJECT_ID}' without --i-know-what-im-doing.`);
  process.exit(3);
}

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const auth = admin.auth();
const db = admin.firestore();

function keep(user) {
  if (PRESERVE_UIDS.has(user.uid)) return true;
  const role = user.customClaims?.role;
  return role === 'super_admin';
}

async function main() {
  console.log(`Target: ${projectId}`);

  // Collect every user, partition into keep / delete.
  const toDelete = [];
  const kept = [];
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    for (const u of page.users) (keep(u) ? kept : toDelete).push(u);
    pageToken = page.pageToken;
  } while (pageToken);

  console.log(`Keeping ${kept.length}: ${kept.map((u) => u.email ?? u.uid).join(', ')}`);
  console.log(`Deleting ${toDelete.length} auth users + their /users docs...`);

  let authDeleted = 0;
  let docsDeleted = 0;
  for (let i = 0; i < toDelete.length; i += 100) {
    const chunk = toDelete.slice(i, i + 100);
    const uids = chunk.map((u) => u.uid);

    const res = await auth.deleteUsers(uids);
    authDeleted += res.successCount;
    if (res.failureCount) {
      for (const e of res.errors) console.error(`  auth delete failed [${uids[e.index]}]: ${e.error.message}`);
    }

    const batch = db.batch();
    uids.forEach((uid) => batch.delete(db.collection('users').doc(uid)));
    await batch.commit();
    docsDeleted += uids.length;

    console.log(`  progress: ${authDeleted} auth users, ${docsDeleted} /users docs`);
  }

  console.log(`Done. Deleted ${authDeleted} auth users and ${docsDeleted} Firestore /users docs. Kept ${kept.length}.`);
}

main().catch((err) => {
  console.error('Failed:', err);
  process.exit(1);
});
