#!/usr/bin/env node
/**
 * Import the extracted curriculum into Firestore.
 *
 * Reads what `extract_curriculum.py --write` produced in data/curriculum/ and
 * writes it verbatim. It does NOT derive a session's kind, tier or scope — the
 * extractor did that from the source spreadsheets, and the old importer's
 * `getSessionType(session_number)` (which overwrote the extractor's own type
 * with one guessed from the session number) is exactly the bug this replaces.
 *
 * Session doc IDs changed from `L{level}_J{juz}_H{hizb}_S{n}` to
 * `L{level}_J{juz}_S{n}` — a juz- or level-tier assessment belongs to no single
 * hizb. Stale docs under the old IDs would still satisfy every `level_id` /
 * `juz_number` query, so a re-import MUST purge the collection first.
 *
 * Usage:
 *   node import_curriculum.mjs --dry-run              # report only, writes nothing
 *   node import_curriculum.mjs --purge --write        # purge sessions, then import
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 node import_curriculum.mjs --purge --write
 */
import { readFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, '..', '..');
const dataDir = join(repoRoot, 'data', 'curriculum');
// firebase-admin lives in scripts/node_modules alongside the repo's other tooling.
const require = createRequire(join(repoRoot, 'scripts', 'package.json'));
const admin = require('firebase-admin');

const args = new Set(process.argv.slice(2));
const write = args.has('--write');
const purge = args.has('--purge');
const usingEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

if (!write) console.log('DRY RUN — nothing will be written. Pass --write to import.\n');

const readJson = (name) => {
  const path = join(dataDir, name);
  if (!existsSync(path)) throw new Error(`Missing ${path}. Run extract_curriculum.py --write first.`);
  return JSON.parse(readFileSync(path, 'utf8'));
};

// The extractor refuses to emit anything that fails validation, but the import
// is the last gate before this data reaches every client — re-check the two
// invariants that the old pipeline violated.
function assertFaithful(sessions) {
  const fabricated = sessions.filter((s) => !s.source);
  if (fabricated.length) {
    throw new Error(`${fabricated.length} session(s) carry no source provenance — refusing to import fabricated data.`);
  }
  const assessmentKinds = new Set(['sard', 'exam']);
  const mistyped = sessions.filter((s) => assessmentKinds.has(s.kind) && s.current_level_content);
  if (mistyped.length) {
    throw new Error(`${mistyped.length} assessment(s) carry lesson content — the old type-by-number bug. Refusing.`);
  }
}

async function purgeCollection(db, name) {
  let deleted = 0;
  for (;;) {
    const snap = await db.collection(name).limit(400).get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    deleted += snap.size;
  }
  return deleted;
}

async function importAll(db) {
  const levels = readJson('levels.json');
  const sessions = [];
  for (const level of levels) {
    const perLevel = readJson(`sessions_level_${level.id}.json`);
    sessions.push(...(Array.isArray(perLevel) ? perLevel : Object.values(perLevel)));
  }
  assertFaithful(sessions);

  const kinds = sessions.reduce((acc, s) => ({ ...acc, [s.kind]: (acc[s.kind] ?? 0) + 1 }), {});
  console.log(`Target: ${usingEmulator ? `emulator ${process.env.FIRESTORE_EMULATOR_HOST}` : 'PRODUCTION Firestore'}`);
  console.log(`${levels.length} levels, ${sessions.length} sessions —`, kinds);
  for (const level of levels) {
    console.log(`  level ${level.id}: juz ${level.juz_numbers.join(' → ')} (teaching order), ${level.session_count} sessions`);
  }

  if (!write) return;

  if (purge) {
    console.log(`\nPurging sessions… (doc IDs changed; stale L_J_H_S docs would otherwise survive)`);
    const n = await purgeCollection(db, 'sessions');
    console.log(`  deleted ${n} stale session docs`);
  }

  console.log('\nImporting levels…');
  const levelBatch = db.batch();
  for (const level of levels) {
    levelBatch.set(db.collection('levels').doc(`level_${level.id}`), level);
  }
  await levelBatch.commit();
  console.log(`  wrote ${levels.length} levels (with per-juz session counts)`);

  console.log('Importing sessions…');
  for (let i = 0; i < sessions.length; i += 400) {
    const chunk = sessions.slice(i, i + 400);
    const batch = db.batch();
    // Written verbatim: kind, tier, scope and provenance come from the source.
    chunk.forEach((s) => batch.set(db.collection('sessions').doc(s.id), s));
    await batch.commit();
    console.log(`  wrote ${Math.min(i + 400, sessions.length)}/${sessions.length}`);
  }
  console.log('\nDone.');
}

const serviceAccountPath = join(repoRoot, 'scripts', 'service-account.json');
if (usingEmulator) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT ?? 'demo-al-rasikhoon' });
} else {
  if (!existsSync(serviceAccountPath)) {
    console.error(`Missing ${serviceAccountPath} — needed to write to production Firestore.`);
    process.exit(1);
  }
  admin.initializeApp({ credential: admin.credential.cert(require(serviceAccountPath)) });
}

await importAll(admin.firestore());
process.exit(0);
