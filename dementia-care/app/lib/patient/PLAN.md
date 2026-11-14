# app/lib/patient - plan (suggestions, create your own files)

What the patient sees. Huge buttons, few choices, kind words, works offline.

## Suggested sub-folders (tasks)
- home/        Home screen: Play, Call family, Assistant, Reminders, SOS. Shows the next reminder.
- games/       word_picture_match, story_comprehension, a rule-based difficulty engine, a session logger.
               Difficulty rises after a streak of correct quick answers, eases after repeated misses. Never show a failing score.
               Log game, level, accuracy, average response time, timestamp to patients/{pid}/sessions.
- sos/         Large red button with a short hold or confirm. Writes an alert doc with location. Works offline, SMS fallback. Never uses the AI.
- reminders/   Medication, hydration, game reminders as local alarms from synced data. Big Done button.
- assistant/   Speech-to-text -> call assistant_chat -> text-to-speech. Handle the 'call <name>' action. Show the fallback kindly.
- calls/       Contacts from Firestore (cached). Tap opens the dialer (url_launcher). Video call is a stub.
- location/    Foreground service, permissions, visible 'location sharing is on' notice, upload when moved, drop low-accuracy readings,
               battery exemption flow, on-phone geofence check, 'simulate walking out' button for the demo.
- pairing/     Screen that asks a function for a 6-digit code and shows it with a 10 minute countdown.

## Talks to
core (theme, auth, shared), functions (pairing, assistant), content (words, stories, strings), caregiver (they read what you write).

## Done when
A full patient day works: reminder -> game -> assistant -> SOS, and it survives airplane mode.

## Watch out
Test on a real phone early. Some phone brands kill background apps. Check Hindi voices on the demo phone.
Big area: split it (games | safety | daily help).
