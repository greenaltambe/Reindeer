"""Build the offline medicine database shipped with the Reindeer app.

Usage (from the project root):
    python3 tools/build_medicine_db.py

Inputs (in data/, not committed because of size and licence):
    Extensive_A_Z_medicines_dataset_of_India.csv   brand medicines (primary)
    jan_aushadhi.csv                               generics (tools/parse_jan_aushadhi.py)
Output:
    assets/db/medicines.db

Standard library only.
"""
import csv
import gzip
import os
import re
import shutil
import sqlite3
import sys
import tempfile
import time

sys.path.insert(0, os.path.dirname(__file__))
import medicine_norm as N  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, 'data')
OUT = os.path.join(ROOT, 'assets', 'db', 'medicines.db')
OUT_GZ = OUT + '.gz'  # the file the app bundles
DB_VERSION = 2

FORMS = [
    ('injection', r'injection|infusion|vial|ampoule|cartridge|pen\b|prefilled'),
    ('inhaler', r'inhaler|inhalation|rotacap|respule|nebuli'),
    ('drops', r'drops?\b|eye|ear\b|nasal'),
    ('capsule', r'capsule|capulse|softgel'),
    ('tablet', r'tablet|tabelt|\btab\b|lozenge|chewable|strip of'),
    ('liquid', r'syrup|suspension|solution|expectorant|liquid|elixir|emulsion|linctus|sachet of \d+ ml'),
    ('topical', r'cream|gel\b|ointment|lotion|spray|soap|shampoo|paste|oil\b|mouthwash|gargle|powder for'),
    ('powder', r'powder|granules|sachet'),
]


def derive_form(*texts):
    blob = ' '.join(t for t in texts if t).lower()
    for form, pat in FORMS:
        if re.search(pat, blob):
            return form
    return 'other'


def first_number(text):
    m = re.search(r'\d+(?:\.\d+)?', text or '')
    return float(m.group(0)) if m else None


def clean(s):
    return re.sub(r'\s+', ' ', str(s or '')).strip()


def strength_count(name):
    m = re.search(r'(\d[\d.]*\s*(?:mg|mcg|iu|g|ml|%)?(?:\s*/\s*\d[\d.]*\s*(?:mg|mcg|iu|g|ml|%)?)+)', name, re.I)
    return len(re.split(r'/', m.group(1))) if m else 0


def title_use(u):
    """Normalise a "used for" phrase into a condition name.

    "Treatment of Hypertension (high blood pressure)" -> "Hypertension (high blood pressure)"
    "Prevention of Migraine" -> "Migraine (prevention)"
    """
    u = clean(u)
    if not u or '$name' in u or len(u) > 90:
        return ''  # empty, or a description that leaked into the field
    m = re.match(r'(?i)^(?:treatment|management|control|relief) of\s+(.+)$', u)
    if m:
        u = m.group(1)
    else:
        m = re.match(r'(?i)^prevention of\s+(.+)$', u)
        if m:
            u = m.group(1) + ' (prevention)'
        else:
            u = re.sub(r'(?i)^controlling\s+', '', u)
    u = clean(u)
    return u[:1].upper() + u[1:]


# Everyday words people use for a condition -> substring of the condition name.
CONDITION_ALIASES = {
    'hypertension': 'bp, blood pressure, high bp, high blood pressure',
    'type 2 diabetes': 'sugar, diabetes, diabetic, high sugar',
    'type 1 diabetes': 'sugar, diabetes, diabetic',
    'cholesterol': 'lipids, high cholesterol, cholesterol',
    'hypothyroidism': 'thyroid, low thyroid',
    'hyperthyroidism': 'thyroid, high thyroid',
    'gastroesophageal reflux': 'acidity, acid reflux, gerd, heartburn',
    'heartburn': 'acidity, acid',
    'peptic ulcer': 'acidity, stomach ulcer, ulcer',
    'fever': 'temperature, viral fever',
    'common cold': 'cold, running nose, flu',
    'cough': 'khansi, dry cough, wet cough',
    'asthma': 'breathing, wheezing',
    'migraine': 'headache',
    'pain': 'dard, body ache, ache',
    'allerg': 'allergy',
    'anxiety': 'stress, tension',
    'depression': 'low mood, sad',
    'insomnia': 'sleep, sleeplessness',
    'constipation': 'stomach, motion',
    'diarrhoea': 'loose motion, stomach',
    'diarrhea': 'loose motion, stomach',
    'anaemia': 'anemia, iron, low hemoglobin, weakness',
    'nutritional deficienc': 'vitamin, weakness, supplement',
    'arthritis': 'joint pain, joints',
    'urinary tract': 'uti, urine infection',
    'bacterial infection': 'infection, antibiotic',
    'fungal': 'infection, ringworm, fungus',
    'epilepsy': 'fits, seizure',
}


def aliases_for(name):
    low = name.lower()
    # "Ocular hypertension" is not what someone means by "bp".
    if low.startswith(('ocular', 'pulmonary', 'portal', 'intracranial', 'intraocular')):
        return ''
    out = []
    for key, al in CONDITION_ALIASES.items():
        if (low.startswith(key) or low.endswith(key)) and low != 'hay fever':
            out += [a.strip() for a in al.split(',') if a.strip() not in out]
    return ', '.join(dict.fromkeys(out))


def load_brands():
    path = os.path.join(DATA, 'Extensive_A_Z_medicines_dataset_of_India.csv')
    seen, rows = {}, []
    with open(path, newline='', encoding='utf-8') as f:
        for r in csv.DictReader(f):
            name = clean(r['name'])
            mfr = clean(r['manufacturer_name'])
            key = (name.lower(), mfr.lower())
            disc = 1 if r['Is_discontinued'].strip().upper() == 'TRUE' else 0
            if key in seen:
                if not disc and rows[seen[key]]['disc']:
                    rows[seen[key]]['disc'] = 0
                continue
            c1, c2 = clean(r['short_composition1']), clean(r['short_composition2'])
            comps = [c for c in (c1, c2) if c]
            ing = []
            for c in comps:
                for w in N.ingredient_words(c):
                    if w not in ing:
                        ing.append(w)
            bw = N.brand_words(name)
            nc = len(comps)
            rows.append(dict(
                name=name, mfr=mfr, pack=clean(r['pack_size_label']),
                pack_qty=first_number(r['pack_size_label']),
                comp=' + '.join(comps),
                form=derive_form(name, r['pack_size_label']),
                ing=sorted(ing), bw=bw, disc=disc, src=0,
                inc=1 if strength_count(name) > nc else 0,
                use=title_use(r.get('use0')), cls=clean(r.get('Therapeutic Class')).title(),
                uses=list(dict.fromkeys(
                    u for u in (title_use(r.get(f'use{k}')) for k in range(5)) if u)),
                nums=N.number_tokens(name, c1, c2),
            ))
            seen[key] = len(rows) - 1
    return rows


def load_generics(ing_vocab):
    path = os.path.join(DATA, 'jan_aushadhi.csv')
    if not os.path.exists(path):
        print('  (no jan_aushadhi.csv, skipping generics)')
        return []
    skip = re.compile(r'janaushadhi|janushadhi|sling|cotton|bandage|gauze|tube\b|mask|glove|syringe|bar\b|catheter|plaster|cap\b.*size', re.I)
    rows = []
    for r in csv.DictReader(open(path, newline='', encoding='utf-8')):
        name = clean(r['name'])
        if skip.search(name):
            continue
        ing = N.ingredient_words(name)
        if not any(w in ing_vocab for w in ing):
            continue
        rows.append(dict(
            name=name, mfr='Jan Aushadhi (PMBJP)', pack=clean(r['unit']),
            pack_qty=first_number(r['unit']), comp='',
            form=derive_form(name, r['unit']),
            ing=sorted(ing), bw=[], disc=0, src=1, inc=0, use='', cls='', uses=[],
            nums=N.number_tokens(name),
        ))
    return rows


SCHEMA = '''
CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT);
CREATE TABLE norm(kind TEXT, word TEXT, canon TEXT);
CREATE TABLE medicine(
  id INTEGER PRIMARY KEY, name TEXT, mfr TEXT, pack TEXT, pack_qty REAL, comp TEXT,
  form TEXT, ing TEXT, ingn INTEGER, bw TEXT, bwn INTEGER, nums TEXT,
  disc INTEGER, src INTEGER, inc INTEGER, use TEXT, cls TEXT, uses TEXT);
CREATE TABLE condition(name TEXT PRIMARY KEY, freq INTEGER, aliases TEXT) WITHOUT ROWID;
CREATE TABLE word_index(word TEXT NOT NULL, id INTEGER NOT NULL, PRIMARY KEY(word, id)) WITHOUT ROWID;
CREATE TABLE vocab(word TEXT PRIMARY KEY, kind INTEGER, freq INTEGER) WITHOUT ROWID;
CREATE INDEX medicine_ing ON medicine(ing);
'''


def main():
    t0 = time.time()
    print('loading brands...')
    brands = load_brands()
    ing_vocab = {w for r in brands for w in r['ing']}
    print(f'  {len(brands)} brand rows, {len(ing_vocab)} ingredient words')
    generics = load_generics(ing_vocab)
    print(f'  {len(generics)} generic rows')
    rows = brands + generics

    # Build in the system temp dir (SQLite can fail on synced/mounted folders), then copy.
    build_path = os.path.join(tempfile.gettempdir(), 'reindeer_medicines_build.db')
    if os.path.exists(build_path):
        os.remove(build_path)
    db = sqlite3.connect(build_path)
    db.executescript(SCHEMA)
    db.executemany('INSERT INTO meta VALUES(?,?)', [
        ('version', str(DB_VERSION)),
        ('built_at', time.strftime('%Y-%m-%d')),
        ('sources', 'Extensive A-Z Medicines Dataset of India (community, provenance unverified); '
                    'Jan Aushadhi (PMBJP) product list'),
        ('rows', str(len(rows))),
    ])
    norm = [('salt', w, '') for w in sorted(N.SALTS)] + \
           [('filler', w, '') for w in sorted(N.FILLER)] + \
           [('syn', k, v) for k, v in sorted(N.SYN.items())]
    db.executemany('INSERT INTO norm VALUES(?,?,?)', norm)

    vocab = {}
    med_rows, idx_rows = [], []
    for i, r in enumerate(rows, start=1):
        med_rows.append((
            i, r['name'], r['mfr'], r['pack'], r['pack_qty'], r['comp'], r['form'],
            ' '.join(r['ing']), len(r['ing']), ' '.join(r['bw']), len(r['bw']),
            ' ' + ' '.join(r['nums']) + ' ' if r['nums'] else ' ',
            r['disc'], r['src'], r['inc'], r['use'], r['cls'], '|'.join(r['uses'])))
        for w in r['ing']:
            idx_rows.append((w, i))
            v = vocab.setdefault(w, [0, 0])
            v[0] |= 1
            v[1] += 1
        for w in r['bw']:
            if w in r['ing']:
                continue
            idx_rows.append((w, i))
            v = vocab.setdefault(w, [0, 0])
            v[0] |= 2
            v[1] += 1
    db.executemany('INSERT INTO medicine VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)', med_rows)
    cond_freq = {}
    for r in rows:
        for u in r['uses']:
            cond_freq[u] = cond_freq.get(u, 0) + 1
    # Case-insensitive de-duplication, keeping the most common spelling.
    best = {}
    for name, f in cond_freq.items():
        k = name.lower()
        if k not in best or f > best[k][1]:
            best[k] = (name, f)
    db.executemany('INSERT INTO condition VALUES(?,?,?)',
                   [(n, f, aliases_for(n)) for n, f in best.values()])
    print(f'  {len(best)} conditions')
    db.executemany('INSERT OR IGNORE INTO word_index VALUES(?,?)', idx_rows)
    db.executemany('INSERT INTO vocab VALUES(?,?,?)', [(w, k, f) for w, (k, f) in vocab.items()])
    db.commit()
    db.execute('VACUUM')
    db.close()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    shutil.copyfile(build_path, OUT)
    gz_tmp = build_path + '.gz'
    with open(build_path, 'rb') as src, gzip.open(gz_tmp, 'wb', compresslevel=9) as dst:
        shutil.copyfileobj(src, dst)
    shutil.copyfile(gz_tmp, OUT_GZ)
    os.remove(gz_tmp)
    os.remove(build_path)
    print(f'wrote {OUT_GZ}: {os.path.getsize(OUT_GZ) / 1e6:.1f} MB')
    mb = os.path.getsize(OUT) / 1e6
    print(f'wrote {OUT}: {mb:.1f} MB, {len(vocab)} vocab words, {len(idx_rows)} index rows, {time.time()-t0:.0f}s')


if __name__ == '__main__':
    main()
