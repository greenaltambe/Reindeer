"""Shared text normalisation for the Reindeer medicine database and search.

This file is the single source of truth. build_medicine_db.py writes these lists
into the `norm` table of the shipped SQLite file, and the Dart app loads them
from there, so the Python reference search and the app cannot drift apart.
"""
import re

# Salt words: dropped after the first word of an ingredient ("Ambroxol
# Hydrochloride" -> ambroxol). Kept when they are the first word ("Calcium").
SALTS = set('''hydrochloride hcl hydrobromide sulphate sulfate sodium potassium calcium magnesium
maleate tartrate bitartrate phosphate acetate besylate besilate mesylate citrate succinate
fumarate dihydrate anhydrous monohydrate trihydrate hemihydrate nitrate mononitrate dinitrate
bromide chloride carbonate dipropionate propionate valerate disodium trisodium axetil hyclate
medoxomil proxetil pivoxil dipivoxil trometamol tromethamine diethylamine olamine hydrogen
lysinate arginine tosylate napsylate decanoate palmitate stearate gluconate lactate'''.split())

# Form / dose / label words that never identify an ingredient or brand.
FILLER = set('''tablet tablets tab tabs capsule capsules cap caps syrup suspension expectorant
injection injections cream gel drops drop oral solution and with plus mg mcg gm g ml iu w v of
ip bp usp sr xr er dt cr mr sp forte sugar free gastro resistant prolonged release controlled
modified sustained extended chewable dispersible ophthalmic eye ear nasal topical infusion
vial per eq equivalent to respules respule inhalation rotacaps lotion ointment powder sachet
granules liquid spray paste emulsion enema suppositories lozenges soap shampoo for use tabelts
capulses a an the in on or by from i ii iii pack mono carton bottle strip tube'''.split())

# Alternate spellings -> the spelling used in the dataset.
SYN = {
    'guaiphenesin': 'guaifenesin',
    'acetaminophen': 'paracetamol',
    'albuterol': 'salbutamol',
    'levalbuterol': 'levosalbutamol',
    'amoxicillin': 'amoxycillin',
    'rifampin': 'rifampicin',
    'cetirizin': 'cetirizine',
    'sulphate': 'sulfate',
}

_TOKEN = re.compile(r'\d+(?:\.\d+)?|[a-z]+')
_SEGMENT_SPLIT = re.compile(r',|;|\+|&|\band\b|/(?=\s*[a-z])', re.I)
_PARENS = re.compile(r'\([^)]*\)')


def is_numeric(tok):
    return tok[0].isdigit()


def tokens(text):
    """Lowercase tokens; digits and letters are split ('650mg' -> 650, mg)."""
    return _TOKEN.findall(_PARENS.sub(' ', str(text).lower()))


def raw_tokens(text):
    """Like tokens() but keeps parenthesised text (used for strengths)."""
    return _TOKEN.findall(str(text).lower())


def ingredient_words(text):
    """Ingredient words of a composition or generic name, in order, no dups."""
    out = []
    for seg in _SEGMENT_SPLIT.split(_PARENS.sub(' ', str(text))):
        first = True
        for t in _TOKEN.findall(seg.lower()):
            t = SYN.get(t, t)
            if is_numeric(t) or t in FILLER:
                continue
            if t in SALTS and not first:
                continue
            first = False
            if t not in out:
                out.append(t)
    return out


def brand_words(name):
    """Non-numeric, non-filler words of a brand name, in order, no dups."""
    out = []
    for t in tokens(name):
        t = SYN.get(t, t)
        if is_numeric(t) or t in FILLER:
            continue
        if t not in out:
            out.append(t)
    return out


def number_tokens(*texts):
    out = []
    for text in texts:
        for t in raw_tokens(text):
            if is_numeric(t) and t not in out:
                out.append(t)
    return out
