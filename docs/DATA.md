# Medicine data

## Sources

- **A-Z medicines dataset of India** (community dataset, `Extensive_A_Z_...csv`): brand
  names, compositions, pack sizes, "used for" text. Provenance and licence are
  unverified, so treat it as demo data.
- **Jan Aushadhi product list** (public PDF, parsed to `data/jan_aushadhi.csv` by
  `tools/parse_jan_aushadhi.py`): generic medicines.

Only `jan_aushadhi.csv` is committed. Put the community CSV in `data/` yourself; the other
files in `data/` are ignored by git.

## Building the database

```bash
python3 tools/build_medicine_db.py
```

It cleans and normalises names, builds an ingredient word index and a conditions table,
then writes `assets/db/medicines.db` and `assets/db/medicines.db.gz`. The conditions come
from the "used for" fields ("Treatment of X" becomes X, "Prevention of X" becomes
"X (prevention)"), with junk filtered out and everyday aliases added.

If you change the data or the schema, bump `DB_VERSION` in the script **and**
`bundledVersion` in `lib/core/database/medicine_database.dart`, so installed apps unpack
the new file.

## Search method

- Normalise words: lowercase, drop salt and form words, map known spellings
  (`acetaminophen` to `paracetamol`).
- Word order does not matter; a query matches rows containing all its words.
- Spell-correct each word against the vocabulary (edit distance 1, or 2 for ingredient
  words). Numbers such as 625 vs 650 are never corrected.
- If nothing contains every word, fall back to rows matching the most words.

Measured on 1,000 synthetic noisy queries (60% of words misspelled): ingredient names
99.6% top-1, brand names 79.5% top-1 (86.1% top-3).

`python3 tools/search_reference.py` runs the reference benchmark. The Dart port is
checked against it by `test/search_parity_test.dart` (needs `assets/db/medicines.db`).

## Known limits

- Only two compositions are kept per product, so some combination products look
  incomplete (the app warns about this).
- No barcode data exists in the datasets, so the scanner learns links as you use it.
