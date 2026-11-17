// Piggery Evaluator - create the starting settings documents.
//
//   settings/targets     the 8 KPI targets from the paper form. Every visit
//                        copies these when it starts. Admins edit them later
//                        from the web app.
//   settings/projection  slaughter age (months) and how old a herd count may
//                        be before projections ignore it.
//
// Only creates what's MISSING: never overwrites values the office has
// already changed. Dry run by default; add --commit to write.
//   node seed_settings.mjs --key service-account.json [--commit]

import { readFileSync } from 'node:fs';
import { parseArgs } from 'node:util';

const DOCS = {
  // Must match defaultTargets in lib/constants/visit_template.dart.
  targets: {
    born_alive: 13,
    pre_wean_mortality_pct: 5,
    post_wean_mortality_pct: 2,
    weaning_age_days: 35,
    weaning_weight_kg: 8,
    slaughter_age_weeks: 24,
    finish_weight_kg: 105,
    pigs_per_sow_year: 26,
  },
  // 8 months reproduces the existing projections workbook; revisit once
  // the 8-months-vs-24-weeks question is answered.
  projection: {
    slaughter_age_months: 8,
    stale_after_months: 9,
  },
};

const { values } = parseArgs({
  options: { key: { type: 'string' }, commit: { type: 'boolean', default: false } },
});
if (!values.key) {
  console.error('Usage: node seed_settings.mjs --key service-account.json [--commit]');
  process.exit(1);
}

const { initializeApp, cert } = await import('firebase-admin/app');
const { getFirestore, FieldValue } = await import('firebase-admin/firestore');
initializeApp({ credential: cert(JSON.parse(readFileSync(values.key, 'utf8'))) });
const db = getFirestore();

console.log(`Mode: ${values.commit ? 'COMMIT' : 'DRY RUN'}`);
for (const [id, data] of Object.entries(DOCS)) {
  const ref = db.collection('settings').doc(id);
  const snap = await ref.get();
  if (snap.exists) {
    console.log(`  settings/${id}: already exists, left alone`);
    continue;
  }
  console.log(`  settings/${id}: ${values.commit ? 'creating' : 'would create'} ${JSON.stringify(data)}`);
  if (values.commit) {
    await ref.set({ ...data, updated_at: FieldValue.serverTimestamp(), updated_by: 'seed_settings' });
  }
}
if (!values.commit) console.log('Dry run: nothing was written. Add --commit to create.');
