# Family sharing (caretaker alerts)

A patient can link one or more caretakers. Caretakers get a push notification
when a dose is not marked as taken, when the patient presses **Help**, asks
for medicines, or their phone battery runs low. Nothing leaves the phone until
the patient links someone.

## How it works

```
Patient phone                      Firestore (asia-south1)            Functions
-------------                      -----------------------            ---------
rescheduleAll / Taken / Skip  -->  patients/{uid}/doses/{date_plan_slot}
  (yesterday .. +2 days,             at, deadline, status, reason
   only what changed)                                                 checkMissedDoses (every 10 min)
                                                                        pending + past deadline
Help / Ask to buy / battery   -->  patients/{uid}/events/{id}         onCareEvent -> push
                                   patients/{uid}/photos/{id}
Caretaker: Send love / On it  -->  patients/{uid}/events/{id}         onCareEvent -> push to patient
Taken / skipped               -->  (dose doc changes)                 onDoseChanged -> push (by choice)
Code on patient phone         -->  invites/{code}                     claimInvite -> links/{pat_care}
```

* Phones sign in anonymously, so nobody needs an account.
* The deadline is the same one the app uses for "missed": 2 hours after the
  dose, or the next dose of that medicine if that is sooner
  (`missedDeadline` in `dose_log.dart`).
* Taken/Skip from a notification while the app is closed is uploaded from the
  notification's background isolate (`CareSync.run`).
* Alert text is written by the server in the reader's language (en/hi/mr,
  `functions/messages.js`).

Code: `lib/features/care/`, `functions/`, `firestore.rules`.

## One-time setup

1. Firebase console > **Build > Firestore Database > Create database**:
   *Standard edition*, location **asia-south1 (Mumbai)**, production mode.
   The functions are deployed to the same region; Firestore triggers need it.
2. **Build > Authentication > Get started > Sign-in method > Anonymous > Enable.**
3. Google Cloud console > **Billing > Budgets & alerts**: add a budget of
   ₹100 for the project with email alerts at 50 % and 100 %. (Budgets warn;
   they do not stop spending.)
4. Deploy from the repository root:

   ```sh
   (cd functions && npm install)
   firebase deploy --only firestore,functions
   firebase functions:artifacts:setpolicy --location asia-south1 --days 1
   ```

   The first deploy asks to enable a few Google APIs; accept.

## Staying inside the free tier

| Service | Free each month | What Reindeer uses |
|---|---|---|
| Cloud Scheduler | 3 jobs | 1 job (`checkMissedDoses`) |
| Cloud Functions | 2 M calls | ~4,500 scheduled + a few per dose |
| Firestore | 50 K reads/day, 20 K writes/day, 1 GiB | ~20 writes per patient per day; old data deleted daily |
| FCM, Anonymous Auth | free | - |
| Artifact Registry | 0.5 GB | function images; old ones removed by the policy above |

Built-in limits: instances capped at 1-2, every server query has a `limit()`,
uploads only send changed doses, prescription photos are ≤ ~550 KB and
deleted after 30 days, doses after 4 days, invites when they expire, one help
alert a minute, one battery alert per 12 hours, 10 code tries an hour.

## Tests

```sh
flutter test test/domain/care_sync_test.dart
(cd functions && npm test)          # notification wording
(cd functions && npm run test:rules) # security rules, on the emulator
```
