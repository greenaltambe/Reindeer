// Reindeer caretaker alerts.
//
// The patient's phone uploads the next few days of doses (time, deadline,
// status). A scheduled check finds doses still pending after their deadline
// and tells the patient's caretakers. Other alerts (help, medicine requests,
// low battery, "send love") are documents the phones create; a trigger turns
// each one into a push notification.
//
// Free-tier limits: one scheduler job (3 are free), small instances capped at
// 1-2, every query bounded with limit(), and a daily clean-up so stored data
// stays tiny.

const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue, Timestamp} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const {setGlobalOptions} = require("firebase-functions/v2");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {
  onDocumentWritten,
  onDocumentCreated,
} = require("firebase-functions/v2/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const {compose, medList} = require("./messages");

initializeApp();
const db = getFirestore();

// Must match the Firestore database location.
setGlobalOptions({
  region: "asia-south1",
  memory: "256MiB",
  timeoutSeconds: 60,
  maxInstances: 2,
});

const HOUR = 60 * 60 * 1000;
const CARE_CHANNEL = "care_alerts";
const EMERGENCY_CHANNEL = "care_emergency";

// A dose uploaded long after its deadline (phone was offline) is not worth
// waking anyone for.
const STALE_AFTER = 6 * HOUR;

// Taken/skipped news older than this (for example the first upload after
// linking) is history, not news.
const FRESH_WITHIN = 2 * HOUR;

/** Trims user text to a safe length. */
function clean(value, max) {
  return typeof value === "string" ? value.trim().slice(0, max) : "";
}

/** The caretakers of [patientUid] with their notification choices. */
async function caretakersOf(patientUid) {
  const snap = await db
    .collection("links")
    .where("patientUid", "==", patientUid)
    .limit(10)
    .get();
  return snap.docs.map((d) => ({
    uid: d.get("caretakerUid"),
    nickname: d.get("nickname") || "",
    caretakerName: d.get("caretakerName") || "",
    notifyTaken: d.get("notifyTaken") === true,
    notifySkipped: d.get("notifySkipped") !== false,
  }));
}

async function patientName(patientUid) {
  const doc = await db.doc(`patients/${patientUid}`).get();
  return doc.exists ? doc.get("name") || "" : "";
}

/**
 * Sends one notification to the phone of [uid], in that phone's language.
 * Forgets the token if FCM says the app was uninstalled.
 */
async function notify(uid, kind, args, {channel = CARE_CHANNEL, route = "/care", tag} = {}) {
  const user = await db.doc(`users/${uid}`).get();
  const token = user.exists ? user.get("token") : null;
  if (!token) return false;
  const {title, body} = compose(kind, user.get("lang") || "en", args);
  try {
    await getMessaging().send({
      token,
      notification: {title, body},
      data: {kind, route},
      android: {
        priority: "high",
        notification: {
          channelId: channel,
          icon: "ic_notification",
          ...(tag ? {tag} : {}),
        },
      },
    });
    return true;
  } catch (e) {
    const code = e && e.code;
    if (
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token"
    ) {
      await user.ref.update({token: FieldValue.delete()});
    } else {
      logger.warn("Could not send notification", {uid, kind, code});
    }
    return false;
  }
}

/** What a caretaker calls the patient, with sensible fallbacks. */
function displayName(caretaker, fallback) {
  return caretaker.nickname || fallback || "Your family member";
}

// ---------------------------------------------------------------------------
// Linking

/**
 * A caretaker redeems the 6-digit code shown on the patient's phone. Creates
 * the link and removes the code so it cannot be used again.
 */
exports.claimInvite = onCall({maxInstances: 2}, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");
  const code = String((request.data && request.data.code) || "").replace(/\D/g, "");
  if (code.length !== 6) throw new HttpsError("invalid-argument", "bad-code");
  const caretakerName = clean(request.data.name, 60);

  // Slows down guessing: at most 10 tries an hour for each phone.
  const userRef = db.doc(`users/${uid}`);
  const user = await userRef.get();
  const recent = ((user.exists && user.get("claimAttempts")) || []).filter(
    (t) => t > Date.now() - HOUR,
  );
  if (recent.length >= 10) {
    throw new HttpsError("resource-exhausted", "too-many-tries");
  }
  await userRef.set({claimAttempts: [...recent, Date.now()]}, {merge: true});

  return db.runTransaction(async (tx) => {
    const inviteRef = db.doc(`invites/${code}`);
    const invite = await tx.get(inviteRef);
    if (!invite.exists || invite.get("expiresAt").toMillis() < Date.now()) {
      throw new HttpsError("not-found", "bad-code");
    }
    const patientUid = invite.get("patientUid");
    if (patientUid === uid) {
      throw new HttpsError("failed-precondition", "own-code");
    }
    const name = invite.get("patientName") || "";
    tx.set(
      db.doc(`links/${patientUid}_${uid}`),
      {
        patientUid,
        caretakerUid: uid,
        patientName: name,
        nickname: name,
        caretakerName,
        caretakerPhone: "",
        notifyTaken: false,
        notifySkipped: true,
        createdAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    tx.delete(inviteRef);
    return {patientUid, patientName: name};
  });
});

// ---------------------------------------------------------------------------
// Missed doses

exports.checkMissedDoses = onSchedule(
  {
    schedule: "every 10 minutes",
    timeZone: "Asia/Kolkata",
    maxInstances: 1,
    retryCount: 0,
  },
  async () => {
    const now = Date.now();
    const snap = await db
      .collectionGroup("doses")
      .where("status", "==", "pending")
      .where("alerted", "==", false)
      .where("deadline", "<=", Timestamp.fromMillis(now))
      .limit(300)
      .get();

    if (!snap.empty) {
      // patientUid -> "date|time" -> dose names
      const byPatient = new Map();
      const batch = db.batch();
      for (const doc of snap.docs) {
        batch.update(doc.ref, {alerted: true, alertedAt: FieldValue.serverTimestamp()});
        if (now - doc.get("deadline").toMillis() > STALE_AFTER) continue;
        const uid = doc.ref.parent.parent.id;
        const slots = byPatient.get(uid) || new Map();
        const key = `${doc.get("date")}|${doc.get("time")}`;
        slots.set(key, [...(slots.get(key) || []), doc.get("name")]);
        byPatient.set(uid, slots);
      }
      await batch.commit();

      for (const [uid, slots] of byPatient) {
        const caretakers = await caretakersOf(uid);
        if (caretakers.length === 0) continue;
        const fallback = await patientName(uid);
        for (const [key, names] of slots) {
          const time = key.split("|")[1];
          for (const c of caretakers) {
            await notify(
              c.uid,
              "missed",
              {name: displayName(c, fallback), meds: medList(names), time},
              {tag: `missed-${uid}-${key}`},
            );
          }
        }
      }
    }

    // Once a day, around 03:00 India time: drop old data.
    const ist = new Date(now + 5.5 * HOUR);
    if (ist.getUTCHours() === 3 && ist.getUTCMinutes() < 10) {
      await cleanUp(now);
    }
  },
);

async function deleteAll(query) {
  const snap = await query.get();
  if (snap.empty) return 0;
  const batch = db.batch();
  snap.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
  return snap.size;
}

async function cleanUp(now) {
  const doses = await deleteAll(
    db
      .collectionGroup("doses")
      .where("deadline", "<", Timestamp.fromMillis(now - 4 * 24 * HOUR))
      .limit(400),
  );
  const events = await deleteAll(
    db
      .collectionGroup("events")
      .where("createdAt", "<", Timestamp.fromMillis(now - 30 * 24 * HOUR))
      .limit(200),
  );
  const photos = await deleteAll(
    db
      .collectionGroup("photos")
      .where("createdAt", "<", Timestamp.fromMillis(now - 30 * 24 * HOUR))
      .limit(100),
  );
  const invites = await deleteAll(
    db.collection("invites").where("expiresAt", "<", Timestamp.fromMillis(now)).limit(200),
  );
  logger.info("Clean-up", {doses, events, photos, invites});
}

// ---------------------------------------------------------------------------
// Taken / skipped news

exports.onDoseChanged = onDocumentWritten(
  {document: "patients/{uid}/doses/{doseId}", maxInstances: 2},
  async (event) => {
    const before = event.data.before.exists ? event.data.before.data() : null;
    const after = event.data.after.exists ? event.data.after.data() : null;
    if (!after || (before && before.status === after.status)) return;
    if (after.status !== "taken" && after.status !== "skipped") return;
    const doneAt = after.doneAt ? after.doneAt.toMillis() : 0;
    if (Date.now() - doneAt > FRESH_WITHIN) return;

    const uid = event.params.uid;
    const caretakers = await caretakersOf(uid);
    if (caretakers.length === 0) return;
    const fallback = await patientName(uid);
    const wasAlerted = before ? before.alerted === true : false;

    if (after.status === "taken") {
      let takenNames = null;
      for (const c of caretakers) {
        const name = displayName(c, fallback);
        if (wasAlerted) {
          // Undoes the worry from the missed-dose alert.
          await notify(c.uid, "late", {name, meds: after.name}, {
            tag: `missed-${uid}-${after.date}|${after.time}`,
          });
        } else if (c.notifyTaken) {
          if (takenNames === null) {
            // One notification per time slot, updated as each dose is ticked.
            const slot = await db
              .collection(`patients/${uid}/doses`)
              .where("date", "==", after.date)
              .where("time", "==", after.time)
              .limit(20)
              .get();
            takenNames = slot.docs
              .filter((d) => d.get("status") === "taken")
              .map((d) => d.get("name"));
          }
          await notify(
            c.uid,
            "taken",
            {name, meds: medList(takenNames), time: after.doneTime || after.time},
            {tag: `taken-${uid}-${after.date}|${after.time}`},
          );
        }
      }
    } else {
      for (const c of caretakers) {
        if (!c.notifySkipped) continue;
        await notify(
          c.uid,
          "skipped",
          {name: displayName(c, fallback), meds: after.name, reason: after.reason || ""},
          {tag: `skip-${uid}-${event.params.doseId}`},
        );
      }
    }
  },
);

// ---------------------------------------------------------------------------
// Help, medicine requests, battery, love

exports.onCareEvent = onDocumentCreated(
  {document: "patients/{uid}/events/{eventId}", maxInstances: 2},
  async (event) => {
    const data = event.data && event.data.data();
    if (!data) return;
    const uid = event.params.uid;
    const type = data.type;

    if (type === "love" || type === "onit") {
      // Caretaker -> patient.
      const link = await db.doc(`links/${uid}_${data.from}`).get();
      if (!link.exists) return;
      await notify(uid, type, {from: link.get("caretakerName") || "Your family"}, {
        route: "/",
        tag: type,
      });
      return;
    }

    const caretakers = await caretakersOf(uid);
    if (caretakers.length === 0) return;
    const fallback = await patientName(uid);

    if (type === "battery") {
      const patientRef = db.doc(`patients/${uid}`);
      const patient = await patientRef.get();
      const last = patient.exists && patient.get("batteryAlertAt");
      if (last && Date.now() - last.toMillis() < 12 * HOUR) return;
      await patientRef.set({batteryAlertAt: FieldValue.serverTimestamp()}, {merge: true});
    }

    for (const c of caretakers) {
      const name = displayName(c, fallback);
      switch (type) {
        case "sos":
          await notify(c.uid, "sos", {name}, {channel: EMERGENCY_CHANNEL, tag: `sos-${uid}`});
          break;
        case "request":
          await notify(
            c.uid,
            "request",
            {
              name,
              meds: medList(Array.isArray(data.items) ? data.items : [], 4),
              hasPhoto: data.hasPhoto === true,
            },
            {route: `/care/request/${uid}/${event.params.eventId}`},
          );
          break;
        case "battery":
          await notify(c.uid, "battery", {name, level: data.level}, {tag: `battery-${uid}`});
          break;
        default:
          break;
      }
    }
  },
);
