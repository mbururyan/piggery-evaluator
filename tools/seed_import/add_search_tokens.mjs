// Piggery Evaluator - back-fill search_tokens on every farmer.
//
// The app builds search_tokens (word beginnings of the name) whenever an EO
// registers or edits a farmer. Farmers loaded by the seed import don't have
// them yet, so All farmers' name search can't find them. This adds them.
//
// DRY RUN BY DEFAULT. Add --commit to write.
//   node add_search_tokens.mjs --key service-account.json [--commit]
//
// Safe to re-run: farmers whose tokens are already right are skipped. Also
// useful later if the token rule ever changes.

import { readFileSync } from 'node:fs';
import { parseArgs } from 'node:util';
import { pathToFileURL } from 'node:url';

const MAX_LEN = 15;

/** MUST match SearchTokens.forName() in lib/utils/search_tokens.dart:
 *  lowercase, apostrophes dropped, split on anything not a-z/0-9, words of
 *  2+ characters, every beginning of 2..15 characters, de-duplicated, sorted. */
export function searchTokens(name) {
  const words = String(name ?? '')
    .toLowerCase()
    .replace(/['’]/g, '')
    .split(/[^a-z0-9]+/)
    .filter((w) => w.length >= 2);
  const out = new Set();
  for (const w of words) {
    for (let i = 2; i <= w.length && i <= MAX_LEN; i++) out.add(w.slice(0, i));
  }
  // Plain code-unit sort, the same order Dart's List.sort() gives strings.
  return [...out].sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));
}

const same = (a, b) => Array.isArray(a) && a.length === b.length && a.every((x, i) => x === b[i]);

export async function run({ db, commit }) {
  const snap = await db.collection('farmers').get();
  console.log(`Farmers: ${snap.size}   Mode: ${commit ? 'COMMIT' : 'DRY RUN'}`);

  const todo = [];
  for (const doc of snap.docs) {
    const tokens = searchTokens(doc.data().name);
    if (!same(doc.data().search_tokens, tokens)) todo.push({ ref: doc.ref, tokens });
  }
  console.log(`Need tokens: ${todo.length}   Already right: ${snap.size - todo.length}`);

  if (commit) {
    // Updates only this one field, so nothing else on the farmer changes.
    for (let i = 0; i < todo.length; i += 400) {
      const batch = db.batch();
      for (const { ref, tokens } of todo.slice(i, i + 400)) batch.update(ref, { search_tokens: tokens });
      await batch.commit();
      console.log(`  updated ${Math.min(i + 400, todo.length)}/${todo.length}`);
    }
  } else {
    if (todo[0]) console.log(`Example: ${todo[0].ref.id} -> ${todo[0].tokens.slice(0, 8).join(', ')} …`);
    console.log('Dry run: nothing was written. Add --commit to update.');
  }
  return todo.length;
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const { values } = parseArgs({
    options: { key: { type: 'string' }, commit: { type: 'boolean', default: false } },
  });
  if (!values.key) {
    console.error('Usage: node add_search_tokens.mjs --key service-account.json [--commit]');
    process.exit(1);
  }
  const { initializeApp, cert } = await import('firebase-admin/app');
  const { getFirestore } = await import('firebase-admin/firestore');
  initializeApp({ credential: cert(JSON.parse(readFileSync(values.key, 'utf8'))) });
  try {
    await run({ db: getFirestore(), commit: values.commit });
  } catch (e) {
    console.error(`\nFAILED: ${e.message}`);
    process.exit(1);
  }
}
