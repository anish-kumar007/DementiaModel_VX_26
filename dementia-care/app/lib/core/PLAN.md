# app/lib/core - plan (suggestions, create your own files)

Foundation of the Flutter app. Do this first; others build on it.

## Suggested sub-folders (tasks)
- setup/      Create the Flutter project in app/ (flutter create), connect Firebase, main.dart, offline persistence on.
- auth/       Sign up, sign in, sign out, stay signed in, load users/{uid}.role, save the FCM token after login.
- routing/    Routes for patient and caregiver, a guard so the wrong role cannot open the other mode.
- theme/      Large text, high contrast, 56dp+ touch targets, calm colours, red only for SOS.
- l10n/       Hindi + English strings. Language read from users/{uid}.language. Content team supplies the words.
- shared/     models (User, Patient, Alert, Session, Reminder, Contact), Firestore helpers, common widgets (BigButton, InfoCard, StatusDot).

## First two hours
Get login working end to end and write 2 or 3 example screens so others copy the pattern.

## Talks to
firebase (config files, project), patient and caregiver folders (they use everything here).

## Done when
App opens on a real phone, a user logs in, and lands in the correct mode.

## Watch out
Keep shared things small and stable; changing them breaks everyone. Announce changes.
