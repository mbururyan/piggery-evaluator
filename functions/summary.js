// Piggery Evaluator: one farmer's visit summary, worked out from their
// visits. Pure JavaScript with no imports, on purpose: the Cloud Function
// (index.js) and the one-off backfill script (tools/seed_import) both use
// it, so the summary is calculated one way only.

/** The age-band keys, as in PopulationTemplate.bands in the app. */
const BANDS = ['m0_1', 'm1_2', 'm2_3', 'm3_4', 'm4_5', 'm5_6', 'm6_7', 'm7p'];

/** Milliseconds of a Firestore Timestamp, or 0 when missing. */
const ms = (ts) => (ts && typeof ts.toMillis === 'function' ? ts.toMillis() : 0);

/** A count, or null when the field is missing or not a number. */
const num = (v) => (typeof v === 'number' && Number.isFinite(v) ? Math.round(v) : null);

/**
 * Which visits count. Submitted app visits, and the paper visits the
 * early-December import will bring in (source "legacy"). Drafts never
 * count: a half-done visit isn't a visit yet.
 */
export function counts(v) {
  return v.status === 'submitted' || v.source === 'legacy';
}

/**
 * The summary for one farmer, from that farmer's visits (plain objects:
 * Firestore data plus `id`). Null when there are none, so the caller
 * removes the summary.
 *
 * "Latest" means the latest VISIT DATE, never the last one written: a
 * March paper visit imported in December must not replace a November
 * app visit as this farmer's last visit. Same date: the later submit
 * wins.
 */
export function buildSummary(visits) {
  const real = visits.filter(counts);
  if (real.length === 0) return null;

  real.sort((a, b) =>
    ms(b.visit_date) - ms(a.visit_date) || ms(b.submitted_at) - ms(a.submitted_at));
  const last = real[0];
  const pop = last.population ?? null;

  return {
    visit_count: real.length,
    last_visit_id: last.id,
    last_visit_date: last.visit_date ?? null,
    last_eo_uid: last.eo_uid ?? null,
    last_eo_name: last.eo_name ?? null,
    // The score as stored on the visit at submit (good ÷ answered);
    // imported paper visits have none.
    score_pct: num(last.score_pct),
    population: pop
      ? {
          growing: BANDS.reduce((n, k) => n + (num(pop[k]) ?? 0), 0),
          sows: num(pop.sows),
          gilts: num(pop.gilts),
          boars: num(pop.boars),
        }
      : null,
  };
}

/**
 * Same summary? Compared as JSON with Timestamps turned into numbers, so
 * an unchanged farmer isn't written again (each write costs, and would
 * wake every phone listening to that farmer).
 */
export function sameSummary(a, b) {
  const plain = (s) =>
    JSON.stringify(s ?? null, (k, v) => (v && typeof v.toMillis === 'function' ? v.toMillis() : v));
  return plain(a) === plain(b);
}
