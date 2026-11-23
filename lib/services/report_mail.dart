import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import '../constants/visit_template.dart';
import '../models/farmer.dart';
import '../models/visit.dart';
import '../utils/formatters.dart';
import 'auth_service.dart';
import 'farmer_service.dart';
import 'pdf_report.dart';

/// What happened to the farmer's email, so the EO is told the truth
/// rather than assuming it went.
enum MailOutcome {
  /// Queued to a valid address. Sends once the phone has signal and the
  /// email extension is connected.
  queued,

  /// The farmer has no email on file: nothing to do, and nothing to say.
  noAddress,

  /// An address is on file but isn't a usable one.
  invalidAddress,

  /// The PDF came out too big for one Firestore document (1 MB).
  tooLarge,

  /// Building the PDF or the queue write itself failed.
  failed,
}

/// Emails the farmer their visit report, as Ranch Evaluator does: a
/// document in `mail/`, with the PDF attached as base64, which Firebase's
/// "Trigger Email from Firestore" extension picks up and sends.
///
/// Why a Firestore document and not a direct send: it's queued like any
/// other write. A visit submitted in a valley still emails the farmer
/// once the phone reaches coverage, even if the app was closed between.
/// And until the extension is connected, the documents simply wait;
/// the day it is, everything queued goes out.
class ReportMail {
  ReportMail._();

  /// Loose on purpose: a second line of defence behind the registration
  /// form, and a report shouldn't be withheld over an unusual but real
  /// address.
  static final _email = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  /// Firestore's limit is 1 MiB per document. The base64 PDF must leave
  /// room for the body text and the rest, and base64 is a third bigger
  /// than the PDF itself.
  static const _maxBase64 = 900000;

  /// The farmer's record, from the phone's cache when offline. Null if it
  /// can't be read within a few seconds.
  static Future<Farmer?> farmerOf(String farmerId) async {
    try {
      return await FarmerService.instance
          .watch(farmerId)
          .first
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      return null;
    }
  }

  /// The usable address on file, or null.
  static String? addressOf(Farmer? f) {
    final a = f?.email?.trim() ?? '';
    return a.isEmpty ? null : a;
  }

  static bool isValid(String address) => _email.hasMatch(address);

  /// Builds the PDF and queues the email. The write is NOT awaited: the
  /// cache takes it at once, and awaiting would hang until the phone
  /// found signal. A rejection by the rules turns up later, in Crashlytics.
  static Future<(MailOutcome, String?)> queue(Visit v, Farmer? farmer) async {
    final address = addressOf(farmer);
    if (address == null) return (MailOutcome.noAddress, null);
    if (!isValid(address)) return (MailOutcome.invalidAddress, address);

    try {
      final bytes = await PdfReport.build(v, phone: farmer?.mobile);
      final content = base64Encode(bytes);
      if (content.length > _maxBase64) {
        FirebaseCrashlytics.instance.recordError(
            Exception('report PDF too large to email: ${bytes.length} bytes'),
            StackTrace.current,
            reason: 'report mail');
        return (MailOutcome.tooLarge, address);
      }

      final doc = FirebaseFirestore.instance.collection('mail').doc();
      unawaited(doc.set({
        'to': [address],
        'message': {
          'subject': 'Farm visit report: ${v.farmerName}, ${Formatters.date(v.visitDate)}',
          'text': _body(v),
          'attachments': [
            {
              'filename': PdfReport.filenameFor(v),
              'content': content,
              'encoding': 'base64',
            }
          ],
        },
        // Ours, not the extension's. The rules check these (only your
        // own submitted visit, only to that farmer's address on file),
        // and they trace an email back to its visit.
        'meta': {
          'visit_id': v.id,
          'farmer_id': v.farmerId,
          'queued_by': AuthService.instance.currentUser?.uid,
          'queued_at': FieldValue.serverTimestamp(),
        },
      }).catchError((Object e, StackTrace s) {
        FirebaseCrashlytics.instance.recordError(e, s, reason: 'mail queue rejected');
      }));
      return (MailOutcome.queued, address);
    } catch (e, s) {
      FirebaseCrashlytics.instance.recordError(e, s, reason: 'report mail');
      return (MailOutcome.failed, address);
    }
  }

  /// One line for a snackbar. Null for "no address": a farmer without
  /// email is normal, not something to announce on every visit.
  static String? message((MailOutcome, String?) r) => switch (r.$1) {
        MailOutcome.queued => 'Report emailed to ${r.$2}',
        MailOutcome.noAddress => null,
        MailOutcome.invalidAddress => 'Not emailed: ${r.$2} doesn\'t look like an email',
        MailOutcome.tooLarge => 'Not emailed: the report is too large. Share it on WhatsApp',
        MailOutcome.failed => 'The report email couldn\'t be prepared',
      };

  static String _body(Visit v) {
    final sc = v.score;
    final rating = Rating.of(sc.pct);
    final b = StringBuffer()
      ..writeln('Dear ${v.farmerName},')
      ..writeln()
      ..writeln('Thank you for welcoming us to your farm. Please find attached '
          'the report from our visit on ${Formatters.date(v.visitDate)}.')
      ..writeln()
      // "out of the questions answered": anything can be skipped (23 Nov).
      ..writeln('Score: ${sc.good} out of ${sc.of} questions answered'
          '${rating == null ? '' : ' (${rating.label})'}.');

    final recs = v.recommendations;
    if (recs.isNotEmpty) {
      b
        ..writeln()
        ..writeln('Recommendations:');
      for (var i = 0; i < recs.length; i++) {
        b.writeln('${i + 1}. ${recs[i]}');
      }
    }
    b
      ..writeln()
      ..writeln('Kind regards,')
      ..writeln(v.eoName.isEmpty ? 'Your extension officer' : v.eoName)
      ..writeln("Farmer's Choice Limited · Pig procurement");
    return b.toString();
  }
}