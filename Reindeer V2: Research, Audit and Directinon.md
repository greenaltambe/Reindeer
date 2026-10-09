# Reindeer V2: Research, Audit and Direction

Oct 9, 2026 · @Greenal

## Decision brief

Reindeer should become a **barrier-aware adherence companion for Indian adults on long-term medicines for blood pressure and diabetes (often 5+ medicines), set up with a family member**. It should stop competing on reminder count and features. These answers are recommendations for the team to approve; no code has been changed.

- **What the project should b****ecome:** an offline Android app that turns an Indian prescription ("1-0-1 after food") into a meal-anchored routine. It notices *why* doses are missed, prevents running out, records prescription changes cleanly, and gives the doctor a one-page dosing history.
- **Patient problem:** non-adherence in chronic disease is about 50% ([WHO 2003](https://www.who.int/news/item/01-07-2003-failure-to-take-prescribed-medicine-for-chronic-diseases-is-a-massive-world-wide-problem)). Forgetting is only one cause. Running out (37%), beliefs and cost also drive it ([Gadkari 2012](https://doaj.org/article/44bd39b397fe4efb80dca1daecdedfaa); [Horne 2013](https://ideas.repec.org/a/plo/pone00/0080633.html)), and supply interruptions are a named cause in rural India ([Roshini 2026](https://www.citedrive.com/en/discovery/from-prescription-to-practice-a-qualitative-study-of-medication-non-adherence-in-rural-tamil-nadu-india/)).
- **Who it is for:** adults aged 60+ with hypertension and/or diabetes and polypharmacy (49% pooled prevalence in older Indians, [Bhagavathula 2021](https://www.frontiersin.org/journals/pharmacology/articles/10.3389/fphar.2021.685518/full)). An adult child or carer usually installs and configures the app.
- **Strongest defensible differentiator:** the *barrier-aware missed-dose loop*. Each miss asks one tap of why (forgot, ran out, side effect, felt fine, cost, fasting). Each reason triggers a matched response, and the reasons feed the doctor report. No competitor or classmate project we found does this. It is built on Indian meal-anchored scheduling and offline Marathi/Hindi, which are rare in competitors.
- **Build first:**
  1. Fix the dose-identity bug (meal-time changes can re-remind a taken dose), daily reminder re-arming and plan editing with history.
  2. Missed-dose reason capture.
  3. Run-out forecast and refill reminders.
  4. A prescription-change review.
  5. The doctor-visit report.
- **Deliberately avoid:**
  - A drug-interaction checker: no open, commercially usable data; overlaps MedScan and ElderCare MedSafe.
  - An LLM medicine chatbot: published inaccuracy.
  - A caregiver dashboard server: ElderCare MedSafe, Memora and CarePath.
  - Symptom triage: the AI Symptom Checker project.
  - Expanding the Health tab.
- **Why a patient would care:** fewer surprise run-outs, no nagging when a dose is already logged, a clear record of what changed at the last visit, and something concrete to show the doctor.
- **Why it is different:** competitors and classmates treat a missed dose as a forgetting problem to remind about. Reindeer treats it as a signal with a cause, in an Indian prescription format, offline.
- **Evidence and what is unproven:**
  - **Supported:** reminders raise self-reported adherence in the short term (OR about 2, [Thakkar 2016](https://research.bond.edu.au/en/publications/mobile-telephone-text-messaging-for-medication-adherence-in-chron/), [Armitage 2020](https://bmjopen.bmj.com/content/10/1/e032045)). Feeding dosing history back adds about 10 points ([Demonceau 2013](https://link.springer.com/article/10.1007/s40265-013-0041-3)).
  - **Against reminder-only designs:** passive reminders were null in the largest trial ([REMIND, n=53,480](https://www.ehidc.org/sites/default/files/resources/files/Choudhry%20et%20al%20JAMA%20Int%20Med%202017.pdf)).
  - **Unproven:** that barrier-matched responses improve adherence, and that meal-anchored scheduling helps. Both are hypotheses we can test only for usability and correctness, not clinical effect.
- **Open question for the team:** the evaluation date. The roadmap below assumes about 2 weeks; if it is tomorrow, present this direction with V1 plus the bug fixes.

## Executive summary

V1 is a capable offline reminder app with real India-specific strengths. It also has two reliability bugs that must be fixed before anything is added, and its scope has drifted into health tracking that classmates already cover. The recommended V2 (Direction A below, weighted score 4.05 of 5 for its core feature) keeps the strengths and adds a small, testable layer aimed at *why* doses are missed.

- **Baseline:**
  - 106 Dart files (about 16,200 lines).
  - 24 test files (about 95 cases, almost all pure logic).
  - Reminders, meal-anchored schedules, offline search of Indian brands, Hindi/Marathi, voice and strip entry, backup, widget and a TB module.
- **Must fix first:**
  - Changing a meal time re-keys doses and can re-remind a taken dose.
  - Reminders stop if the app is not opened for 7 days.
  - Plans cannot be edited.
- **Classmates:** 5 of 16 other groups overlap with medication work:
  - DoseMate: basic reminders.
  - ElderCare MedSafe: elderly polypharmacy, interactions, caregiver dashboard.
  - MedScan: scan and interactions.
  - Memora and CarePath: caregiver alerts and discharge plans.

  The open space is Indian prescription format, missed-dose causes, supply gaps and prescription changes.
- **Evidence:**
  - Reminders help self-reported adherence over about 12 weeks but fail when passive.
  - Feedback of dosing history and a human follow-up loop have the best objective support.
  - India's own digital-adherence experience (99DOTS) shows that a logged dose is engagement, not proof of ingestion ([Thomas 2020](https://pmc.ncbi.nlm.nih.gov/articles/PMC7713673)).
- **Competitors:**
  - Medisafe became paid outside the US on 1 Jan 2026 ([Medisafe help](https://help-center.medisafe.com/en/articles/13052285-medisafe-is-now-a-fully-paid-app-for-users-outside-the-u-s)).
  - Interaction checkers are US/English-only.
  - No listing we checked offers meal-anchored scheduling, missed-dose reason capture or prescription-change reconciliation. This is absence in listings, not proof.
- **Method limits:**
  - The code was read, not run (no Flutter toolchain here).
  - PubMed, PMC and Europe PMC were often blocked, so papers were verified on publisher or repository pages. Claims that could not be verified were dropped or marked.

## V1 audit

V1's core design is sound: doses are derived from plans, and only actions are stored. But dose identity, reminder re-arming and plan editing are broken or missing, and several documented features do not exist. This audit comes from reading the 9 Oct snapshot of the repo. Nothing was built or run.

### What it does

- **Navigation:** five tabs (Today, Medicines, Health, Progress, You) in `shared/widgets/app_shell.dart`. Full-screen routes cover onboarding, add, settings, allergies, Medical ID, symptoms and TB.
- **Adding a medicine:**
  - `add_search_screen.dart` searches Indian brands and salts offline, with typo tolerance.
  - The search box reads shorthand (`shorthand_parser.dart`: 1-0-1, OD/BD/TDS/HS, AC/PC, durations), voice (`voice_input.dart`) and strip photos (ML Kit OCR plus `scan_candidates.dart`).
  - It then runs a nine-step wizard in `add_details_screen.dart`.
- **Scheduling:**
  - Three meal-anchored slots (`DaySlot`, `MealAnchors`, ±30 min), plus every-N-days, weekday masks and alternating amounts.
  - Not supported: clock-time doses, more than three doses a day, as-needed (PRN) or tapering.
- **Today screen:** doses grouped by time with Taken / Skip / Undo, a missed-dose card, a low-stock banner and a TB banner.
- **Notifications:**
  - `reminder_service.dart` schedules the next 7 days (`_horizonDays = 7`) on two channels (normal and insistent alarm).
  - Notification actions are handled in a background isolate.
  - Settings has a health panel with test notifications.
- **Data:**
  - `reindeer.db` schema v5 holds plans, dose logs (taken/skipped only; "missed" is derived after a 2 h grace), refills, settings, measurements, symptoms, allergies and DOTS observations.
  - The bundled medicine DB is built by `tools/build_medicine_db.py` from a community A–Z CSV and the Jan Aushadhi list.
- **Other features:**
  - Progress tab with 7/30-day adherence and a text doctor summary.
  - Allergy guard (9 classes) and same-ingredient overlap warning.
  - Health readings with charts, and a symptom diary.
  - Routine learning, home widget and JSON backup.
  - Hindi/Marathi (541 keys) and the TB/DOTS module.

### What it does well

- **Derived-dose model:** `MedicationPlan.dosesOn`, `DoseTimeline.build` and `missedDeadline`. Adherence returns no figure rather than a fake 0% when nothing is due yet.
- **Transactional stock accounting** in `DoseLogRepository.record/clear`.
- **Search engineering:** a Python reference, a Dart port and parity fixtures, and spelling correction that never changes strength numbers.
- **India-specific UX:** meal anchors, 1-0-1 notation, Hindi/Marathi with placeholder-parity tests, and Jan Aushadhi generics.
- **Honest wording:** for example, the README says it "does not check interactions".

### Missing or unreliable (ranked)

1. **Dose identity is the local clock time** (`planId|yyyy-MM-ddTHH:mm`). Changing a meal time (`_pickMeal`, or `_applyRoutine` from routine learning) orphans past logs, so they show as missed. A dose already taken today can be reminded again, which is a double-dose risk.
2. **Reminders silently stop after 7 days without opening the app.** There is no daily re-arm job and no time-zone or clock-change handling. Today shows no banner when notifications are blocked.
3. **Plans cannot be edited.** There is no `update` in `PlanRepository`. Only one pause window is stored, so a second pause marks the first pause's doses as missed.
4. **Release and policy problems:**
   - The release build is signed with the debug key and the app ID is `com.example.reindeer`.
   - It relies on `USE_EXACT_ALARM`, which Play restricts to alarm and calendar apps ([Play policy](https://support.google.com/googleplay/android-developer/answer/13161072)).
   - Snooze is inexact.
5. **Data provenance:**
   - The medicine dataset's licence is unverified.
   - Side-effect text is shipped, against spec §7.1.
   - Discontinued products are never labelled.
   - The app refuses to start if the medicine DB fails to unpack.
6. **Tests:**
   - No tests cover repositories, migrations, `ReminderService` or screens; there is one widget test.
   - CI uses an empty DB, so the search tests skip.
7. **Privacy:** an unencrypted DB, plain JSON backups, `allowBackup` left at its default, and a reversible 4-digit PIN hash.
8. **Translations:** notification buttons and missed-dose advice are not translated.
9. **Refill reminders:** marked "Must have" in the spec, but only an in-app banner exists.
10. **Scope and doc drift:**
    - The Health tab, symptom diary, mascot and TB module go beyond the spec's own scope.
    - The docs are stale (ARCHITECTURE says schema 3; ROADMAP lists shipped features as future work).
    - Dead code: `Result`, `AppException`, `Profile`, `PrimaryButton`, `barcode_links` and `cupertino_icons`.

### Claims versus code

| Claim (source) | What the code does |
| --- | --- |
| "Editing a plan never rewrites history" (PRESENTATION\_OUTLINE) | No plan editing; meal-time changes do rewrite history |
| Add, edit, refill, view history (spec §6) | No edit; no refill or dose history screen |
| Refill reminder is Must Have (spec §18) | In-app banner only |
| Daily refresh and time-zone handling (spec §12.1) | Only on app open or a change; stored zone never updated |
| Snooze capped at 3; missed doses stored (spec §5.3) | Neither |
| Symptoms and measurements excluded (spec §17.1) | Both implemented |

### Keep, improve, simplify, remove

| Feature | Verdict | Why |
| --- | --- | --- |
| Offline brand search, shorthand, add wizard | Keep; add edit mode | Core strength; rare in competitors |
| Meal-anchored timing | Improve | Fix dose identity; allow explicit times |
| Today, notifications, health panel | Improve | Daily re-arm, permission banner, exact snooze |
| Progress and doctor summary | Improve into the doctor-visit report | Best-evidenced "beyond reminder" feature |
| Stock tracking | Improve into run-out forecast and refill alerts | Running out is a top cause of missed doses |
| Voice and strip OCR entry | Keep (optional) | Cheap; keep confirm-before-save |
| Hindi/Marathi | Keep; cover notifications | Differentiator |
| Same-ingredient overlap, allergy guard | Keep as is | Defensible, no new data needed |
| Routine learning | Hold | Triggers the dose-identity bug |
| Health tab, symptom diary | Simplify (BP and sugar only); fold symptoms into "side effect" miss reason | Out of scope; overlaps classmates |
| TB/DOTS module | Generalise to an optional supporter mode or drop | Weak evidence (see literature) |
| Mascot easter eggs, dead code | Remove or minimise | Noise |

## Classmates' projects and overlap

Five of the 16 other groups overlap with medication work. ElderCare MedSafe is the closest, covering elderly polypharmacy, scanning, voice reminders, duplicate and interaction warnings, and a caregiver dashboard. So Reindeer should not lead with any of those. The spreadsheet lists proposals, not built apps, and is marked on Content, Presentation, Innovation and Q&A at 5 marks each. Only MediCore, Synapse and the Drug Launch Simulator filled in the Innovation column.

| Project (group) | Users and problem | Proposed features | Overlap with Reindeer | Could complement | Avoid duplicating |
| --- | --- | --- | --- | --- | --- |
| ElderCare MedSafe (11) | Elderly on many medicines | Add or scan medicines, large-font and voice reminders, duplicate and interaction warnings, caregiver dashboard with repeated-miss alerts | High: polypharmacy, scanning, voice, duplicates, caregiver | Nothing we should copy | Interaction checker, caregiver dashboard, "elder-friendly" as the headline |
| DoseMate (7) | Anyone organising daily medicines | Add, alert, taken or skipped, history | High, but basic: V1 already exceeds it | n/a | Plain reminder framing |
| MedScan (2) | Public wanting medicine info | Scan or enter a medicine, purpose, dosage, side effects, interaction checker | Medium: scanning and side-effect text | Patients could look up details there | Drug-info and interaction features |
| Memora (13) | Alzheimer's patients and carers | Medication reminders, cognitive aids, safety monitoring, emergency alerts to carers | Medium: reminders and caregiver alerts | Dementia-specific needs | Caregiver emergency alerting |
| CarePath (4) | Patients after hospital discharge | Discharge instructions turned into a plan, follow-ups, symptom check-ins, AI flags, caregiver or doctor dashboard | Medium: medicine schedules and care transitions | Hand-off at discharge | Discharge-to-plan conversion, symptom check-ins |
| MediCore (5) | Patients confused by reports | OCR of reports, translation, AI triage | Low: OCR and language | n/a | LLM explanations |
| AI Symptom Checker (12) | Patients deciding where to seek care | Guided triage | Low: our symptom diary | n/a | Symptom interpretation |
| AWaRe-Track (3) | Doctors prescribing antibiotics | Offline WHO AWaRe lookup | Low: offline drug data | n/a | n/a |

The other groups (Nutrition tracker, Maternal Health, HealthPulse dashboard, Synapse, HearYourEars, Appointment System, Drug Launch Simulator, ScreenSense) do not overlap.

**Differentiation that remains open:**

- **No group mentions why doses are missed, running out of medicine, or prescription changes over time.**
- **No group mentions Indian prescription notation (1-0-1, after food) or Marathi/Hindi.**
- **CarePath covers discharge, but as a one-time conversion.** A running record of each prescription change, with history kept, is different.

These are our working space. Inference: in the Q&A, examiners will likely ask "how is this different from ElderCare MedSafe and DoseMate?" The answer should be one sentence: *we treat a missed dose as a signal with a cause, not just a reminder to repeat.*

## Literature review

The evidence says reminders alone are a weak, short-lived intervention. Two things have better objective support: feeding people their own dosing history, and a human response loop triggered by a problem. Non-adherence also has causes reminders do not touch: running out, cost, beliefs and side effects. Twenty-four papers or reports were opened and checked. The full evidence table is in the last section.

### What we know

1. **The problem is large and has several causes.**
   - About 50% of chronic-disease patients do not take medicines as prescribed ([WHO 2003](https://www.who.int/news/item/01-07-2003-failure-to-take-prescribed-medicine-for-chronic-diseases-is-a-massive-world-wide-problem)); 30–50% according to [Kini & Ho 2018](https://vivo.weill.cornell.edu/display/pubid30561486).
   - In 24,017 US adults, 62% had forgotten a dose and 37% had run out. Even "unintentional" misses were predicted by beliefs and cost ([Gadkari & McHorney 2012](https://doaj.org/article/44bd39b397fe4efb80dca1daecdedfaa)).
   - Believing a medicine is necessary goes with better adherence (OR 1.74, 94 studies, [Horne 2013](https://ideas.repec.org/a/plo/pone00/0080633.html)).
   - In rural Tamil Nadu, non-adherence came from supply, cost and access interruptions, disrupted routines and deliberate changes ([Roshini 2026](https://www.citedrive.com/en/discovery/from-prescription-to-practice-a-qualitative-study-of-medication-non-adherence-in-rural-tamil-nadu-india/)).
2. **Reminders help self-report, briefly.** Text messages gave an OR of 2.11 (16 RCTs, median 12 weeks, mostly self-report). Personalisation, two-way messaging and daily frequency made no difference ([Thakkar 2016](https://research.bond.edu.au/en/publications/mobile-telephone-text-messaging-for-medication-adherence-in-chron/)). Apps gave an OR of 2.12 (9 RCTs, all at unclear risk of bias). No behaviour-change technique predicted the effect ([Armitage 2020](https://bmjopen.bmj.com/content/10/1/e032045)). A 2025 meta-analysis of 14 RCTs found no Indian trial ([Lanke 2025](https://www.jmir.org/2025/1/e60822)).
3. **Passive reminders often fail on objective measures.**
   - Pillboxes and timer caps had no effect in 53,480 patients ([REMIND, Choudhry 2017](https://www.ehidc.org/sites/default/files/resources/files/Choudhry%20et%20al%20JAMA%20Int%20Med%202017.pdf)).
   - SMS alone did not reduce missed TB doses in China (aMR 0.94). A reminder box that logged each dose did (aMR 0.58) ([Liu 2015](https://doaj.org/article/6bbd248076744f6495a20192a70196d8)).
   - Only 5 of the 17 best-quality trials improved both adherence and outcomes ([Cochrane 2014](https://www.cochrane.org/evidence/CD000011_interventions-enhancing-medication-adherence)).
4. **Feedback and a human loop do better.**
   - Showing patients their dosing history added about 10 points of objectively measured adherence (19.8 vs 10.3), fading by about 1.1 points a month ([Demonceau 2013](https://link.springer.com/article/10.1007/s40265-013-0041-3)).
   - In Kenya, a clinician calling anyone who reported a problem or didn't reply improved viral suppression (57% vs 48%) ([Lester 2010](https://www.ehidc.org/sites/default/files/resources/files/Lester%202010%20Lancet%20-%20SMS%20for%20adherence%20in%20Keyna.pdf)).
5. **More frequent reminders are not better.** Weekly texts raised the share of patients reaching 90% measured adherence by 13 points; daily texts had no effect ([Pop-Eleches 2011](https://www.povertyactionlab.org/node/8135725)). 62% of installers of a wellbeing app (not a medication app) had turned notifications off ([Bidargaddi 2018](https://mhealth.jmir.org/2018/11/e10123)).
6. **India's digital-adherence lessons (TB).** 99DOTS self-reports caught missed doses poorly (specificity 39–61% against urine tests, [Thomas 2020](https://pmc.ncbi.nlm.nih.gov/articles/PMC7713673)). Statewide rollout did not change outcomes (aOR 0.97), and only 33% of patients ever called ([Chen 2023](https://pmc.ncbi.nlm.nih.gov/articles/PMC10391893)). The 2025 ASCENT trials (about 23,000 patients) were also null ([KNCV summary](https://www.kncvtbplus.com/articles/news/researchers-unveil-ground-breaking-insights-digital-technologies-tuberculosis-care)).
7. **Who and how.**
   - Polypharmacy affects 49% of older Indians ([Bhagavathula 2021](https://www.frontiersin.org/journals/pharmacology/articles/10.3389/fphar.2021.685518/full)) and 33.7% in six cities. A recent hospital stay raises the odds (aOR 4.6) ([Das 2025](https://www.nature.com/articles/s41598-024-84627-2)).
   - Only 39.6% of Indians aged 60+ are literate ([LASI factsheet](https://www.iipsindia.ac.in/sites/default/files/other_files/LASI_W1_Factsheet_INDIA.pdf)).
   - Older first-time users scored medication apps 42–57 on a 100-point usability scale. Bare "+" icons and "Cancel" confused them ([Grindrod 2014](https://mhealth.jmir.org/2014/1/e11)).
   - Families do medication work but are poorly told about changes ([Manias 2019](https://link.springer.com/article/10.1186/s12877-019-1102-6)).

### Synthesis

- **A well-evidenced problem that apps under-serve:** running out, and intentional misses from beliefs, cost and side effects. Apps answer every miss with another reminder.
- **What works:** dosing-history feedback, and human follow-up triggered by a problem.
- **Mixed:** apps and SMS on self-report; pictograms ([van Beusekom 2017](https://research-portal.st-andrews.ac.uk/en/publications/pharmaceutical-pictograms-for-low-literate-patients-understanding/) found only half reached 67% comprehension).
- **Often fails:** passive or daily reminders; supervision tools without a responsive system.
- **Limits of the evidence:**
  - Short trials, mostly self-report.
  - Mostly high-income settings.
  - No Indian app RCT found.
  - Almost no clinical outcomes.
- **Under-explored:** reason-for-miss capture in apps; habit anchoring (10 of 11 studies link habit to adherence, but no habit-based app had been tested; [Badawy 2020](https://www.jmir.org/2020/4/e17883/)); prescription-change records kept by patients and families.
- **What a student project can test:** software correctness under simulated schedules, and usability with older adults and carers. Not clinical effect.
- **Not proven:** that any feature here improves real-world adherence. A tapped "taken" is engagement, not ingestion.

## Competitor matrix

Reminders, taken/skipped logs, refill counts and doctor reports are commonplace. Indian-language support, meal-anchored scheduling, missed-dose reasons and prescription-change reconciliation are rare or absent in every listing we checked. Sources were checked on 9 Oct 2026 from official sites and store listings. "Not listed" means we found no mention, not that the feature is confirmed absent.

| Product | Price (India) | Caregiver / family | Refill / stock | Interactions | Hindi or Marathi | Offline | Notable limit |
| --- | --- | --- | --- | --- | --- | --- | --- |
| [Medisafe](https://help-center.medisafe.com/en/articles/13052285-medisafe-is-now-a-fully-paid-app-for-users-outside-the-u-s) | Paid outside the US since 1 Jan 2026: $4.99/mo or $39.99/yr | Medfriend missed-dose alerts (account) | Refill reminders | US and English only | Not listed | Not listed | Paywall; users call notifications "nagging" |
| [MyTherapy](https://play.google.com/store/apps/details?id=eu.smartpatient.mytherapy&hl=en_IN) | Free with ads | Multiple profiles | Pill counter, reorder reminder | None found | 32 languages, Hindi not confirmed | Not listed | Play data-safety: may share data |
| [Apple Health Medications](https://support.apple.com/en-ca/105064) | Free, iPhone only | Health Sharing | Not listed | US only | Not listed | On-device | 30-min follow-up if not logged; no Android |
| [Tata 1mg](https://play.google.com/store/apps/details?id=com.aranoah.healthkart.plus&hl=en_IN) | Free (pharmacy) | Family records | Not listed | Drug info | Not listed | Not listed | Reminders inside a shopping app |
| [Eka Care](https://apps.apple.com/app/id1561621558) | Free; Eka Pass $2.49/mo | Not listed | Not listed | Not listed | Hindi, Kannada | Not listed | Records-first (ABHA) |
| [Aarogya Setu 2.0](https://www.onmanorama.com/health/healthcare/2026/06/27/arogya-setu-app-launch-features.amp.html) | Free (government) | Family profiles (news reports only) | Not listed | Not listed | Not confirmed | Not listed | New since Jun 2026; reminders from prescriptions |
| [Dosezy](https://f-droid.org/fr/packages/com.saad2134.dosezy/) | Free, open source | Family profiles | Stock and refill warning | Not listed | Hindi + 11 more | Yes, encrypted | Small project; closest in spirit |
| [CareClinic](https://apps.apple.com/us/app/-/id1455648231) | Free + in-app purchases | Care Teams | Refill reminders | Yes | 73 languages, list not checked | Not listed | Only one with a with/without-food flag |

**Published app reviews:**

- **Common:** reminders in 86–92% of apps.
- **Rare:** caregiver monitoring in 5.2%, SMS in 1.4% and any evidence base in 1% ([Ahmed 2018](https://mhealth.jmir.org:443/2018/3/e62)); interaction checking in 3.7% ([Tabi 2019](https://mhealth.jmir.org/2019/9/e13608)).
- **Top complaint:** technical problems, in 29.7% of reviews ([Park 2019](https://mhealth.jmir.org/2019/1/e11919)).
- **Reliability risk:** [dontkillmyapp](https://dontkillmyapp.com/) rates Xiaomi, Samsung and OnePlus as the worst at killing background apps (5/5) and Oppo 4/5. If these brands dominate in India, as we expect but did not verify, phone brand is the biggest threat to reminder reliability.

**What we found:**

- **Commonplace:** reminders, logs, refill counts, reports, family profiles.
- **Partial:** caregiver alerts (always account- or server-based), and interaction checks (US-only).
- **Rare or not found:** meal-anchored scheduling; reason-for-miss capture; reconciliation of a changed prescription against the current list; an offline database of Indian brands; voice prompts in Marathi or Hindi.
- **Biggest positioning question:** Aarogya Setu 2.0. Answer: it is records-first and online. Reindeer is offline, works from the routine, and explains misses.

## Patient needs and opportunities

Older adults with hypertension and diabetes, supported by family, are the strongest target. The problem is large, the daily difficulties are concrete, and we can demonstrate value without patient data. TB is a serious need, but India's own digital-adherence evidence there is null, and we cannot integrate with Nikshay.

| Group or problem | How serious | Day-to-day difficulty | Gap in current solutions | Can we demo without patient data? | Verdict |
| --- | --- | --- | --- | --- | --- |
| Older adults, hypertension and diabetes, 5+ medicines | Measured hypertension in 36.2% of those aged 60+, of whom only 42.3% are adequately treated ([LASI](https://www.iipsindia.ac.in/sites/default/files/other_files/LASI_W1_Factsheet_INDIA.pdf)); polypharmacy 49% | Many timings around meals; running out; low literacy (39.6% literate) | Apps are English-first, clock-based and paywalled | Yes, with synthetic regimens and usability tests | **Primary** |
| Family carers | Families give and monitor medicines ([Manias 2019](https://link.springer.com/article/10.1186/s12877-019-1102-6)) | Not told what changed; shared phones (46–49% of women share, [Kilkari](https://pmc.ncbi.nlm.nih.gov/articles/PMC9288869/)) | Caregiver features need accounts and servers; classmates cover dashboards | Yes | **Secondary user, not the headline** |
| Prescription changes and discharge | 15% have discrepancies after discharge ([Coleman 2005](https://psnet.ahrq.gov/issue/posthospital-medication-discrepancies-prevalence-and-contributing-factors)); a recent hospital stay raises polypharmacy odds (aOR 4.6) ([Das 2025](https://www.nature.com/articles/s41598-024-84627-2)) | Old and new lists mixed up | No consumer app found that reconciles changes; CarePath does a one-time discharge plan | Yes, with synthetic prescription pairs | **Include as a feature** |
| Running out of medicine | 37% have run out ([Gadkari 2012](https://doaj.org/article/44bd39b397fe4efb80dca1daecdedfaa)); medicines are up to 67% of out-of-pocket spending ([Selvaraj 2018](https://bmjopen.bmj.com/content/8/5/e018020)) | Pharmacy trips, cost | Refill counts exist, but rarely as a forecast tied to misses | Yes | **Include** |
| TB (6-month course) | High burden; DOTS is national policy | Long course, side effects, stigma | DAT evidence null in India and in ASCENT; no Nikshay API | Partly | **Optional mode, not the core** |
| Dementia, post-discharge recovery, elderly safety | Real | Real | Covered by Memora, CarePath and ElderCare MedSafe | n/a | **Avoid** |

Because older adults see little need for an app until health declines ([Grindrod 2014](https://mhealth.jmir.org/2014/1/e11)), the best moment to start is a new prescription or a hospital discharge. The family member who sets it up is the realistic installer. This is an inference from low digital literacy: 11% in rural Mysore ([DAHLIA](https://doaj.org/article/84c3b157657d43428b43f94bc238b9f1)).

## Candidate innovations, scored

Five ideas clear 3.5 out of 5, led by the barrier-aware missed-dose loop (4.05). They form one workflow rather than five features: a schedule that matches the prescription, a miss that is explained, supply that is protected, changes that are recorded, and a visit that is informed. Popular ideas such as family escalation and an LLM helper score low here, and an interaction checker was excluded before scoring (no usable data; see Architecture). They duplicate classmates or lack safe data.

&#91;embedded content: Scores set by this review using the brief's weights: benefit 25%, differentiation 20%, evidence 15%, feasibility 15%, demonstrability 10%, India fit 10%, learning 5%\]

Each criterion is scored 1–5, and the chart shows the weighted total. We kept the brief's weights unchanged.

| Idea | Benefit | Differentiation | Evidence | Feasibility | Demo | India fit | Learning |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Barrier-aware missed-dose loop | 4 | 4 | 3 | 5 | 5 | 4 | 3 |
| Meal-anchored Indian scheduling | 4 | 4 | 2 | 4 | 5 | 5 | 3 |
| Prescription-change reconciliation | 4 | 4 | 3 | 3 | 4 | 4 | 4 |
| Supply-gap prevention | 4 | 3 | 3 | 4 | 4 | 5 | 3 |
| Doctor-visit dosing-history review | 4 | 2 | 4 | 5 | 4 | 3 | 2 |
| Regional voice + pictogram reminders | 3 | 3 | 2 | 4 | 5 | 5 | 3 |
| TB/DOTS supporter mode | 3 | 4 | 1 | 4 | 4 | 4 | 2 |
| Duplicate-ingredient guard (Indian FDCs) | 3 | 2 | 4 | 3 | 4 | 4 | 3 |
| Sparse reminders + escalation ladder | 3 | 2 | 3 | 4 | 4 | 3 | 3 |
| Habit anchoring at setup | 2 | 4 | 2 | 5 | 3 | 3 | 2 |
| Offline family escalation (no account) | 3 | 2 | 3 | 3 | 4 | 4 | 3 |
| LLM ask-about-my-medicine | 2 | 1 | 1 | 3 | 4 | 2 | 5 |

| Idea | Novelty | Effort | External data or services | Main risk | Needs clinical input? | Real patient data? | Local demo? |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Barrier-aware missed-dose loop: one-tap reason, then a matched response (refill flow, note for doctor, belief card, reminder change) | Potentially underexplored | Low | None | Wording of belief and side-effect cards | Review of card text | No | Yes |
| Meal-anchored scheduling with 1-0-1, voice and strip entry | Differentiated combination (exists in V1) | Low (fix identity bug) | None | Dose-identity bug | No | No | Yes |
| Prescription-change reconciliation: versioned plans, a "what changed" diff, a shareable current list | Potentially underexplored | Medium | None | Data migration | No | No | Yes |
| Supply-gap prevention: run-out forecast, refill reminder, Jan Aushadhi generic hint | Differentiated combination | Low–medium | Jan Aushadhi list (public) | Stock counts drift | No | No | Yes |
| Doctor-visit review: calendar, reasons summary, changes, one page in English | Established, with a new combination | Low | None | Implying verified adherence | No | No | Yes |
| Regional voice and pictograms | Potentially underexplored (voice) | Medium | Android text-to-speech voices | Pictogram misreading | Pictogram testing | No | Yes |
| TB/DOTS supporter mode | Established (99DOTS, VOT) | Done | None | Null outcome evidence; stigma | Regimen check | No | Yes |
| Duplicate-ingredient guard | Established | Medium | Brand-to-salt mapping of unverified quality | False alarms and missed alerts | Yes | No | Yes |
| Sparse reminders and escalation | Established (Apple 30-min follow-up) | Low | None | Alarm reliability | No | No | Yes |
| Habit anchoring | Research hypothesis | Low | None | Little effect | No | No | Partly |
| Offline family escalation | Differentiated combination | Medium | SMS through the user's own messages app (Play restricts automatic SMS) | Consent, alert fatigue | No | No | Yes |
| LLM helper | Established elsewhere | Medium | Cloud LLM | Harmful answers (14% in one study) | Yes | No | Yes |

The top five win because each one targets a documented cause of missed doses, needs no new external data, and can be shown working on one phone in a few minutes. Regional voice reminders are the best idea we left out, and they come back as polish if time allows. The duplicate-ingredient guard is defensible on evidence ([Chidiac 2024](https://link.springer.com/10.1007/s40264-024-01472-y): 19.6% of paracetamol dosing errors involved several products). V1 already has a basic version, and improving it depends on data we cannot verify.

## Three project directions

We recommend **Direction A, "Reindeer: why-aware adherence for chronic care"**. It has the clearest patient benefit, the least overlap with classmates, needs no outside data, and reuses most of V1. Direction B is too close to ElderCare MedSafe and Memora. Direction C is distinctive but rests on evidence that is null in India.

### A. Reindeer: why-aware adherence for chronic care (recommended)

- **Users and unmet need:**
  - Adults aged 60+ with hypertension and/or diabetes on several medicines, set up by a family member.
  - Apps answer every miss with another reminder. They ignore running out, side effects, beliefs and prescription changes.
- **Problem statement:** older Indians on long-term medicines miss doses for different reasons, and the reminder apps they could use treat all misses as forgetting.
- **Value proposition:** reminders that fit an Indian prescription, plus one tap to say why a dose was missed. The app then responds to that reason and tells the doctor.
- **Core features:**
  1. Meal-anchored routine from 1-0-1 shorthand, voice or a strip photo, with the identity bug fixed and editable plans.
  2. A missed-dose reason with a matched response:
     - Forgot: reminder change and habit anchor.
     - Ran out: refill flow.
     - Side effect: note for the doctor plus a "don't stop on your own" card.
     - Felt fine: "why this medicine matters" card.
     - Cost: Jan Aushadhi generic hint.
  3. Run-out forecast with refill reminders.
  4. Prescription-change record: versioned plans and a "what changed" list.
  5. One-page doctor-visit report: dosing calendar, miss reasons, changes.
- **Differentiator:** the reason-to-response loop. No competitor listing or classmate proposal we found has it.
- **Evidence:**
  - Causes beyond forgetting ([Gadkari 2012](https://doaj.org/article/44bd39b397fe4efb80dca1daecdedfaa), [Horne 2013](https://ideas.repec.org/a/plo/pone00/0080633.html), [Roshini 2026](https://www.citedrive.com/en/discovery/from-prescription-to-practice-a-qualitative-study-of-medication-non-adherence-in-rural-tamil-nadu-india/)).
  - Feedback works ([Demonceau 2013](https://link.springer.com/article/10.1007/s40265-013-0041-3)); passive reminders fail ([REMIND](https://www.ehidc.org/sites/default/files/resources/files/Choudhry%20et%20al%20JAMA%20Int%20Med%202017.pdf)).
- **User journey:**
  1. Priya installs the app for her father and types "amlo 5 1-0-0 after food, metformin 500 1-0-1".
  2. At 9:00 he skips a dose and taps "ran out".
  3. The app shows a refill list and moves the run-out alert earlier.
  4. At the next visit, the doctor sees two misses marked "ran out" and one marked "dizzy".
  5. The doctor changes the dose. Priya records the change, and the old plan's history is kept.
- **Technology and data:** the existing Flutter, sqflite and notifications stack, plus the public Jan Aushadhi list. No server.
- **Safety and privacy:**
  - No dosing advice, and no "stop" advice.
  - Side-effect reasons route to "tell your doctor".
  - Data stays on the device.
  - The report says "self-recorded".
- **Scope:** medium.
  - Most of the work is a schema change (dose identity, plan versions, miss reasons) and three screens.
  - MVP: features 1–5.
  - Deferred: voice reminders, family SMS escalation, duplicate-ingredient upgrade.
- **Evaluation:** simulated schedules for correctness; usability with 5–8 older adults and carers; reason-routing tests.

### B. Family Circle: shared medicine care for a household

- **Users:** one adult child managing medicines for two or more elders on one shared phone, or across phones without accounts.
- **Problem:** families do medication work but are poorly informed ([Manias 2019](https://link.springer.com/article/10.1186/s12877-019-1102-6)).
- **Core features:**
  1. Multiple profiles.
  2. Per-person reminders with names spoken in Marathi or Hindi.
  3. A missed-dose escalation ladder to the family by SMS, opened as a prepared message in the user's messages app.
  4. A daily digest.
  5. A shared change log.
- **Differentiator:** escalation without accounts or servers.
- **Weakness:**
  - Strong overlap with ElderCare MedSafe (caregiver dashboard, repeated-miss alerts), Memora and CarePath.
  - Google Play restricts apps that send SMS automatically.
  - The evidence on caregiver alerts is weak.
- **Evaluation:** escalation-rule scenarios and a carer usability test.

### C. Reindeer DOTS: a long-course companion for TB

- **Users:** people on 6-month TB treatment and their treatment supporters.
- **Problem:** stopping TB treatment early.
- **Core features:** the existing TB module, extended:
  1. Phase-aware schedule.
  2. Supporter confirmation.
  3. Side-effect red flags.
  4. Nutrition-support reminders.
  5. A report with the Nikshay ID.
- **Differentiator:** no classmate chose TB, and it is the professor's own example.
- **Weakness:**
  - India's digital-adherence evidence is null (99DOTS statewide aOR 0.97, [Chen 2023](https://pmc.ncbi.nlm.nih.gov/articles/PMC10391893); ASCENT null).
  - Self-confirmation is inaccurate ([Thomas 2020](https://pmc.ncbi.nlm.nih.gov/articles/PMC7713673)).
  - There is no Nikshay API.
  - Regimen details need clinical checking.
  - Stigma risk on shared phones.
- **Evaluation:** regimen-calendar correctness and supporter usability.

### Comparison

|  | A. Why-aware chronic care | B. Family Circle | C. DOTS companion |
| --- | --- | --- | --- |
| Patient benefit | Addresses several documented causes | Supports carers | High need, weak tool evidence |
| Overlap with classmates | Low | High (ElderCare MedSafe, Memora, CarePath) | None |
| Evidence for the approach | Mixed to good on components | Weak | Null in India |
| Reuse of V1 | High | Medium | High (already built) |
| External dependencies | None | SMS policy limits | Clinical review |
| Demo without patient data | Yes | Yes | Yes |

A keeps the TB work as an optional supporter mode inside the same app, so the effort is not lost.

## V2 features, workflows and UI

V2 keeps the five-tab app, but each tab gets narrower: the core loop is now take, miss with a reason, refill, and review. Health and Symptoms shrink into supporting roles. Every change below maps to a V1 file.

### Feature set

| Area | Keep | Add or change | Remove or postpone |
| --- | --- | --- | --- |
| Schedule | Meal anchors, 1-0-1 parser, voice and strip entry | Stable dose key (`planId + date + slot`); optional clock time per dose; QID and as-needed (PRN) | Routine-learning auto-shift (until the key is fixed) |
| Missed dose | Taken / Skip / Undo, missed-dose card | Reason chips on Skip and on a missed dose; matched response card; one follow-up reminder, then quiet | Unlimited snooze |
| Supply | Stock, low-stock banner | Run-out date per medicine; refill notification N days ahead; "I bought more" quick entry; Jan Aushadhi generic name shown for the salt | Refill history screen (later) |
| Prescription change | Pause, resume, stop | Edit plan through the wizard; plan versions with an effective date; "What changed" list after a visit; multiple pause windows | Import of FHIR prescriptions (later) |
| Report | Doctor summary text | One-page visit report: 30-day calendar, miss reasons, changes since the last visit, "self-recorded" label; English for the doctor | PDF styling (later) |
| Safety | Allergy guard, same-ingredient overlap | Side-effect reason links to a "tell your doctor" card, never "stop" | Interaction checker; shipped side-effect text without a source |
| Scope | Hindi/Marathi, widget, backup | Translate notification buttons and missed-dose text | Health tab reduced to BP and sugar; symptom diary folded into the side-effect reason; mascot easter eggs; TB moved to optional "Supporter mode" |

### Redesigned workflows

1. **Missed or skipped dose:**
   - The notification has buttons for Taken and for Not now.
   - After the grace period, Today shows the dose in red with "Why was it missed?" and six chips: *Forgot, Ran out, Side effect, Felt fine, Cost, Fasting or travel*.
   - Each chip opens one response card:
     - Ran out: refill list.
     - Side effect: "Tell your doctor; don't stop on your own", plus a note added to the report.
     - Felt fine: a short "why this medicine matters" card.
   - No chip is required. Ignoring it stores "unknown".
2. **Prescription change after a visit:** Medicines → "Doctor changed my medicines" → tick the ones changed or stopped and add new ones → review "What changed" (started / stopped / dose changed) → save. Old versions stay in history, and the report shows the diff.
3. **Refill:**
   - The run-out date is shown under each medicine.
   - A notification arrives 5 days before (configurable).
   - "I bought more" asks for one number.
   - A miss marked "ran out" moves the alert earlier next time.
4. **Doctor visit:** Progress → "Prepare for doctor" → a one-page report, shared through the share sheet or shown on screen.

### UI and UX direction

The design should look like a calm paper prescription card, not a fitness app.

- **Look:** warm off-white surfaces, one strong accent for actions, and red only for a missed dose.
- **Type:**
  - Body text at least 18 sp, numbers 22 sp.
  - Respect system font scaling up to 200%, and test it.
- **Navigation:** keep 5 tabs, but rename them for the loop: *Today, Medicines, Refills, Reports, You*. Health moves inside Reports as "Readings".
- **Today:**
  - Time-of-day sections (Morning · after breakfast) with a meal icon and a text label.
  - One large Taken button per dose (at least 56 dp).
  - Reason chips appear only on misses.
  - A permission banner appears whenever notifications or exact alarms are off.
- **Adding and editing:** the same linear wizard for both. Confirm OCR and voice results before saving. Write "Go back without saving" instead of "Cancel" ([Grindrod 2014](https://mhealth.jmir.org/2014/1/e11)).
- **History:** a month calendar coloured by status, using pattern as well as colour (✓, ✕, ?) so it reads without colour vision.
- **Accessibility:**
  - Contrast at least 4.5:1.
  - Every icon has a text label.
  - TalkBack labels on dose rows.
  - Voice playback of each instruction in the app language.
- **Empty, loading and error states:**
  - The first-run empty state offers "Type the prescription line".
  - A failed medicine-DB unpack still allows custom entry.
  - Permission screens explain why before asking, and show the OEM auto-start steps (OPPO/ColorOS, Xiaomi, Vivo).

## Architecture, safety and privacy

No rewrite is needed. V2 is a schema migration to v6, a reminder-pipeline hardening pass, and three new screens on the existing Flutter, Riverpod and sqflite stack.

### Data model (schema v6)

- **`dose_logs`:** add `dose_date` and `slot`. The key becomes (`plan_id`, `dose_date`, `slot`). Keep `scheduled_at` for display only. Migrate existing rows by deriving date and slot from the stored time.
- **`plan_versions`:**
  - One row per change, holding amounts, timing, frequency, `effective_from` and a `reason`.
  - `plans` keeps identity and stock.
  - `dosesOn(day)` uses the version effective that day.
- **`plan_pauses`:** one row per pause window, replacing the single `stopped_at`/`resumed_at` pair.
- **`miss_reasons`:** `plan_id`, `dose_date`, `slot`, `reason` (enum), `note` and `at`.
- **`refills`:** start reading it for the run-out forecast and history.
- **Remove:** `barcode_links` and the dead classes.

### Reminders

- **Daily re-arm:** a daily background job (WorkManager, or an inexact daily alarm) re-runs `rescheduleAll`. Also re-run it on `TIMEZONE_CHANGED`, `TIME_SET` and boot. Re-detect the time zone on each run.
- **Exact alarms:** request `SCHEDULE_EXACT_ALARM` with an explanation screen, and drop reliance on `USE_EXACT_ALARM`. On Android 14 the permission is denied by default, and Play limits `USE_EXACT_ALARM` to alarm and calendar apps ([Android 14](https://developer.android.com/about/versions/14/changes/schedule-exact-alarms); [Play policy](https://support.google.com/googleplay/android-developer/answer/13161072)). If denied, fall back to inexact scheduling and show a banner.
- **Follow-ups:** one follow-up 30 minutes after an unlogged dose, then nothing more. This is conditional, not repeated nagging ([Pop-Eleches 2011](https://www.povertyactionlab.org/node/8135725)).
- **Snooze:** exact, at most 3 times, and only within the grace window.
- **Widget:** apply widget ticks natively, through a broadcast receiver that writes the log, so the reminder does not fire afterwards.
- **OEM killers:** detect the manufacturer and show auto-start steps; ColorOS kills background apps ([dontkillmyapp](https://dontkillmyapp.com/oppo)).

### Integrations: what is and is not feasible

- **Jan Aushadhi product list:** feasible. Use it as a static, dated asset.
- **ABDM/ABHA:** sandbox only. Production needs NHA certification and a WASA audit. Optional later work: import an NRCeS FHIR PrescriptionRecord from a file ([NRCeS IG v6.5.0](https://nrces.in/ndhm/fhir/r4/index.html)).
- **Health Connect:** has no medication record type. Its medical-records API is Android 16+ and still under development ([docs](https://developer.android.com/health-and-fitness/guides/personal-health-records/overview)). Skip it.
- **Interaction data:** no open source allows commercial use.
  - DrugBank's open data has no interactions.
  - DDInter is non-commercial ShareAlike.
  - RxNav's interaction API was announced for shutdown in January 2024 ([NLM](https://lhncbc.nlm.nih.gov/RxNav/APIs/InteractionAPIs.html); [DDInter terms](https://ddinter2.scbdd.com/terms/)).
  - So do not build an interaction checker.
- **Nikshay/99DOTS:** no public API found.

### Safety

- **No dosing or stop advice.** Missed-dose guidance stays generic and is reviewed by a pharmacist or doctor before the demo.
- **Same-ingredient overlap stays.** Its value is backed by [Chidiac 2024](https://link.springer.com/10.1007/s40264-024-01472-y). Word it as "check with your pharmacist".
- **No LLM in any safety path.** Published evaluations found 10 of 39 drug answers satisfactory and fabricated references ([Drug Topics](https://www.drugtopics.com/view/chatgpt-provides-inaccurate-responses-to-questions-about-drug-information)).
- **Medicine dataset:**
  - Label the source and date in the app.
  - Show a discontinued tag.
  - Stop showing side-effect text until its source is verified.
- **Reports say "self-recorded, not verified intake"** ([Thomas 2020](https://pmc.ncbi.nlm.nih.gov/articles/PMC7713673)).

### Privacy (DPDP-ready)

DPDP Rules were notified 13 Nov 2025; most duties apply from about May 2027 ([AZB](https://www.azbpartners.com/bank/indias-digital-personal-data-protection-act-phased-rollout-and-key-compliance-milestones/)).

- **Data:** keep it on the device, with no network permission.
- **Notice and consent:** a plain notice at onboarding.
- **Export and delete:** export-all and delete-all.
- **Backups:** set `allowBackup=false`, or exclude the databases from auto-backup. Offer a password-encrypted backup.
- **App lock:** an optional lock for shared phones.
- **Notifications:** keep disease names off the lock screen; use the medicine nickname only.
- **TB PIN:** drop the 4-digit PIN; it gives no real security.
- **CDSCO:** draft software guidance (Oct 2025) may cover apps with a "medical purpose" ([India Briefing](https://india-briefing.com/news/cdsco-draft-guidance-medical-software-40691.html)). Keeping to logging and reminders, without dosing advice, lowers that risk but does not rule it out.

### Testing and maintainability

- **Data layer:** repository and migration tests (v1 to v6) with `sqflite_common_ffi`.
- **Reminders:** `ReminderService` tests using a fake notification plugin.
- **Screens:** widget tests for Today, the add/edit wizard and reason chips.
- **CI:** a small real medicine-DB fixture so the search tests stop skipping.
- **Release:** a release error log, a real application ID and a release keystore.

## Roadmap and evaluation

The work runs in four phases, each with a gate the team can check. The evaluation tests correctness and usability honestly. It does not claim adherence or clinical benefit, which would need a trial.

### Roadmap

1. **Reliability fixes (about 3–4 days). Must ship before the demo.**
   - Stable dose key and migration.
   - Daily re-arm, plus time-zone and clock-change handling.
   - Permission banner on Today.
   - Exact-alarm request flow.
   - Translated notification buttons.
   - Medicine DB made optional at startup.
   - *Gate:* the scenario tests below pass. A 7-day unattended run on the CPH2707 (ColorOS) logs every reminder.
2. **MVP (about 4–5 days):**
   - Edit plan with versions and multiple pauses.
   - Missed-dose reason chips and response cards.
   - Run-out forecast and refill notification.
   - *Gate:* the reason-routing tests pass, and editing a dose keeps the previous 30 days of history unchanged.
3. **Differentiators (about 3–4 days):**
   - "What changed" review.
   - Doctor-visit report with calendar, reasons and changes.
   - Jan Aushadhi generic hint.
   - *Gate:* the reconciliation test set is 100% correct, and 5 or more usability participants complete the core tasks.
4. **Optional:**
   - Voice playback in Marathi and Hindi.
   - Supporter mode (generalised from TB).
   - Duplicate-ingredient upgrade.
   - FHIR prescription import from a file.
   - Encrypted backup.

**Dependencies:** phase 2 needs phase 1's dose key; the report in phase 3 needs phase 2's reasons and versions.

**Integration risks:**

- Background re-arming on ColorOS.
- Data migration on phones already running V1.
- Translation review time.

### Evaluation plan

| Method | What it measures | Metric and target | What it cannot show |
| --- | --- | --- | --- |
| Scenario simulation (synthetic regimens: 3 users, 30 days, with meal-time changes, pauses, edits, travel time zone) | Scheduling and history correctness | 100% of expected doses scheduled; 0 duplicate reminders after a meal-time change; history unchanged after edits | Real-world adherence |
| Notification reliability run on 2+ phones including ColorOS | Delivery | % delivered within 1 minute, over 7 days, app not opened; target 95% or more | Other phone brands |
| Reason-routing tests | Each of the 6 reasons opens the right response and appears in the report | 100% | Whether responses change behaviour |
| Reconciliation test set (20 synthetic old/new prescription pairs) | Started / stopped / changed detection | 100% correct diff | Free-text prescription reading |
| Usability with 5–8 older adults plus carers | Learnability | Task completion (add from "1-0-1", record a miss reason, edit a dose, share the report); errors; time; System Usability Scale, target 68 or more ([Grindrod 2014](https://mhealth.jmir.org/2014/1/e11) found 42–57 for existing apps) | Long-term use |
| Localisation review by native Marathi and Hindi speakers | Clarity and safety of wording | 0 meaning errors in safety text | Dialect coverage |
| Strip OCR on 30 photographed strips (team's own medicines) | Name-capture accuracy | % with the correct brand in the top 3 suggestions | Accuracy on damaged strips |
| Capability comparison with Medisafe, MyTherapy, Apple Health, Dosezy and Aarogya Setu 2.0 | Positioning | Feature matrix from documented sources | Hands-on quality |

Simulated adherence numbers are software tests, not evidence that patients will adhere better. The presentation should say this plainly.

## Evidence table and sources

Every recommendation traces to a source, a code observation or a labelled hypothesis. All sources were opened on 9 Oct 2026. Where PubMed or PMC was blocked, a publisher or repository page was used instead.

| Recommendation | Basis | Type |
| --- | --- | --- |
| Missed-dose reasons with matched responses | Gadkari 2012; Horne 2013; Roshini 2026 | Need is evidence-based; that the response helps is a **hypothesis** |
| Meal-anchored scheduling | Common Indian prescription practice; absent from competitor listings | **Hypothesis** (no study found) |
| Run-out forecast and refills | Gadkari 2012 (37% ran out); Selvaraj 2018; Roshini 2026 | Evidence of need |
| Prescription-change record | Coleman 2005; Manias 2019; Das 2025 | Need is evidence-based; app effect is a **hypothesis** |
| Doctor-visit history report | Demonceau 2013 | Evidence (objective measures) |
| Conditional, not daily, reminders | Pop-Eleches 2011; Bidargaddi 2018; Thakkar 2016 | Evidence |
| "Self-recorded" label | Thomas 2020 | Evidence |
| No interaction checker or LLM | DrugBank, DDInter, NLM licence pages; Drug Topics; medRxiv 2024 | Evidence plus licence facts |
| Fix dose identity and re-arming first | V1 audit (`reminder_service.dart`, `you_screen.dart`) | Code observation |
| Exact-alarm permission flow | Android 14 docs; Play policy | Platform documentation |

### Sources

**Adherence and interventions**

- WHO (2003). [Adherence to long-term therapies](https://www.who.int/news/item/01-07-2003-failure-to-take-prescribed-medicine-for-chronic-diseases-is-a-massive-world-wide-problem).
- Kini V, Ho PM (2018). [Interventions to Improve Medication Adherence: A Review](https://vivo.weill.cornell.edu/display/pubid30561486). *JAMA* 320(23). doi:10.1001/jama.2018.19271.
- Gadkari AS, McHorney CA (2012). [Unintentional non-adherence to chronic prescription medications](https://doaj.org/article/44bd39b397fe4efb80dca1daecdedfaa). *BMC Health Serv Res* 12:98.
- Horne R et al. (2013). [Necessity-Concerns Framework meta-analysis](https://ideas.repec.org/a/plo/pone00/0080633.html). *PLOS ONE* 8(12):e80633.
- Nieuwlaat R et al. (2014). [Interventions for enhancing medication adherence](https://www.cochrane.org/evidence/CD000011_interventions-enhancing-medication-adherence). Cochrane CD000011.
- Thakkar J et al. (2016). [Text messaging for medication adherence in chronic disease: a meta-analysis](https://research.bond.edu.au/en/publications/mobile-telephone-text-messaging-for-medication-adherence-in-chron/). *JAMA Intern Med* 176(3):340–349.
- Armitage LC et al. (2020). [Do mobile apps for medication adherence demonstrate efficacy?](https://bmjopen.bmj.com/content/10/1/e032045). *BMJ Open* 10(1):e032045.
- Pérez-Jover V et al. (2019). [Mobile apps for increasing treatment adherence](https://www.jmir.org/2019/6/e12505). *JMIR* 21(6):e12505.
- Lanke V et al. (2025). [Effectiveness of mobile apps on medication adherence](https://www.jmir.org/2025/1/e60822). *JMIR* 27:e60822.
- Choudhry NK et al. (2017). [REMIND randomized trial](https://www.ehidc.org/sites/default/files/resources/files/Choudhry%20et%20al%20JAMA%20Int%20Med%202017.pdf). *JAMA Intern Med*.
- Demonceau J et al. (2013). [Adherence interventions with electronic dosing histories](https://link.springer.com/article/10.1007/s40265-013-0041-3). *Drugs* 73(6):545–562.
- Lester RT et al. (2010). [WelTel Kenya1 SMS trial](https://www.ehidc.org/sites/default/files/resources/files/Lester%202010%20Lancet%20-%20SMS%20for%20adherence%20in%20Keyna.pdf). *Lancet*.
- Pop-Eleches C et al. (2011). [Text message reminders, Kenya](https://www.povertyactionlab.org/node/8135725). *AIDS* (via J-PAL).
- Liu X et al. (2015). [Electronic reminders for TB adherence, China](https://doaj.org/article/6bbd248076744f6495a20192a70196d8). *PLoS Med* 12(9):e1001876.
- Bidargaddi N et al. (2018). [To prompt or not to prompt?](https://mhealth.jmir.org/2018/11/e10123). *JMIR mHealth uHealth* 6(11):e10123.
- Badawy SM et al. (2020). [Habit strength and habit-based mHealth](https://www.jmir.org/2020/4/e17883/). *JMIR* 22(4):e17883.

**TB and digital adherence in India**

- Thomas BE et al. (2020). [Accuracy of 99DOTS vs urine isoniazid](https://pmc.ncbi.nlm.nih.gov/articles/PMC7713673). *Clin Infect Dis* 71(9).
- Chen AZ et al. (2023). [99DOTS outcomes in Himachal Pradesh](https://pmc.ncbi.nlm.nih.gov/articles/PMC10391893). *BMC Infect Dis* 23:504.
- Subbaraman R et al. (2018). [Digital adherence technologies for TB](https://eprints.nirt.res.in/1657/). *BMJ Glob Health*.
- Story A et al. (2019). [Video-observed vs directly observed TB therapy](https://discovery.ucl.ac.uk/id/eprint/10069521/). *Lancet* 393.
- KNCV (2025). [ASCENT trials summary](https://www.kncvtbplus.com/articles/news/researchers-unveil-ground-breaking-insights-digital-technologies-tuberculosis-care).

**Patient needs (India and older adults)**

- Bhagavathula AS et al. (2021). [Polypharmacy in older adults in India](https://www.frontiersin.org/journals/pharmacology/articles/10.3389/fphar.2021.685518/full). *Front Pharmacol* 12.
- Das S et al. (2025). [Polypharmacy and self-medication among older urban Indians](https://www.nature.com/articles/s41598-024-84627-2). *Sci Rep* 15:4062.
- IIPS. [LASI Wave-1 India factsheet](https://www.iipsindia.ac.in/sites/default/files/other_files/LASI_W1_Factsheet_INDIA.pdf).
- Grindrod KA et al. (2014). [Medication apps with older adults: usability](https://mhealth.jmir.org/2014/1/e11). *JMIR mHealth uHealth* 2(1):e11.
- Manias E et al. (2019). [Family involvement in older patients' medications](https://link.springer.com/article/10.1186/s12877-019-1102-6). *BMC Geriatr* 19:95.
- Roshini RA et al. (2026). [Medication non-adherence in rural Tamil Nadu](https://www.citedrive.com/en/discovery/from-prescription-to-practice-a-qualitative-study-of-medication-non-adherence-in-rural-tamil-nadu-india/). *BMJ Open*.
- Selvaraj S et al. (2018). [Out-of-pocket spending on medicines in India](https://bmjopen.bmj.com/content/8/5/e018020). *BMJ Open* 8(5).
- van Beusekom MM et al. (2017). [Pharmaceutical pictograms for low-literate patients](https://research-portal.st-andrews.ac.uk/en/publications/pharmaceutical-pictograms-for-low-literate-patients-understanding/). *Patient Educ Couns* 100(5).
- Coleman EA et al. (2005). [Post-hospital medication discrepancies](https://psnet.ahrq.gov/issue/posthospital-medication-discrepancies-prevalence-and-contributing-factors). *Arch Intern Med* 165.
- LeFevre AE et al. (2022). [Kilkari RCT](https://pmc.ncbi.nlm.nih.gov/articles/PMC9288869/). *BMJ Glob Health*.
- Rasekaba TM et al. (2022). [DAHLIA: digital literacy of older rural Indians](https://doaj.org/article/84c3b157657d43428b43f94bc238b9f1). *Geriatrics* 7(2):28.

**Competitors and app reviews**

- Medisafe paywall: [help centre](https://help-center.medisafe.com/en/articles/13052285-medisafe-is-now-a-fully-paid-app-for-users-outside-the-u-s).
- Store listings and official pages: [Apple Health Medications](https://support.apple.com/en-ca/105064), [MyTherapy](https://play.google.com/store/apps/details?id=eu.smartpatient.mytherapy&hl=en_IN), [Tata 1mg](https://play.google.com/store/apps/details?id=com.aranoah.healthkart.plus&hl=en_IN), [Dosezy](https://f-droid.org/fr/packages/com.saad2134.dosezy/), [Eka Care](https://apps.apple.com/app/id1561621558), [Aarogya Setu 2.0 (news)](https://www.onmanorama.com/health/healthcare/2026/06/27/arogya-setu-app-launch-features.amp.html).
- Published app reviews: [Ahmed 2018](https://mhealth.jmir.org:443/2018/3/e62), [Park 2019](https://mhealth.jmir.org/2019/1/e11919), [Tabi 2019](https://mhealth.jmir.org/2019/9/e13608).
- Background-kill ratings: [dontkillmyapp](https://dontkillmyapp.com/).

**Safety, data, platform and regulation**

- Chidiac AS et al. (2024). [Paracetamol dosing errors](https://link.springer.com/10.1007/s40264-024-01472-y). *Drug Saf* 47(12).
- Interaction data licences: [NLM RxNav interaction API notice](https://lhncbc.nlm.nih.gov/RxNav/APIs/InteractionAPIs.html), [DrugBank open data](https://go.drugbank.com/releases/latest#open-data), [DDInter terms](https://ddinter2.scbdd.com/terms/).
- LLM accuracy: [Drug Topics on ChatGPT drug answers](https://www.drugtopics.com/view/chatgpt-provides-inaccurate-responses-to-questions-about-drug-information), [GPT-4 interaction preprint](https://www.medrxiv.org/content/10.1101/2024.06.29.24309701.full.pdf).
- Platform: [Android 14 exact alarms](https://developer.android.com/about/versions/14/changes/schedule-exact-alarms), [Play exact-alarm policy](https://support.google.com/googleplay/android-developer/answer/13161072), [Health Connect medical records](https://developer.android.com/health-and-fitness/guides/personal-health-records/overview).
- Records standard: [NRCeS FHIR IG](https://nrces.in/ndhm/fhir/r4/index.html).
- Regulation: [DPDP rollout (AZB)](https://www.azbpartners.com/bank/indias-digital-personal-data-protection-act-phased-rollout-and-key-compliance-milestones/), [CDSCO draft software guidance (India Briefing)](https://india-briefing.com/news/cdsco-draft-guidance-medical-software-40691.html).

**Could not verify, so not used for claims:**

- India pooled adherence meta-analyses for hypertension and diabetes.
- The van der Sijs alert-override range.
- The Phansalkar high-priority interaction list.
- OCR accuracy on Indian blister strips.
- Whether CDSCO's draft covers reminder apps.
