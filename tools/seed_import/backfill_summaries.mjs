// Piggery Evaluator: fill in every farmer's visit summary, once.
//
// The Cloud Function keeps summaries up to date from the moment it's
// deployed, but only for visits written AFTER that. This catches up on the
// visits made before (the EOs' first weeks), and can be run again any
// time: a farmer whose summary is already right isn't written.
//
// Uses the same calculation as the function (functions/summary.js), so
// the two can't disagree. Dry run by default, like the seed import.
//
//   node backfill_summaries.mjs            what would change, nothing written
//   node backfill_summaries.mjs --commit   write it

import { readFileSync } from 'node:fs';
import { parseArgs } from 'node:util';
import { initializeApp, cert } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

import { buildSummary, sameSummary } from '../../functions/summary.js';

const { values } = parseArgs({
  options: {
    key: { type: 'string', default: 'service-account.json' },
    commit: { type: 'boolean', default: false },
  },
});

initializeApp({ credential: cert(JSON.parse(readFileSync(values.key, 'utf8'))) });
const db = getFirestore();

// Every visit in one read, grouped by farmer: far fewer reads than one
// query per farmer.
const visits = await db.collection('visits').get();
const byFarmer = new Map();
for (const d of visits.docs) {
  const v = { id: d.id, ...d.data() };
  if (!v.farmer_id) continue;
  if (!byFarmer.has(v.farmer_id)) byFarmer.set(v.farmer_id, []);
  byFarmer.get(v.farmer_id).push(v);
}

// Farmers with a summary but no visits any more (a test visit deleted in
// the console, say) are cleared too.
const withSummary = await db.collection('farmers').where('summary.visit_count', '>', 0).get();
const ids = new Set([...byFarmer.keys(), ...withSummary.docs.map((d) => d.id)]);

let updated = 0, cleared = 0, unchanged = 0, missing = 0;
let batch = db.batch(), inBatch = 0;
for (const id of ids) {
  const ref = db.collection('farmers').doc(id);
  const snap = await ref.get();
  if (!snap.exists) { missing++; continue; }
  const next = buildSummary(byFarmer.get(id) ?? []);
  if (sameSummary(snap.get('summary'), next)) { unchanged++; continue; }
  next ? updated++ : cleared++;
  if (values.commit) {
    batch.update(ref, {
      summary: next ?? FieldValue.delete(),
      summary_updated_at: FieldValue.serverTimestamp(),
    });
    // Firestore takes at most 500 writes per batch.
    if (++inBatch === 400) { await batch.commit(); batch = db.batch(); inBatch = 0; }
  }
}
if (values.commit && inBatch > 0) await batch.commit();

console.log(`${visits.size} visits, ${byFarmer.size} farmers with visits`);
console.log(`  to update: ${updated}   to clear: ${cleared}   already right: ${unchanged}`);
if (missing) console.log(`  visits pointing at a farmer that doesn't exist: ${missing}`);
console.log(values.commit ? 'Written.' : 'Dry run: nothing written. Add --commit to write.');
