# app/lib/caregiver - plan (suggestions, create your own files)

What family or an NGO sees. Clear, calm, data without clutter.

## Suggested sub-folders (tasks)
- pairing/     Enter the 6-digit code, call link_with_code, kind errors for wrong, used or expired codes.
- dashboard/   Patient status at a glance: name, last seen, battery, today's sessions, latest alerts.
- alerts/      Stream of alerts, colour by type, Acknowledge writes ackedBy and ackedAt.
- map/         OpenStreetMap (flutter_map), listen to lastLocation only while open, draw the safe zone circle.
- trends/      30-day charts of accuracy and speed, flagged change from the person's own baseline, plain-language insight line.
               Words: engagement trend, change from baseline. Never: recovery, decline, diagnosis.
- settings/    Safe zone picker, reminder editor, contact editor, revoke access.
- ngo/         Optional. List of several patients with status colours. Cut first if short on time.

## Talks to
core, functions (pairing, analytics), patient (the data they write), pitch (demo data).

## Done when
A caregiver pairs, sees the live dot, gets an alert, acknowledges it, and sees a trend with a flagged change.

## Watch out
Do not stream location constantly; the map only listens while open. Seeded data must look real for the demo.
