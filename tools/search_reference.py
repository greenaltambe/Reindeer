"""Reference implementation of Reindeer medicine search, run against medicines.db.

The Dart implementation (lib/features/medicine_database) mirrors this file step
for step and uses the same SQL, so results should match. Run:

    python3 tools/search_reference.py benchmark     # accuracy on synthetic noisy queries
    python3 tools/search_reference.py "ambroxal hydrochoride, guaiphenesin"
    python3 tools/search_reference.py vectors       # write test/fixtures/search_cases.json

Standard library only.
"""
import json
import os
import random
import re
import sqlite3
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
import medicine_norm as N  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB_PATH = os.path.join(ROOT, 'assets', 'db', 'medicines.db')
LIMIT = 30
PREFIX_EXPANSIONS = 12
ING, BRAND = 1, 2


def osa_within(a, b, k):
    """Optimal-string-alignment distance <= k."""
    if abs(len(a) - len(b)) > k:
        return False
    prev2, prev = None, list(range(len(b) + 1))
    for i in range(1, len(a) + 1):
        cur = [i] + [0] * len(b)
        for j in range(1, len(b) + 1):
            c = 0 if a[i - 1] == b[j - 1] else 1
            cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + c)
            if prev2 is not None and i > 1 and j > 1 and a[i - 1] == b[j - 2] and a[i - 2] == b[j - 1]:
                cur[j] = min(cur[j], prev2[j - 2] + 1)
        prev2, prev = prev, cur
    return prev[-1] <= k


def edits1(w):
    letters = 'abcdefghijklmnopqrstuvwxyz'
    sp = [(w[:i], w[i:]) for i in range(len(w) + 1)]
    out = {a + b[1:] for a, b in sp if b}
    out |= {a + b[1] + b[0] + b[2:] for a, b in sp if len(b) > 1}
    out |= {a + c + b[1:] for a, b in sp if b for c in letters}
    out |= {a + c + b for a, b in sp for c in letters}
    out.discard(w)
    return out


class Search:
    def __init__(self, path=DB_PATH):
        self.db = sqlite3.connect(path)
        self.vocab = {w: (k, f) for w, k, f in self.db.execute('SELECT word, kind, freq FROM vocab')}
        self.ing_words = [w for w, (k, _) in self.vocab.items() if k & ING]
        norm = self.db.execute('SELECT kind, word, canon FROM norm').fetchall()
        self.salts = {w for k, w, _ in norm if k == 'salt'}
        self.fillers = {w for k, w, _ in norm if k == 'filler'}
        self.syn = {w: c for k, w, c in norm if k == 'syn'}

    # --- query normalisation -------------------------------------------------
    def parse(self, query):
        """Return (required_words, numbers). Required words keep query order."""
        words, numbers = [], []
        for seg in N._SEGMENT_SPLIT.split(N._PARENS.sub(' ', query)):
            first = True
            for t in N._TOKEN.findall(seg.lower()):
                t = self.syn.get(t, t)
                if N.is_numeric(t):
                    if t not in numbers:
                        numbers.append(t)
                    continue
                if t in self.fillers:
                    continue
                if t in self.salts and not first:
                    continue
                first = False
                words.append(t)
        return words, numbers

    # --- per-word candidates ---------------------------------------------------
    def correct(self, w):
        if w in self.vocab:
            return w
        hits = [c for c in edits1(w) if c in self.vocab]
        if not hits and len(w) >= 6:
            hits = [c for c in self.ing_words if osa_within(w, c, 2)]
        if not hits:
            return None
        return max(hits, key=lambda c: (self.vocab[c][0] & ING, self.vocab[c][1], c))

    def prefix_words(self, p):
        rows = self.db.execute(
            'SELECT word FROM vocab WHERE word >= ? AND word < ? ORDER BY freq DESC, word LIMIT ?',
            (p, p + '￿', PREFIX_EXPANSIONS)).fetchall()
        return [r[0] for r in rows]

    def candidates(self, words, as_you_type):
        """List of candidate-word lists, one per query word that survives."""
        out = []
        for i, w in enumerate(words):
            last = i == len(words) - 1
            cands = []
            if last and as_you_type and len(w) >= 2:
                cands = self.prefix_words(w)
                if w in self.vocab and w not in cands:
                    cands.insert(0, w)
            if not cands:
                c = self.correct(w)
                cands = [c] if c else []
            if cands:
                out.append(cands)
        return out

    # --- retrieval ---------------------------------------------------------------
    def search(self, query, as_you_type=False, limit=LIMIT):
        words, numbers = self.parse(query)
        if not words:
            return []
        cand = self.candidates(words, as_you_type)
        if not cand:
            return []
        # drop duplicate single-candidate words (same word twice)
        seen, uniq = set(), []
        for c in cand:
            k = tuple(c)
            if k not in seen:
                seen.add(k)
                uniq.append(c)
        cand = uniq
        single = all(len(c) == 1 for c in cand)
        # Ingredient mode: every word can only be an ingredient (no brand reading).
        ingredient_mode = all(all(self.vocab[w][0] & ING for w in c) for c in cand)
        key = ' '.join(sorted({c[0] for c in cand})) if single else None

        bonus = ' + '.join(['(instr(m.nums, ?) > 0)'] * len(numbers)) or '0.0'
        bonus_args = [f' {n} ' for n in numbers]
        if ingredient_mode:
            order = (f'(m.ing = ?) DESC, m.ingn ASC, ({bonus}) DESC, m.disc ASC, m.src DESC, '
                     f'length(m.name) ASC, m.id ASC')
            order_args = [key or '\x00'] + bonus_args
        else:
            order = (f'((\' \' || m.bw) LIKE ?) DESC, ({bonus}) DESC, m.src ASC, m.bwn ASC, m.disc ASC, '
                     f'length(m.name) ASC, m.id ASC')
            order_args = [f'% {words[-1]}%'] + bonus_args

        # Smallest candidate group drives the lookup; the rest are EXISTS checks.
        groups = sorted(cand, key=lambda c: sum(self.vocab[w][1] for w in c))
        conds, args = [], []
        for n, c in enumerate(groups):
            ph = ','.join('?' * len(c))
            if n == 0:
                conds.append(f'm.id IN (SELECT id FROM word_index WHERE word IN ({ph}))')
            else:
                conds.append(f'EXISTS (SELECT 1 FROM word_index x WHERE x.id = m.id AND x.word IN ({ph}))')
            args += c
        sql = ('SELECT m.id, m.name FROM medicine m WHERE ' + ' AND '.join(conds) +
               f' ORDER BY {order} LIMIT ?')
        rows = self.db.execute(sql, args + order_args + [limit]).fetchall()
        if rows or len(cand) == 1:
            return rows
        # relax: rank by how many query words matched
        flat = [w for c in cand for w in c]
        ph = ','.join('?' * len(flat))
        sql = (f'SELECT m.id, m.name FROM medicine m JOIN '
               f'(SELECT id, COUNT(DISTINCT word) c FROM word_index WHERE word IN ({ph}) GROUP BY id) t '
               f'ON t.id = m.id ORDER BY t.c DESC, m.ingn ASC, m.disc ASC, m.src DESC, m.id ASC LIMIT ?')
        return self.db.execute(sql, flat + [limit]).fetchall()


def typo(w, rng):
    if len(w) < 5:
        return w
    kind = rng.choice(['sub', 'del', 'swap', 'ins'])
    i = rng.randrange(1, len(w) - 1)
    if kind == 'sub':
        return w[:i] + rng.choice('abcdefghijklmnoprstuv') + w[i + 1:]
    if kind == 'del':
        return w[:i] + w[i + 1:]
    if kind == 'swap':
        return w[:i] + w[i + 1] + w[i] + w[i + 2:]
    return w[:i] + w[i] + w[i:]


def benchmark(n=1000):
    s = Search()
    rng = random.Random(7)
    db = s.db
    ids = [r[0] for r in db.execute('SELECT id FROM medicine WHERE src = 0 AND ing != ""')]
    sample = rng.sample(ids, n)
    stats = {'ingredient': [0, 0, 0], 'brand': [0, 0, 0]}
    times = []
    for kind in stats:
        for i in sample:
            name, ing, bw = db.execute('SELECT name, ing, bw FROM medicine WHERE id = ?', (i,)).fetchone()
            if kind == 'ingredient':
                parts = ing.split()
                rng.shuffle(parts)
                parts = [typo(w, rng) if rng.random() < 0.6 else w for w in parts]
                if rng.random() < 0.5:
                    parts.append(rng.choice(['syrup', 'tablet', 'hydrochloride', 'sulphate']))
                q = ' '.join(parts)
                ok = lambda j: db.execute('SELECT ing FROM medicine WHERE id=?', (j,)).fetchone()[0] == ing
            else:
                parts = [t for t in N.tokens(name) if t not in s.fillers]
                if not bw:
                    continue
                q = ' '.join(typo(w, rng) if rng.random() < 0.6 and not N.is_numeric(w) else w
                             for w in parts)
                ok = lambda j: db.execute('SELECT name FROM medicine WHERE id=?', (j,)).fetchone()[0].lower() == name.lower()
            t0 = time.time()
            res = s.search(q)
            times.append(time.time() - t0)
            stats[kind][2] += 1
            if res and ok(res[0][0]):
                stats[kind][0] += 1
            if any(ok(r[0]) for r in res[:3]):
                stats[kind][1] += 1
    for kind, (t1, t3, tot) in stats.items():
        print(f'{kind:10s} top1={t1/tot:.1%} top3={t3/tot:.1%} (n={tot})')
    times.sort()
    print(f'query time: median {times[len(times)//2]*1000:.0f} ms, p95 {times[int(len(times)*.95)]*1000:.0f} ms')


CASES = [
    ('dolo 650', False), ('dolo', True), ('dol', True), ('paracetamol', False),
    ('Levosalbutanol sulphate, Ambroxal hydrochoride and guaiphenesin exeectorant', False),
    ('Ambroxol Hydrochloride 15 mg, Guaifenesin 50 mg and Levosalbutamol Sulphate 1 mg Syrup', False),
    ('amoxicillin clavulanate', False), ('augmentin 625', False), ('azithral', False),
    ('metformin glimepiride', False), ('pantop', True), ('pantoprazole', False),
    ('cetirizine', False), ('ascoril ls', False), ('acetaminophen 500', False),
    ('calcium', False), ('vitamin d3', False), ('crocin', False), ('combiflam', False),
    ('telmisartan amlodipine', False), ('ecosprin', False), ('thyronorm', True),
    ('atorvastatin', False), ('amoxycilin', False), ('glycomet gp', False),
    ('ofloxacin ornidazole', False), ('zzzzqq', False),
]


def write_vectors():
    s = Search()
    out = []
    for q, ayt in CASES:
        res = s.search(q, as_you_type=ayt, limit=5)
        out.append({'query': q, 'asYouType': ayt, 'top': [[r[0], r[1]] for r in res]})
    path = os.path.join(ROOT, 'test', 'fixtures', 'search_cases.json')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    json.dump(out, open(path, 'w', encoding='utf-8'), indent=1, ensure_ascii=False)
    print('wrote', path)
    for c in out:
        print(f"{c['query'][:60]!r:64} -> {[t[1] for t in c['top'][:2]]}")


if __name__ == '__main__':
    arg = sys.argv[1] if len(sys.argv) > 1 else 'benchmark'
    if arg == 'benchmark':
        benchmark()
    elif arg == 'vectors':
        write_vectors()
    else:
        t0 = time.time()
        for r in Search().search(arg, as_you_type=True, limit=8):
            print(r)
        print(f'{(time.time()-t0)*1000:.0f} ms')
