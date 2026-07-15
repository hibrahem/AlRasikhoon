/**
 * backfill-institute-id.ts — one-off maintenance migration.
 *
 * WHY THIS EXISTS
 *   AgDR-0003 denormalized `institute_id` onto students/{id} so both the
 *   Firestore rules and the supervisor Cloud Functions can scope by institute
 *   with NO multi-hop read. Commit 51c0dcb introduced the field but DEFERRED
 *   backfilling students created before it existed (see the note on
 *   isSupervisorOfStudentInstitute in firestore.rules). Both that rule and the
 *   supervisor branch of setUserPassword (functions/src/index.ts) FAIL CLOSED
 *   for any student doc missing `institute_id`: a student with no institute_id
 *   is treated as out-of-scope and DENIED. The intended, safe behaviour — but
 *   it means a legitimate supervisor cannot reset the password of (or otherwise
 *   act on) a real student in their institute until that student's
 *   `institute_id` is backfilled. This script performs that backfill.
 *   Issue: al_rasikhoon-7q5 (surfaced by the functions audit al_rasikhoon-fh2).
 *
 * DERIVATION RULE (source of truth)
 *   A student's institute is the institute of their TEACHER. This mirrors the
 *   ONLY two write paths that set institute_id at creation
 *   (lib/features/teacher/screens/add_student_screen.dart +
 *   lib/data/repositories/student_repository.dart#createStudent):
 *     - Teacher flow: the teacher picks one of THEIR institutes
 *       (getInstitutesForTeacher) and the student is assigned teacher_id =
 *       that teacher. So student.institute_id is always one of the teacher's
 *       institutes.
 *     - Supervisor flow: institute = supervisor's bound institute, and the
 *       chosen teacher is one from that same institute.
 *   In BOTH paths student.institute_id ∈ institutes(student.teacher_id), where
 *   the teacher→institute mapping is the `teacher_institutes` collection
 *   (active assignments only — is_active == true), exactly as
 *   InstituteRepository.getInstitutesForTeacher reads it. (Teachers do NOT
 *   carry users/{uid}.institute_id — only supervisors do — so
 *   teacher_institutes is the authoritative source.)
 *
 *   Therefore, for a student missing institute_id:
 *     - teacher_id present AND that teacher has EXACTLY ONE active institute
 *         -> backfill institute_id = that institute (UNAMBIGUOUS).
 *     - teacher_id present but the teacher has MULTIPLE active institutes
 *         -> AMBIGUOUS: we cannot know which one the creator originally picked.
 *            SKIP and REPORT. Never guess.
 *     - teacher_id present but the teacher has ZERO active institutes
 *         -> cannot derive. SKIP and REPORT.
 *     - teacher_id absent/empty (teacher-less student)
 *         -> cannot derive. SKIP and REPORT.
 *
 * SAFETY
 *   Dry-run is the DEFAULT: with no flags the script lists every students doc
 *   missing institute_id, the value it WOULD set, and the derivation source —
 *   and writes NOTHING. It only writes when explicitly passed --write (alias
 *   --apply). It is idempotent: docs that already carry a non-empty
 *   institute_id are skipped, so re-running after a partial apply is safe.
 *
 * USAGE
 *   # from functions/ :
 *   npm run backfill:institute-id                 # DRY RUN (writes nothing)
 *   npm run backfill:institute-id -- --write      # APPLY the backfill
 *
 *   Credentials: uses Application Default Credentials. For production, run with
 *   a service account, e.g.
 *     GOOGLE_APPLICATION_CREDENTIALS=/path/sa.json \
 *     GOOGLE_CLOUD_PROJECT=<project-id> npm run backfill:institute-id
 *   Against the Firestore emulator, set FIRESTORE_EMULATOR_HOST (firebase-admin
 *   honours it automatically), e.g.
 *     FIRESTORE_EMULATOR_HOST=localhost:8080 GOOGLE_CLOUD_PROJECT=demo-al-rasikhoon \
 *     npm run backfill:institute-id -- --write
 */

import * as admin from "firebase-admin";

/** Firestore allows up to 500 writes per batch; stay well under. */
const BATCH_LIMIT = 400;

interface Flags {
  write: boolean;
}

function parseFlags(argv: string[]): Flags {
  const write = argv.includes("--write") || argv.includes("--apply");
  const unknown = argv.filter(
    (a) => a.startsWith("--") && !["--write", "--apply"].includes(a),
  );
  if (unknown.length > 0) {
    throw new Error(
      `Unknown flag(s): ${unknown.join(", ")}. ` +
        "Supported: --write (alias --apply). Default is dry-run.",
    );
  }
  return { write };
}

/** A student doc that needs institute_id, once we know what to do with it. */
interface Backfillable {
  studentId: string;
  teacherId: string;
  instituteId: string;
}

interface Skipped {
  studentId: string;
  reason: string;
}

/**
 * Resolve the sole active institute for a teacher, or null if the teacher has
 * zero or MORE THAN ONE active institute (ambiguous). Results are memoized so
 * a shared teacher is only queried once.
 */
class TeacherInstituteResolver {
  private readonly db: admin.firestore.Firestore;
  private readonly cache = new Map<string, string | null>();

  constructor(db: admin.firestore.Firestore) {
    this.db = db;
  }

  /**
   * @returns { instituteId } when the teacher has exactly one active institute,
   *          or { reason } explaining why it could not be resolved.
   */
  async resolve(
    teacherId: string,
  ): Promise<{ instituteId: string } | { reason: string }> {
    if (this.cache.has(teacherId)) {
      const cached = this.cache.get(teacherId) ?? null;
      return cached === null
        ? { reason: "teacher has no single active institute" }
        : { instituteId: cached };
    }

    const snap = await this.db
      .collection("teacher_institutes")
      .where("teacher_id", "==", teacherId)
      .where("is_active", "==", true)
      .get();

    const instituteIds = Array.from(
      new Set(
        snap.docs
          .map((d) => d.data().institute_id)
          .filter(
            (v): v is string => typeof v === "string" && v.trim().length > 0,
          )
          .map((v) => v.trim()),
      ),
    );

    if (instituteIds.length === 1) {
      this.cache.set(teacherId, instituteIds[0]);
      return { instituteId: instituteIds[0] };
    }

    this.cache.set(teacherId, null);
    if (instituteIds.length === 0) {
      return {
        reason: `teacher ${teacherId} has no active teacher_institutes mapping`,
      };
    }
    return {
      reason:
        `teacher ${teacherId} belongs to ${instituteIds.length} active ` +
        `institutes (${instituteIds.join(", ")}) — cannot disambiguate`,
    };
  }
}

/** True when a value is a present, non-empty institute id string. */
function hasInstituteId(value: unknown): boolean {
  return typeof value === "string" && value.trim().length > 0;
}

async function main(): Promise<void> {
  const flags = parseFlags(process.argv.slice(2));
  const mode = flags.write ? "WRITE (applying backfill)" : "DRY RUN (no writes)";

  admin.initializeApp();
  const db = admin.firestore();
  const resolver = new TeacherInstituteResolver(db);

  // eslint-disable-next-line no-console
  console.log(`\n=== backfill-institute-id — ${mode} ===\n`);

  const studentsSnap = await db.collection("students").get();
  const total = studentsSnap.size;

  let alreadyPresent = 0;
  const backfillable: Backfillable[] = [];
  const skipped: Skipped[] = [];

  for (const doc of studentsSnap.docs) {
    const data = doc.data();

    // Idempotent: anything that already carries a real institute_id is done.
    if (hasInstituteId(data.institute_id)) {
      alreadyPresent += 1;
      continue;
    }

    const teacherId = data.teacher_id;
    if (typeof teacherId !== "string" || teacherId.trim().length === 0) {
      skipped.push({
        studentId: doc.id,
        reason: "student has no teacher_id (teacher-less) — cannot derive institute",
      });
      continue;
    }

    const resolved = await resolver.resolve(teacherId.trim());
    if ("reason" in resolved) {
      skipped.push({ studentId: doc.id, reason: resolved.reason });
      continue;
    }

    backfillable.push({
      studentId: doc.id,
      teacherId: teacherId.trim(),
      instituteId: resolved.instituteId,
    });
  }

  const missing = backfillable.length + skipped.length;

  // ---- Report the plan (both modes) ---------------------------------------
  /* eslint-disable no-console */
  console.log("Backfillable (missing institute_id, derivation found):");
  if (backfillable.length === 0) {
    console.log("  (none)");
  } else {
    for (const b of backfillable) {
      console.log(
        `  student ${b.studentId}: institute_id -> ${b.instituteId} ` +
          `(source: teacher_institutes of teacher ${b.teacherId})`,
      );
    }
  }

  console.log("\nSkipped — AMBIGUOUS/UNRESOLVABLE (left untouched, needs manual review):");
  if (skipped.length === 0) {
    console.log("  (none)");
  } else {
    for (const s of skipped) {
      console.log(`  student ${s.studentId}: ${s.reason}`);
    }
  }
  /* eslint-enable no-console */

  // ---- Apply (write mode only) --------------------------------------------
  let written = 0;
  if (flags.write && backfillable.length > 0) {
    // eslint-disable-next-line no-console
    console.log("\nApplying writes in batches...");
    for (let i = 0; i < backfillable.length; i += BATCH_LIMIT) {
      const chunk = backfillable.slice(i, i + BATCH_LIMIT);
      const batch = db.batch();
      for (const b of chunk) {
        const ref = db.collection("students").doc(b.studentId);
        batch.set(
          ref,
          {
            institute_id: b.instituteId,
            // Audit trail: mark that this value came from the backfill, not a
            // human edit, so a later reviewer can tell derived from authored.
            institute_id_backfilled_at:
              admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
        // eslint-disable-next-line no-console
        console.log(
          `  [write] student ${b.studentId}: before=<absent> after=${b.instituteId}`,
        );
      }
      await batch.commit();
      written += chunk.length;
    }
  }

  // ---- Summary ------------------------------------------------------------
  /* eslint-disable no-console */
  console.log("\n=== Summary ===");
  console.log(`  total students scanned : ${total}`);
  console.log(`  already had institute  : ${alreadyPresent}`);
  console.log(`  missing institute      : ${missing}`);
  console.log(`    - backfillable       : ${backfillable.length}`);
  console.log(`    - skipped (ambiguous): ${skipped.length}`);
  if (flags.write) {
    console.log(`  WRITTEN                : ${written}`);
  } else {
    console.log(
      `  WRITTEN                : 0 (dry run — re-run with --write to apply)`,
    );
  }
  console.log("");
  /* eslint-enable no-console */

  if (!flags.write && backfillable.length > 0) {
    // eslint-disable-next-line no-console
    console.log(
      "Dry run only. Review the plan above, then apply with:\n" +
        "  npm run backfill:institute-id -- --write\n",
    );
  }
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    // eslint-disable-next-line no-console
    console.error("backfill-institute-id FAILED:", err);
    process.exit(1);
  });
