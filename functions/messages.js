// Notification wording in the reader's language. Pure functions, so they can
// be tested without Firebase.

const TEXT = {
  en: {
    missedTitle: "{name} hasn't taken their medicine",
    missedBody: "{meds} was due at {time}. Not marked as taken yet.",
    lateTitle: "{name} has now taken their medicine",
    lateBody: "{meds} ✓",
    takenTitle: "✅ {name} took their medicine",
    takenBody: "{meds} at {time}",
    skippedTitle: "{name} skipped a medicine",
    skippedBody: "{meds}. Reason: {reason}",
    skippedNoReason: "{meds}. No reason given.",
    sosTitle: "🆘 {name} needs help",
    sosBody: "{name} pressed the Help button. Please call them now.",
    requestTitle: "{name} needs medicines",
    requestPhoto: "Prescription photo attached",
    batteryTitle: "{name}'s phone battery is low",
    batteryBody: "{level}% left. Reminders stop if the phone switches off.",
    loveTitle: "❤️ {from} is thinking of you",
    loveBody: "{from} sent you love.",
    onitTitle: "{from} is getting your medicines",
    onitBody: "No need to worry.",
    reasons: {
      forgot: "Forgot",
      ranOut: "Ran out",
      sideEffect: "Side effect",
      feltFine: "Felt fine",
      cost: "Cost / price",
      fastingTravel: "Fasting or travel",
      unknown: "Other / unknown",
    },
  },
  hi: {
    missedTitle: "{name} ने अभी तक दवा नहीं ली",
    missedBody: "{meds} का समय {time} था। अभी तक 'लिया' नहीं दबाया।",
    lateTitle: "{name} ने अब दवा ले ली",
    lateBody: "{meds} ✓",
    takenTitle: "✅ {name} ने दवा ले ली",
    takenBody: "{meds}, {time} पर",
    skippedTitle: "{name} ने एक दवा छोड़ दी",
    skippedBody: "{meds}। कारण: {reason}",
    skippedNoReason: "{meds}। कोई कारण नहीं बताया।",
    sosTitle: "🆘 {name} को मदद चाहिए",
    sosBody: "{name} ने मदद का बटन दबाया है। कृपया अभी फ़ोन करें।",
    requestTitle: "{name} को दवाइयाँ चाहिए",
    requestPhoto: "पर्चे की फ़ोटो साथ में है",
    batteryTitle: "{name} के फ़ोन की बैटरी कम है",
    batteryBody: "{level}% बची है। फ़ोन बंद हुआ तो रिमाइंडर नहीं बजेंगे।",
    loveTitle: "❤️ {from} आपको याद कर रहे हैं",
    loveBody: "{from} ने प्यार भेजा है।",
    onitTitle: "{from} आपकी दवाइयाँ ला रहे हैं",
    onitBody: "चिंता न करें।",
    reasons: {
      forgot: "भूल गए",
      ranOut: "दवा खत्म हो गई",
      sideEffect: "दुष्प्रभाव (साइड इफेक्ट)",
      feltFine: "अच्छा लग रहा था",
      cost: "दवा की कीमत / खर्च",
      fastingTravel: "उपवास या यात्रा",
      unknown: "अन्य / अज्ञात कारण",
    },
  },
  mr: {
    missedTitle: "{name} यांनी अजून औषध घेतले नाही",
    missedBody: "{meds} ची वेळ {time} होती. अजून 'घेतले' दाबलेले नाही.",
    lateTitle: "{name} यांनी आता औषध घेतले",
    lateBody: "{meds} ✓",
    takenTitle: "✅ {name} यांनी औषध घेतले",
    takenBody: "{meds}, {time} वाजता",
    skippedTitle: "{name} यांनी एक औषध वगळले",
    skippedBody: "{meds}. कारण: {reason}",
    skippedNoReason: "{meds}. कारण दिले नाही.",
    sosTitle: "🆘 {name} यांना मदत हवी आहे",
    sosBody: "{name} यांनी मदतीचे बटण दाबले. कृपया आत्ताच फोन करा.",
    requestTitle: "{name} यांना औषधे हवी आहेत",
    requestPhoto: "प्रिस्क्रिप्शनचा फोटो सोबत आहे",
    batteryTitle: "{name} यांच्या फोनची बॅटरी कमी आहे",
    batteryBody: "{level}% उरली आहे. फोन बंद झाला तर रिमाइंडर वाजणार नाहीत.",
    loveTitle: "❤️ {from} तुमची आठवण काढत आहेत",
    loveBody: "{from} यांनी प्रेम पाठवले आहे.",
    onitTitle: "{from} तुमची औषधे आणत आहेत",
    onitBody: "काळजी करू नका.",
    reasons: {
      forgot: "विसरलो",
      ranOut: "औषध संपले",
      sideEffect: "दुष्परिणाम (साइड इफेक्ट)",
      feltFine: "बरे वाटत होते",
      cost: "औषधाचा खर्च",
      fastingTravel: "उपवास किंवा प्रवास",
      unknown: "इतर / माहीत नाही",
    },
  },
};

function strings(lang) {
  return TEXT[lang] || TEXT.en;
}

function fill(template, args) {
  return template.replace(/\{(\w+)\}/g, (_, k) =>
    args[k] === undefined ? "" : String(args[k]),
  );
}

/** "Metformin, Amlodipine and 1 more" style list, kept short for a notification. */
function medList(names, max = 3) {
  const unique = [...new Set(names.filter(Boolean))];
  if (unique.length <= max) return unique.join(", ");
  return `${unique.slice(0, max).join(", ")} +${unique.length - max}`;
}

/**
 * Builds a notification for one caretaker or patient.
 *
 * @param {string} kind missed | late | taken | skipped | sos | request | battery | love | onit
 * @param {string} lang en | hi | mr
 * @param {object} args name, from, meds, time, reason, level, hasPhoto
 * @return {{title: string, body: string}}
 */
function compose(kind, lang, args) {
  const s = strings(lang);
  const a = {...args};
  switch (kind) {
    case "missed":
      return {title: fill(s.missedTitle, a), body: fill(s.missedBody, a)};
    case "late":
      return {title: fill(s.lateTitle, a), body: fill(s.lateBody, a)};
    case "taken":
      return {title: fill(s.takenTitle, a), body: fill(s.takenBody, a)};
    case "skipped": {
      const reason = a.reason && a.reason !== "unknown" ?
        s.reasons[a.reason] || a.reason :
        null;
      return {
        title: fill(s.skippedTitle, a),
        body: reason ?
          fill(s.skippedBody, {...a, reason}) :
          fill(s.skippedNoReason, a),
      };
    }
    case "sos":
      return {title: fill(s.sosTitle, a), body: fill(s.sosBody, a)};
    case "request": {
      const parts = [a.meds, a.hasPhoto ? s.requestPhoto : ""].filter(Boolean);
      return {title: fill(s.requestTitle, a), body: parts.join(" · ")};
    }
    case "battery":
      return {title: fill(s.batteryTitle, a), body: fill(s.batteryBody, a)};
    case "love":
      return {title: fill(s.loveTitle, a), body: fill(s.loveBody, a)};
    case "onit":
      return {title: fill(s.onitTitle, a), body: fill(s.onitBody, a)};
    default:
      throw new Error(`Unknown notification kind: ${kind}`);
  }
}

module.exports = {compose, medList, fill};
