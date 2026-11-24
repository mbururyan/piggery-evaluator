// Piggery Evaluator Cloud Functions (Phase 3).
//
// onVisitWritten keeps each farmer's `summary` (last visit, its score,
// pigs counted, visit count) in step with their visits, so farmer cards,
// sorts and the "Due for a visit" list work without the phone reading
// every visit. Phones can't write `summary` (the rules forbid it); only
// this function can, because it runs with admin rights.

import { initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions';

import { buildSummary, sameSummary } from './summary.js';

initializeApp();
const db = getFirestore();

// The function runs where the database is: a Firestore trigger must be in
// the database's region, and it keeps the reads local.
const REGION = 'africa-south1';

/** Recalculate one farmer's summary from all their visits. */
export async function refreshFarmer(farmerId) {
  const farmerRef = db.collection('farmers').doc(farmerId);
  // Equality filter only: no index needed. A farmer has a handful of
  // visits, so reading them all is cheap.
  const [farmerSnap, visitsSnap] = await Promise.all([
    farmerRef.get(),
    db.collection('visits').where('farmer_id', '==', farmerId).get(),
  ]);
  if (!farmerSnap.exists) {
    logger.warn('visit for a farmer that does not exist', { farmerId });
    return 'missing';
  }

  const next = buildSummary(visitsSnap.docs.map((d) => ({ id: d.id, ...d.data() })));
  if (sameSummary(farmerSnap.get('summary'), next)) return 'unchanged';

  await farmerRef.update({
    summary: next ?? FieldValue.delete(),
    // When the server last worked it out: helps when checking it by hand.
    summary_updated_at: FieldValue.serverTimestamp(),
  });
  return next ? 'updated' : 'cleared';
}

export const onVisitWritten = onDocumentWritten(
  { document: 'visits/{visitId}', region: REGION },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();

    // Drafts are saved every time a section closes. Their edits can't
    // change a summary, so skip them unless the visit is, or was,
    // submitted (submit, an edit in the 7 days, or a delete).
    const matters = (v) => v && (v.status === 'submitted' || v.source === 'legacy');
    if (!matters(before) && !matters(after)) return;

    // Both sides, in case a visit ever moves farmer (admins can).
    const ids = new Set([before?.farmer_id, after?.farmer_id].filter(Boolean));
    for (const id of ids) {
      const result = await refreshFarmer(id);
      logger.info('summary', { farmerId: id, visitId: event.params.visitId, result });
    }
  },
);
