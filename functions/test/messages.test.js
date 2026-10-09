const test = require("node:test");
const assert = require("node:assert/strict");
const {compose, medList} = require("../messages");

test("missed alert names the person, medicines and time", () => {
  const m = compose("missed", "en", {name: "Mom", meds: "Metformin", time: "9:00 AM"});
  assert.equal(m.title, "Mom hasn't taken their medicine");
  assert.equal(m.body, "Metformin was due at 9:00 AM. Not marked as taken yet.");
});

test("skipped alert explains the reason in the reader's language", () => {
  const en = compose("skipped", "en", {name: "Dad", meds: "Atorvastatin", reason: "sideEffect"});
  assert.equal(en.body, "Atorvastatin. Reason: Side effect");
  const hi = compose("skipped", "hi", {name: "पापा", meds: "Metformin", reason: "fastingTravel"});
  assert.match(hi.body, /उपवास या यात्रा/);
});

test("skipped without a reason says so", () => {
  const m = compose("skipped", "en", {name: "Dad", meds: "X", reason: "unknown"});
  assert.equal(m.body, "X. No reason given.");
});

test("unknown language falls back to English", () => {
  assert.equal(compose("sos", "fr", {name: "Mom"}).title, "🆘 Mom needs help");
});

test("request mentions the photo only when there is one", () => {
  assert.equal(compose("request", "en", {name: "Mom", meds: "A, B", hasPhoto: false}).body, "A, B");
  assert.equal(
    compose("request", "en", {name: "Mom", meds: "A", hasPhoto: true}).body,
    "A · Prescription photo attached",
  );
});

test("medicine list is de-duplicated and shortened", () => {
  assert.equal(medList(["A", "B", "A"]), "A, B");
  assert.equal(medList(["A", "B", "C", "D", "E"]), "A, B, C +2");
});
