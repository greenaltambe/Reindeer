// Firestore security rules tests. Run with:
//   firebase emulators:exec --only firestore "node --test functions/rules-test"
const test = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const {doc, setDoc, getDoc, updateDoc, deleteDoc, collection, query, where, getDocs, Timestamp} =
  require("firebase/firestore");

let env;

test.before(async () => {
  env = await initializeTestEnvironment({
    projectId: "reindeer-rules-test",
    firestore: {rules: fs.readFileSync(path.join(__dirname, "../../firestore.rules"), "utf8")},
  });
});

test.after(async () => env && env.cleanup());

test.beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "links/pat_care"), {
      patientUid: "pat",
      caretakerUid: "care",
      nickname: "Mom",
      caretakerName: "Rahul",
      notifyTaken: false,
      notifySkipped: true,
    });
    await setDoc(doc(db, "patients/pat/doses/2026-10-09_1_morning"), {status: "pending"});
    await setDoc(doc(db, "patients/pat/photos/e1"), {data: "abc"});
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();

test("a patient makes an invite; strangers cannot read it", async () => {
  const now = Timestamp.now();
  await assertSucceeds(setDoc(doc(as("pat"), "invites/123456"), {
    patientUid: "pat", patientName: "Asha", createdAt: now, expiresAt: now,
  }));
  await assertFails(getDoc(doc(as("stranger"), "invites/123456")));
  // A code already in use cannot be taken over.
  await assertFails(setDoc(doc(as("other"), "invites/123456"), {
    patientUid: "other", patientName: "X", createdAt: now, expiresAt: now,
  }));
});

test("nobody can create a link directly", async () => {
  await assertFails(setDoc(doc(as("care"), "links/pat2_care"), {
    patientUid: "pat2", caretakerUid: "care",
  }));
});

test("both sides can list their links", async () => {
  await assertSucceeds(getDocs(query(collection(as("pat"), "links"), where("patientUid", "==", "pat"))));
  await assertSucceeds(getDocs(query(collection(as("care"), "links"), where("caretakerUid", "==", "care"))));
  await assertFails(getDocs(query(collection(as("stranger"), "links"), where("patientUid", "==", "pat"))));
});

test("caretaker may change only their own fields", async () => {
  await assertSucceeds(updateDoc(doc(as("care"), "links/pat_care"), {nickname: "Amma", notifyTaken: true}));
  await assertFails(updateDoc(doc(as("care"), "links/pat_care"), {patientUid: "evil"}));
  await assertFails(updateDoc(doc(as("pat"), "links/pat_care"), {caretakerName: "Someone else"}));
});

test("either side can unlink", async () => {
  await assertSucceeds(deleteDoc(doc(as("pat"), "links/pat_care")));
});

test("linked caretaker reads doses and photos; strangers do not", async () => {
  await assertSucceeds(getDocs(query(collection(as("care"), "patients/pat/doses"), where("date", "==", "2026-10-09"))));
  await assertSucceeds(getDoc(doc(as("care"), "patients/pat/photos/e1")));
  await assertFails(getDoc(doc(as("stranger"), "patients/pat/doses/2026-10-09_1_morning")));
  await assertFails(getDoc(doc(as("stranger"), "patients/pat/photos/e1")));
});

test("only the patient writes their doses", async () => {
  await assertSucceeds(setDoc(doc(as("pat"), "patients/pat/doses/x"), {status: "taken"}));
  await assertFails(setDoc(doc(as("care"), "patients/pat/doses/x"), {status: "taken"}));
});

test("event senders are checked", async () => {
  const at = Timestamp.now();
  await assertSucceeds(setDoc(doc(as("pat"), "patients/pat/events/a"), {type: "sos", from: "pat", createdAt: at}));
  await assertSucceeds(setDoc(doc(as("pat"), "patients/pat/events/b"), {
    type: "request", from: "pat", createdAt: at, items: ["A"], hasPhoto: true,
  }));
  await assertSucceeds(setDoc(doc(as("care"), "patients/pat/events/c"), {type: "love", from: "care", createdAt: at}));
  // A caretaker cannot fake a help alert, a stranger cannot send love,
  // and nobody can pretend to be someone else.
  await assertFails(setDoc(doc(as("care"), "patients/pat/events/d"), {type: "sos", from: "care", createdAt: at}));
  await assertFails(setDoc(doc(as("stranger"), "patients/pat/events/e"), {type: "love", from: "stranger", createdAt: at}));
  await assertFails(setDoc(doc(as("care"), "patients/pat/events/f"), {type: "love", from: "pat", createdAt: at}));
  await assertFails(setDoc(doc(as("pat"), "patients/pat/events/g"), {type: "sos", from: "pat", createdAt: at, extra: 1}));
});

test("photos are limited in size", async () => {
  const at = Timestamp.now();
  await assertSucceeds(setDoc(doc(as("pat"), "patients/pat/photos/p1"), {data: "x".repeat(1000), createdAt: at}));
  await assertFails(setDoc(doc(as("pat"), "patients/pat/photos/p2"), {data: "x".repeat(760000), createdAt: at}));
});

test("device tokens are private", async () => {
  await assertSucceeds(setDoc(doc(as("care"), "users/care"), {token: "t"}));
  await assertFails(getDoc(doc(as("pat"), "users/care")));
});
