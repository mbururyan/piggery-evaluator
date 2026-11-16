// Piggery Evaluator - one-off seed import of the cleaned farmer list.
//
// Reads farmers_seed.csv (from the data-cleaning chat) and writes one
// farmers/ document per row, plus a pf_numbers/ lock for every farmer with a
// PF. Uses the Firebase Admin SDK, which skips the security rules, so only
// ever run it from your own laptop with the service-account key.
//
// DRY RUN BY DEFAULT: validates, resolves EO accounts, checks what's already
// loaded, writes the report, and changes nothing. Add --commit to write.
//
// Usage (from this folder):
//   node import_farmers.mjs farmers_seed.csv --key service-account.json
//        --dart ../../lib/constants/kenya_locations.dart
//        --reassign fwainaina=NEWUSER --reassign bmugo=NEWUSER [--commit]
//
// Safe to re-run: each farmer's document ID is seed_<legacy_id>, so a farmer
// already there is skipped, never duplicated. A crash half-way? Run it again.

import { readFileSync, writeFileSync } from 'node:fs';
import { parseArgs } from 'node:util';
import { pathToFileURL } from 'node:url';
import { parse } from 'csv-parse/sync';

const NEEDS_UPDATE_VALUES = new Set(['location', 'id', 'phone']);
// Firestore allows 500 writes per batch; a farmer may need 2 (farmer + PF
// lock), so 200 farmers per batch stays safely under the limit.
const FARMERS_PER_BATCH = 200;

// ------------------------------------------------------------------ helpers

/** County -> Set(sub-counties), straight from the app's own Dart file, so the
 *  import can never accept a spelling the app's dropdowns don't know.
 *  Handles escaped apostrophes (Murang\'a, Chuka/Igambang\'ombe). */
export function loadLocations(dartPath) {
  const src = readFileSync(dartPath, 'utf8');
  const body = src.slice(src.indexOf('countySubcounties = {'), src.indexOf('};'));
  const str = "'((?:[^'\\\\]|\\\\.)+)'";
  const unescape = (s) => s.replace(/\\'/g, "'");
  const out = new Map();
  for (const m of body.matchAll(new RegExp(str + ':\\s*\\[([\\s\\S]*?)\\]', 'g'))) {
    const subs = [...m[2].matchAll(new RegExp(str, 'g'))].map((x) => unescape(x[1]));
    out.set(unescape(m[1]), new Set(subs));
  }
  return out;
}

/** Problems with one CSV row (empty array = fine). */
export function validate(r, locations) {
  const p = [];
  if (!r.legacy_id) p.push('no legacy_id');
  if (!r.name) p.push('no name');
  if (r.pf_number && !/^PF\d{5}$/.test(r.pf_number)) p.push(`bad PF '${r.pf_number}'`);
  if (r.mobile && !/^0[17]\d{8}$/.test(r.mobile)) p.push(`bad mobile '${r.mobile}'`);
  if (r.id_number && !/^\d{6,9}$/.test(r.id_number)) p.push(`bad ID '${r.id_number}'`);
  if (r.county && !locations.has(r.county)) p.push(`unknown county '${r.county}'`);
  if (r.subcounty && !r.county) p.push('sub-county without county');
  if (locations.has(r.county) && r.subcounty && !locations.get(r.county).has(r.subcounty)) {
    p.push(`sub-county '${r.subcounty}' not in ${r.county}`);
  }
  if (r.registered_date && !/^\d{4}-\d{2}-\d{2}$/.test(r.registered_date)) {
    p.push(`bad date '${r.registered_date}'`);
  }
  const bad = r.needs_update.split('|').filter((x) => x && !NEEDS_UPDATE_VALUES.has(x));
  if (bad.length) p.push(`unknown needs_update ${bad.join(',')}`);
  return p;
}

/** Missing values are stored as null, never "", so "no ward" is one value
 *  in Firestore, not two. */
const blankToNull = (v) => (v ? v : null);

/** Which of these document IDs already exist. getAll reads them in one
 *  round-trip per chunk instead of one call per document. */
async function getExisting(db, collection, ids) {
  const found = new Map();
  for (let i = 0; i < ids.length; i += 300) {
    const refs = ids.slice(i, i + 300).map((id) => db.collection(collection).doc(id));
    if (!refs.length) continue;
    for (const snap of await db.getAll(...refs)) {
      if (snap.exists) found.set(snap.id, snap.data());
    }
  }
  return found;
}

const csvCell = (v) => {
  const s = v == null ? '' : String(v);
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
};

// ------------------------------------------------------------------ main

/** The whole import. `db` and `FieldValue`/`Timestamp` are passed in so the
 *  logic can be tested without a real project. */
export async function run({ db, FieldValue, Timestamp, projectId, opts }) {
  const reassign = new Map();
  for (const pair of opts.reassign ?? []) {
    const [oldU, newU] = pair.split('=').map((s) => s?.trim().toLowerCase());
    if (!oldU || !newU) throw new Error(`--reassign must look like old=new, got '${pair}'`);
    reassign.set(oldU, newU);
  }

  // Every cell read as text exactly as written. (No number conversion, so
  // "0722..." keeps its leading zero.)
  const rows = parse(readFileSync(opts.csv, 'utf8'), {
    columns: true,
    skip_empty_lines: true,
    trim: true,
    bom: true,
  });
  const locations = loadLocations(opts.dart);
  console.log(`Project: ${projectId}   Mode: ${opts.commit ? 'COMMIT' : 'DRY RUN'}   Rows: ${rows.length}`);

  for (const r of rows) {
    r.previous_eo = reassign.has(r.assigned_eo_username) ? r.assigned_eo_username : '';
    r.eo = reassign.get(r.assigned_eo_username) ?? r.assigned_eo_username;
    r.doc_id = `seed_${r.legacy_id}`;
  }

  // ---- resolve EO usernames -> uid + full name (after reassignment) ----
  const eos = new Map();
  const unames = [...new Set([...rows.map((r) => r.eo), ...reassign.keys()])].sort();
  for (const u of unames) {
    const snap = await db.collection('usernames').doc(u).get();
    if (!snap.exists) { eos.set(u, null); continue; }
    const uid = snap.data().uid;
    const user = (await db.collection('users').doc(uid).get()).data() ?? {};
    eos.set(u, { uid, name: user.full_name ?? u, active: user.active ?? true });
  }
  // Former EOs may have no account at all: fall back to the username.
  const prevName = (u) => eos.get(u)?.name ?? u;

  console.log('\nEO accounts:');
  for (const [u, info] of eos) {
    if (reassign.has(u)) {
      const n = rows.filter((r) => r.previous_eo === u).length;
      console.log(`  ${u.padEnd(12)} ${'former'.padEnd(9)} ${String(n).padStart(5)} farmers -> ${reassign.get(u)}`);
      continue;
    }
    const n = rows.filter((r) => r.eo === u).length;
    const status = info == null ? 'MISSING' : info.active ? 'ok' : 'inactive';
    console.log(`  ${u.padEnd(12)} ${status.padEnd(9)} ${String(n).padStart(5)} farmers${info ? `   (${info.name})` : ''}`);
  }

  // ---- what is already loaded ----
  const existingFarmers = await getExisting(db, 'farmers', rows.map((r) => r.doc_id));
  const existingPfs = await getExisting(db, 'pf_numbers', rows.filter((r) => r.pf_number).map((r) => r.pf_number));

  // ---- decide row by row ----
  const report = [];
  const toWrite = [];
  for (const r of rows) {
    const rec = { legacy_id: r.legacy_id, doc_id: r.doc_id, pf_number: r.pf_number, name: r.name, eo: r.eo, previous_eo: r.previous_eo };
    const problems = validate(r, locations);
    const eo = eos.get(r.eo);
    const pfOwner = r.pf_number && existingPfs.get(r.pf_number)?.farmer_id;
    if (problems.length) Object.assign(rec, { action: 'skipped', reason: problems.join('; ') });
    else if (!eo) Object.assign(rec, { action: 'skipped', reason: `EO account missing: ${r.eo}` });
    else if (existingFarmers.has(r.doc_id)) Object.assign(rec, { action: 'skipped', reason: 'already imported' });
    // The PF lock belongs to a different farmer: never steal it.
    else if (pfOwner && pfOwner !== r.doc_id) Object.assign(rec, { action: 'skipped', reason: `PF already used by ${pfOwner}` });
    else {
      Object.assign(rec, { action: opts.commit ? 'imported' : 'would import', reason: '' });
      toWrite.push({ r, eo });
    }
    report.push(rec);
  }

  // ---- write ----
  if (opts.commit && toWrite.length) {
    let written = 0;
    for (let i = 0; i < toWrite.length; i += FARMERS_PER_BATCH) {
      const chunk = toWrite.slice(i, i + FARMERS_PER_BATCH);
      const batch = db.batch();
      for (const { r, eo } of chunk) {
        batch.set(db.collection('farmers').doc(r.doc_id), {
          pf_number: blankToNull(r.pf_number),
          // No PF yet = waits in the office's PF queue like any farmer an
          // EO registers in the field.
          status: r.pf_number ? 'active' : 'pending_pf',
          name: r.name,
          name_lower: r.name.toLowerCase(),
          id_number: blankToNull(r.id_number),
          mobile: blankToNull(r.mobile),
          email: blankToNull(r.email.toLowerCase()),
          location: {
            county: blankToNull(r.county),
            subcounty: blankToNull(r.subcounty),
            ward: blankToNull(r.ward),
          },
          assigned_eo_uid: eo.uid,
          assigned_eo_name: eo.name,
          previous_eo_name: r.previous_eo ? prevName(r.previous_eo) : null,
          source: 'seed',
          created_by: 'seed_import',
          legacy_id: r.legacy_id,
          needs_update: r.needs_update.split('|').filter(Boolean),
          // Midnight in Nairobi on the registration date.
          registered_at: r.registered_date
            ? Timestamp.fromDate(new Date(`${r.registered_date}T00:00:00+03:00`))
            : FieldValue.serverTimestamp(),
          created_at: FieldValue.serverTimestamp(),
          updated_at: FieldValue.serverTimestamp(),
        });
        if (r.pf_number) {
          batch.set(db.collection('pf_numbers').doc(r.pf_number), { farmer_id: r.doc_id });
        }
      }
      await batch.commit();
      written += chunk.length;
      console.log(`  wrote ${written}/${toWrite.length}`);
    }
  }

  // ---- report ----
  const cols = ['legacy_id', 'doc_id', 'pf_number', 'name', 'eo', 'previous_eo', 'action', 'reason'];
  writeFileSync(opts.report, [cols.join(','), ...report.map((x) => cols.map((c) => csvCell(x[c])).join(','))].join('\n') + '\n', 'utf8');

  const count = (arr, f) => arr.reduce((m, x) => m.set(f(x), (m.get(f(x)) ?? 0) + 1), new Map());
  console.log('\nResult:');
  for (const [k, v] of count(report, (x) => x.action)) console.log(`  ${k.padEnd(14)} ${v}`);
  const skipped = report.filter((x) => x.action === 'skipped');
  if (skipped.length) {
    console.log('\nSkipped, by reason:');
    for (const [k, v] of count(skipped, (x) => x.reason.replace(/:.*/, ''))) console.log(`  ${k.padEnd(26)} ${v}`);
  }
  console.log(`\nFull report: ${opts.report}`);
  if (!opts.commit) console.log('Dry run: nothing was written. Add --commit to import.');
  return report;
}

// ------------------------------------------------------------------ CLI
// Only runs when started as `node import_farmers.mjs ...`, not when the
// file is imported by a test.
if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const { values, positionals } = parseArgs({
    allowPositionals: true,
    options: {
      key: { type: 'string' },
      dart: { type: 'string' },
      reassign: { type: 'string', multiple: true },
      report: { type: 'string', default: 'import_report.csv' },
      commit: { type: 'boolean', default: false },
    },
  });
  if (!positionals[0] || !values.key || !values.dart) {
    console.error('Usage: node import_farmers.mjs farmers_seed.csv --key service-account.json --dart <kenya_locations.dart> [--reassign old=new] [--commit]');
    process.exit(1);
  }
  const { initializeApp, cert } = await import('firebase-admin/app');
  const { getFirestore, FieldValue, Timestamp } = await import('firebase-admin/firestore');
  const key = JSON.parse(readFileSync(values.key, 'utf8'));
  initializeApp({ credential: cert(key) });
  try {
    await run({
      db: getFirestore(),
      FieldValue,
      Timestamp,
      projectId: key.project_id,
      opts: { ...values, csv: positionals[0] },
    });
  } catch (e) {
    console.error(`\nFAILED: ${e.message}`);
    process.exit(1);
  }
}
