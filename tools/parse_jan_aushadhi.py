"""Extract the Jan Aushadhi (PMBJP) product list PDF into a CSV.

Usage: python3 tools/parse_jan_aushadhi.py "data/Product List.pdf" data/jan_aushadhi.csv

Needs `pdftotext` (poppler). Run once; the CSV is what the app build uses.
Columns: sr, code, name, unit, mrp
"""
import csv
import re
import subprocess
import sys

NUM_LINE = re.compile(r'^\s*(\d+)\s+(\d+)\s*(.*?)\s+([\d.]+)\s*$')


def parse(text):
    text = text.replace('\f', '\n\n')
    records = []
    for block in re.split(r'\n\s*\n', text):
        lines = [l for l in block.split('\n') if l.strip()]
        if not lines or lines[0].strip().startswith('Sr. No'):
            continue
        name_parts, meta = [], None
        for line in lines:
            m = NUM_LINE.match(line)
            if m:
                rest = m.group(3)
                pieces = [p.strip() for p in re.split(r'\s{2,}', rest.strip()) if p.strip()]
                unit = pieces[-1] if pieces else ''
                if len(pieces) > 1:
                    name_parts.append(' '.join(pieces[:-1]))
                meta = (int(m.group(1)), m.group(2), unit, float(m.group(4)))
            else:
                name_parts.append(line.strip())
        if meta is None:
            continue
        name = ' '.join(name_parts)
        name = re.sub(r'-\s+(?=[a-z])', '-', name)
        name = re.sub(r'\s+', ' ', name).strip()
        records.append((meta[0], meta[1], name, meta[2], meta[3]))
    return records


def main(pdf, out):
    text = subprocess.run(['pdftotext', '-layout', pdf, '-'], check=True,
                          capture_output=True, text=True).stdout
    recs = parse(text)
    with open(out, 'w', newline='', encoding='utf-8') as f:
        w = csv.writer(f)
        w.writerow(['sr', 'code', 'name', 'unit', 'mrp'])
        w.writerows(sorted(recs))
    print(f'{len(recs)} records written to {out}')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
