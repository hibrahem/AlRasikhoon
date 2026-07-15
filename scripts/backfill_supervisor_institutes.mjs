// Backfill supervisor_institutes membership docs for existing supervisors
// (al_rasikhoon-3n6).
//
// As of al_rasikhoon-3n6 the SOURCE OF TRUTH for supervisor institute scoping
// is the membership doc supervisor_institutes/{uid}_{instituteId} — NOT
// users/{uid}.institute_id. createUserAccount has written BOTH since #28, so
// supervisors created since then already have a membership doc. This script
// exists to catch OLDER supervisors (or any drift) whose users/{uid} doc still
// carries an institute_id that has no matching membership doc, and create the
// missing membership so rules/providers resolve their scope.
//
// SAFETY:
//   * --dry-run is the DEFAULT: with no flags the script WRITES NOTHING, it only
//     reports what it WOULD create. You must pass --write to actually create
//     membership docs.
//   * Idempotent: a membership doc that already exists (active or inactive) is
//     left UNTOUCHED — the script never flips is_active, never overwrites, and
//     re-running it is a no-op after the first successful --write.
//   * It NEVER deletes anything and NEVER touches users/{uid}.institute_id.
//     Dropping that field is a SEPARATE, later, human-run step, only after rules
//     and clients no longer read it (they no longer do as of al_rasikhoon-3n6,
//     but the field is still used for non-supervisor purposes — do not drop it
//     as part of this migration).
//
// Usage (DRY-RUN, writes nothing):
//   GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json \
//   FIREBASE_PROJECT_ID=alrasikhoon-57151 \
//   node backfill_supervisor_institutes.mjs
//
// Usage (ACTUALLY WRITE):
//   GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json \
//   FIREBASE_PROJECT_ID=alrasikhoon-57151 \
//   node backfill_supervisor_institutes.mjs --write
//
// DO NOT run --write against production without an explicit human decision.

import admin from 'firebase-admin';

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
  const write = process.argv.includes('--write');
  const mode = write ? 'WRITE' : 'DRY-RUN';

  admin.initializeApp({ projectId });
  const firestore = admin.firestore();

  console.log(
    `Backfilling supervisor_institutes on ${projectId} — mode: ${mode}` +
      (write ? '' : ' (no writes; pass --write to apply)'),
  );

  // Every supervisor account.
  const supervisors = await firestore
    .collection('users')
    .where('role', '==', 'supervisor')
    .get();

  let scanned = 0;
  let missingInstituteField = 0;
  let alreadyPresent = 0;
  let created = 0;
  let wouldCreate = 0;

  for (const supervisorDoc of supervisors.docs) {
    scanned += 1;
    const uid = supervisorDoc.id;
    const instituteId = supervisorDoc.data().institute_id;

    // A supervisor with no legacy institute_id has nothing to backfill FROM.
    // Their memberships (if any) were written directly and are the truth; this
    // script only reconciles the legacy field into a membership.
    if (typeof instituteId !== 'string' || instituteId.trim().length === 0) {
      missingInstituteField += 1;
      continue;
    }

    const membershipId = `${uid}_${instituteId}`;
    const membershipRef = firestore
      .collection('supervisor_institutes')
      .doc(membershipId);
    const existing = await membershipRef.get();

    if (existing.exists) {
      // Idempotent: leave it exactly as-is (active OR soft-deleted). We do NOT
      // resurrect an intentionally removed (is_active:false) membership.
      alreadyPresent += 1;
      continue;
    }

    if (write) {
      await membershipRef.set({
        supervisor_id: uid,
        institute_id: instituteId,
        assigned_at: admin.firestore.FieldValue.serverTimestamp(),
        is_active: true,
        backfilled: true,
      });
      created += 1;
      console.log(`  CREATED  supervisor_institutes/${membershipId}`);
    } else {
      wouldCreate += 1;
      console.log(`  WOULD CREATE  supervisor_institutes/${membershipId}`);
    }
  }

  console.log('\nSummary:');
  console.log(`  supervisors scanned        : ${scanned}`);
  console.log(`  no legacy institute_id     : ${missingInstituteField}`);
  console.log(`  membership already present : ${alreadyPresent}`);
  if (write) {
    console.log(`  memberships created        : ${created}`);
  } else {
    console.log(`  memberships that WOULD be created : ${wouldCreate}`);
    console.log('\nDRY-RUN only — nothing was written. Re-run with --write to apply.');
  }
}

main().catch((err) => {
  console.error('Backfill failed:', err);
  process.exit(1);
});
