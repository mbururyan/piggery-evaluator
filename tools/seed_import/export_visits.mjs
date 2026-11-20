// Piggery Evaluator - export visits to a CSV you can open in Excel.
//
// For the first weeks in the field, before the web app exists: one row per
// visit, every answer in its own column. Read-only: it never writes to
// Firestore. Uses the same service-account key as the seed import, so the
// same rule applies: only ever run it from your own laptop.
//
// Usage (from this folder):
//   node export_visits.mjs                       submitted visits, all time
//   node export_visits.mjs --from 2026-11-23     on or after a date
//   node export_visits.mjs --from 2026-11-23 --to 2026-11-28
//   node export_visits.mjs --eo gaita            EO name contains "gaita"
//   node export_visits.mjs --drafts              include unfinished drafts
//   node export_visits.mjs --out week1.csv       choose the file name
//
// The CSV holds farmer names: it's covered by the .gitignore line
// tools/seed_import/*.csv, and like the seed file it shouldn't be emailed
// or put on a shared drive. Opening it in Excel is fine; saving it back
// from Excel is not needed (Excel would quietly reformat dates and IDs).

import { writeFileSync } from 'node:fs';
import { parseArgs } from 'node:util';
import { pathToFileURL } from 'node:url';

// The app's section keys, in form order, so the columns come out in the
// order the EO filled them. Must match VisitSection in visit_template.dart.
export const SECTIONS = [
  'production', 'biosecurity', 'herd_health', 'records', 'feeds',
  'breeding', 'housing', 'population', 'intake_schedule',
];

// Kenya is UTC+3 all year (no daylight saving), so a fixed offset is exact.
const NAIROBI_MS = 3 * 60 * 60 * 1000;

/** A Firestore Timestamp (or anything with toDate) as YYYY-MM-DD, Nairobi. */
export function day(ts) {
  if (!ts || typeof ts.toDate !== 'function') return '';
  return new Date(ts.toDate().getTime() + NAIROBI_MS).toISOString().slice(0, 10);
}

/** One cell's text: Yes/No for booleans, dates for timestamps. */
function cell(v) {
  if (v === null || v === undefined) return '';
  if (typeof v === 'boolean') return v ? 'Yes' : 'No';
  if (typeof v.toDate === 'function') return day(v);
  return String(v);
}

/**
 * One visit document -> a flat { column: value } row.
 *
 * Section answers are flattened generically (every key in the section's
 * map becomes "<section>.<key>") rather than from a hard-coded list, so a
 * question added to the app later shows up here without touching this
 * script. Intake months use calendar columns (intake.2026-12) so pigs
 * planned for a month can be summed across farms in one column.
 */
export function flatten(id, d) {
  const row = {
    visit_id: id,
    status: d.status ?? '',
    visit_date: day(d.visit_date),
    submitted_at: day(d.submitted_at),
    edit_count: d.edit_count ?? 0,
    eo_name: d.eo_name ?? '',
    farmer_id: d.farmer_id ?? '',
    farmer_name: d.farmer_name ?? '',
    pf_number: d.pf_number ?? '',
    county: d.county ?? '',
    subcounty: d.subcounty ?? '',
    score_pct: d.score_pct ?? '',
  };

  // Section scores as two numbers each, never "4/5": Excel reads that as
  // the 4th of May.
  const scores = d.scores_by_section ?? {};
  for (const s of SECTIONS) {
    if (scores[s]) {
      row[`${s}.score_good`] = scores[s].good;
      row[`${s}.score_of`] = scores[s].of;
    }
  }

  for (const s of SECTIONS) {
    const sec = d[s];
    if (!sec || typeof sec !== 'object') continue;
    for (const [k, v] of Object.entries(sec)) {
      if (s === 'intake_schedule' && k === 'months' && v && typeof v === 'object') {
        for (const [month, pigs] of Object.entries(v)) row[`intake.${month}`] = pigs;
      } else {
        row[`${s}.${k}`] = cell(v);
      }
    }
  }

  // Close-out lives in top-level fields, not a section map.
  row['close_out.ready_for_market'] = d.ready_for_market ?? '';
  row['close_out.recommendations'] = (d.recommendations ?? []).join(' | ');
  row['close_out.last_recs_review'] = (d.last_recs_review ?? [])
    .map((r) => `${r.text}: ${r.outcome ?? 'not answered'}`)
    .join(' | ');
  row['close_out.follow_up_needed'] = cell(d.follow_up?.needed);
  row['close_out.follow_up_by'] = day(d.follow_up?.by);
  return row;
}

/** Columns in a sensible order: fixed ones first, then section by section
 *  (scores, answers, remark last), intake months in calendar order. */
export function columns(rows) {
  const seen = new Set();
  for (const r of rows) for (const k of Object.keys(r)) seen.add(k);
  const fixed = Object.keys(rows[0] ?? flatten('', {})).filter((k) => !k.includes('.'));
  const out = [...fixed];
  for (const s of SECTIONS) {
    const mine = [...seen].filter((k) => k.startsWith(`${s}.`));
    const score = mine.filter((k) => k.includes('.score_')).sort();
    const remark = mine.filter((k) => k === `${s}.remark`);
    const rest = mine.filter((k) => !score.includes(k) && !remark.includes(k)).sort();
    out.push(...score, ...rest, ...remark);
    if (s === 'intake_schedule') {
      out.push(...[...seen].filter((k) => k.startsWith('intake.')).sort());
    }
  }
  out.push(...[...seen].filter((k) => k.startsWith('close_out.')));
  return out;
}

/** RFC 4180 CSV, with a byte-order mark so Excel reads ≤, – and accented
 *  names correctly instead of as garbage. */
export function toCsv(rows) {
  const cols = columns(rows);
  const esc = (v) => {
    const s = v === undefined || v === null ? '' : String(v);
    return /[",\r\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  const lines = [cols.join(',')];
  for (const r of rows) lines.push(cols.map((c) => esc(r[c])).join(','));
  return '﻿' + lines.join('\r\n') + '\r\n';
}

// ------------------------------------------------------------------ main

async function main() {
  const { values } = parseArgs({
    options: {
      key: { type: 'string', default: 'service-account.json' },
      from: { type: 'string' },
      to: { type: 'string' },
      eo: { type: 'string' },
      drafts: { type: 'boolean', default: false },
      out: { type: 'string' },
    },
  });
  for (const d of [values.from, values.to]) {
    if (d && !/^\d{4}-\d{2}-\d{2}$/.test(d)) {
      console.error(`Dates must look like 2026-11-23 (got '${d}')`);
      process.exit(1);
    }
  }

  const { readFileSync } = await import('node:fs');
  const { initializeApp, cert } = await import('firebase-admin/app');
  const { getFirestore } = await import('firebase-admin/firestore');
  initializeApp({ credential: cert(JSON.parse(readFileSync(values.key, 'utf8'))) });

  // Everything, filtered here: a few hundred documents a week is nothing
  // for one read, and it needs no Firestore index.
  const snap = await getFirestore().collection('visits').get();
  const eo = values.eo?.toLowerCase();
  const rows = snap.docs
    .map((doc) => ({ id: doc.id, d: doc.data() }))
    .filter(({ d }) => values.drafts || d.status === 'submitted')
    .filter(({ d }) => !values.from || day(d.visit_date) >= values.from)
    .filter(({ d }) => !values.to || day(d.visit_date) <= values.to)
    .filter(({ d }) => !eo || (d.eo_name ?? '').toLowerCase().includes(eo))
    .sort((a, b) => day(a.d.visit_date).localeCompare(day(b.d.visit_date)))
    .map(({ id, d }) => flatten(id, d));

  if (rows.length === 0) {
    console.log('No visits match. Nothing written.');
    return;
  }
  const out = values.out ?? `visits_${new Date(Date.now() + NAIROBI_MS).toISOString().slice(0, 10)}.csv`;
  writeFileSync(out, toCsv(rows), 'utf8');

  const byEo = new Map();
  for (const r of rows) byEo.set(r.eo_name || '(no EO)', (byEo.get(r.eo_name || '(no EO)') ?? 0) + 1);
  console.log(`Wrote ${rows.length} visits to ${out}`);
  for (const [name, n] of [...byEo].sort()) console.log(`  ${name}: ${n}`);
}

// Only run when called directly, so the tests can import the helpers.
if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((e) => {
    console.error(e.message ?? e);
    process.exit(1);
  });
}
