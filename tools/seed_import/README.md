# Seed import (one-off)

Loads `farmers_seed.csv` into Firestore: `farmers/seed_<legacy_id>` plus a
`pf_numbers/<PF>` lock for each farmer with a PF. Firebase Admin SDK: skips
the security rules, so run it only from your own machine.

## Once

1. `npm install` (in this folder) — fetches firebase-admin and csv-parse
   into `node_modules/`.
2. Firebase console → Project settings → Service accounts → **Generate new
   private key**. Save it here as `service-account.json`.
   **Never commit it.** It's full admin access to the project.
3. Every EO in the CSV needs an app account first.

## Every run

Dry run (checks everything, writes nothing):

    node import_farmers.mjs farmers_seed.csv --key service-account.json --dart ../../lib/constants/kenya_locations.dart --reassign fwainaina=NEWUSER --reassign bmugo=NEWUSER

Read `import_report.csv`. When happy, run the same command with `--commit`
added at the end.

Re-running is safe: farmers already loaded are skipped.
