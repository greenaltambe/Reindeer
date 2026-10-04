# Reindeer: presentation outline and demo script

Draft for the Oct 10 presentation. Adjust after the app has been run on a phone.

## Slide outline (about 10 minutes)

1. **Problem.** Missed doses are common; most reminder apps are cloud-first, global, and not built around Indian medicines or meal-based instructions.
2. **Survey.** What Medisafe and My Therapy do well and where they fall short (your survey notes).
3. **Idea.** Reindeer: a local-first, India-focused medicine reminder. No account, no server, data stays on the phone.
4. **Key features.**
   - Search that survives misspellings and any word order (brand or salt names).
   - Reminders tied to meals ("after breakfast"), not just clock times.
   - Big-tile quick add designed for older users.
   - Custom medicines when something is not in the list.
   - Same-ingredient alternatives, run-out date, doctor summary.
5. **Search deep-dive.** Data sources (community A-Z dataset plus the Jan Aushadhi generic list), the pipeline (normalise, correct, index), and the measured results: ingredient names 99.6% top-1, noisy brand names 79.5% top-1, on 1,000 synthetic misspelled queries.
6. **Architecture.** Flutter + Riverpod, two SQLite databases (read-only medicine list, private app data), local notifications with Taken / Skip / Snooze buttons, no backend. Why no backend.
7. **Reliability.** Doses are derived from the plan, so editing a plan never rewrites history; missed doses are computed, not stored; reminders are rescheduled on every change and app open.
8. **Privacy and safety.** Everything on device; disclaimer: a reminder tool, not medical advice; dataset licence caveat.
9. **Demo** (below).
10. **Limits and next steps.** Barcode learning needs one manual link per pack (no public barcode-to-medicine list), iOS not tested, caregiver profiles, refill prediction, OCR of the label.

## Demo script (about 3 minutes)

1. Open app, show Today with the reindeer greeting.
2. Add medicine: type the misspelled salt query from your own bottle ("Levosalbutanol sulphate, Ambroxal hydrochoride and guaiphenesin exeectorant") and show it finds Ascoril LS.
3. Pick "Twice a day", "After food", "7 days", stock 100 ml. Save.
4. Show the reminder: change breakfast time in Settings and show reminders move. Send a test reminder; tap Taken from the notification.
5. Show Progress and "copy summary for my doctor".
6. Tap the reindeer (easter egg).
7. Optional: scan a pack, link it, scan again.

## Questions to expect

- *Why no backend?* Privacy, works offline, nothing to host; backend only worth it for multi-device or caregiver sharing.
- *Where does the data come from, is it accurate?* Public lists; shown as reference, user confirms against the strip.
- *How is search accuracy measured?* Synthetic noisy queries over real names; numbers above; Python reference and Dart port checked against the same fixtures.
- *What if a medicine is missing?* Custom entry, clearly marked.
