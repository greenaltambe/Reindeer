# Roadmap

## Done

**v1.0.** Android, local only. Medicine search, guided add, meal-based reminders with action
buttons, Today / Medicines / Progress, stock and low-stock warnings, doctor summary,
prescription shorthand, same-ingredient warning, allergy guard, Medical ID, symptom diary,
missed-dose guidance, unusual-reading flags, share summary, conditions list, onboarding,
profile, Health tab, custom icon.

**Since v1.0.**
- Stable dose identity, versioned plans, multiple pause windows (DB schema v6).
- Missed-dose reasons with matched guidance; refill forecast; "doctor changed my medicines".
- Five-tab layout (Today, Medicines, Refills, Reports, You).
- Prescription and strip scanning, voice entry, flexible dosing (every N days, weekdays).
- Pharmacy and Jan Aushadhi purchase links.
- Hindi and Marathi, loud repeating reminders, routine suggestions.
- Home-screen widget, backup/restore, TB DOTS care.
- Optional family alerts for caretakers (Firebase).

## Not yet verified

- Prescription scanning and shorthand on real prescriptions.
- Reminders after a reboot and under aggressive battery saving, on several phones.
- Family alerts end to end on real devices and at scale (free-tier limits).
- Medicine dataset licence and accuracy.

## Later

- Appointments, diary, contacts.
- Multiple profiles on one phone.
- More languages.
- Optional: iOS.

The original product specification is in `PRODUCT_SPECIFICATION.md`; it is broader than v1.
