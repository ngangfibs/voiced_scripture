#!/usr/bin/env python3
"""Convert a WEB (World English Bible, public domain) source text into the
seed.json format consumed by BibleSeeder.

Usage:
    python3 tools/build_seed.py path/to/web.txt > assets/bible/web/seed.json

Expected input: one verse per line, e.g. from the WEB public-domain release:
    GEN 1:1 <tab or space> In the beginning, God created ...
Adjust BOOK_CODES to match your source's book identifiers.
"""

import json
import re
import sys

BOOKS = [
    ("Genesis", "Gen", "OT", 50), ("Exodus", "Exod", "OT", 40),
    ("Leviticus", "Lev", "OT", 27), ("Numbers", "Num", "OT", 36),
    ("Deuteronomy", "Deut", "OT", 34), ("Joshua", "Josh", "OT", 24),
    ("Judges", "Judg", "OT", 21), ("Ruth", "Ruth", "OT", 4),
    ("1 Samuel", "1Sam", "OT", 31), ("2 Samuel", "2Sam", "OT", 24),
    ("1 Kings", "1Kgs", "OT", 22), ("2 Kings", "2Kgs", "OT", 25),
    ("1 Chronicles", "1Chr", "OT", 29), ("2 Chronicles", "2Chr", "OT", 36),
    ("Ezra", "Ezra", "OT", 10), ("Nehemiah", "Neh", "OT", 13),
    ("Esther", "Esth", "OT", 10), ("Job", "Job", "OT", 42),
    ("Psalms", "Ps", "OT", 150), ("Proverbs", "Prov", "OT", 31),
    ("Ecclesiastes", "Eccl", "OT", 12), ("Song of Solomon", "Song", "OT", 8),
    ("Isaiah", "Isa", "OT", 66), ("Jeremiah", "Jer", "OT", 52),
    ("Lamentations", "Lam", "OT", 5), ("Ezekiel", "Ezek", "OT", 48),
    ("Daniel", "Dan", "OT", 12), ("Hosea", "Hos", "OT", 14),
    ("Joel", "Joel", "OT", 3), ("Amos", "Amos", "OT", 9),
    ("Obadiah", "Obad", "OT", 1), ("Jonah", "Jonah", "OT", 4),
    ("Micah", "Mic", "OT", 7), ("Nahum", "Nah", "OT", 3),
    ("Habakkuk", "Hab", "OT", 3), ("Zephaniah", "Zeph", "OT", 3),
    ("Haggai", "Hag", "OT", 2), ("Zechariah", "Zech", "OT", 14),
    ("Malachi", "Mal", "OT", 4),
    ("Matthew", "Matt", "NT", 28), ("Mark", "Mark", "NT", 16),
    ("Luke", "Luke", "NT", 24), ("John", "John", "NT", 21),
    ("Acts", "Acts", "NT", 28), ("Romans", "Rom", "NT", 16),
    ("1 Corinthians", "1Cor", "NT", 16), ("2 Corinthians", "2Cor", "NT", 13),
    ("Galatians", "Gal", "NT", 6), ("Ephesians", "Eph", "NT", 6),
    ("Philippians", "Phil", "NT", 4), ("Colossians", "Col", "NT", 4),
    ("1 Thessalonians", "1Thess", "NT", 5),
    ("2 Thessalonians", "2Thess", "NT", 3), ("1 Timothy", "1Tim", "NT", 6),
    ("2 Timothy", "2Tim", "NT", 4), ("Titus", "Titus", "NT", 3),
    ("Philemon", "Phlm", "NT", 1), ("Hebrews", "Heb", "NT", 13),
    ("James", "Jas", "NT", 5), ("1 Peter", "1Pet", "NT", 5),
    ("2 Peter", "2Pet", "NT", 3), ("1 John", "1John", "NT", 5),
    ("2 John", "2John", "NT", 1), ("3 John", "3John", "NT", 1),
    ("Jude", "Jude", "NT", 1), ("Revelation", "Rev", "NT", 22),
]

# Map common source codes to 1-based book ids. Extend for your source.
BOOK_CODES = {
    "GEN": 1, "EXO": 2, "LEV": 3, "NUM": 4, "DEU": 5, "JOS": 6, "JDG": 7,
    "RUT": 8, "1SA": 9, "2SA": 10, "1KI": 11, "2KI": 12, "1CH": 13,
    "2CH": 14, "EZR": 15, "NEH": 16, "EST": 17, "JOB": 18, "PSA": 19,
    "PRO": 20, "ECC": 21, "SNG": 22, "ISA": 23, "JER": 24, "LAM": 25,
    "EZK": 26, "DAN": 27, "HOS": 28, "JOL": 29, "AMO": 30, "OBA": 31,
    "JON": 32, "MIC": 33, "NAM": 34, "HAB": 35, "ZEP": 36, "HAG": 37,
    "ZEC": 38, "MAL": 39, "MAT": 40, "MRK": 41, "LUK": 42, "JHN": 43,
    "ACT": 44, "ROM": 45, "1CO": 46, "2CO": 47, "GAL": 48, "EPH": 49,
    "PHP": 50, "COL": 51, "1TH": 52, "2TH": 53, "1TI": 54, "2TI": 55,
    "TIT": 56, "PHM": 57, "HEB": 58, "JAS": 59, "1PE": 60, "2PE": 61,
    "1JN": 62, "2JN": 63, "3JN": 64, "JUD": 65, "REV": 66,
}

LINE_RE = re.compile(r"^([A-Z0-9]{3})\s+(\d+):(\d+)\s+(.+)$")


def main(path: str) -> None:
    verses = []
    vid = 1
    with open(path, encoding="utf-8") as f:
        for line in f:
            m = LINE_RE.match(line.strip())
            if not m:
                continue
            code, chapter, verse, text = m.groups()
            book_id = BOOK_CODES.get(code)
            if book_id is None:
                continue
            verses.append({
                "id": vid,
                "book_id": book_id,
                "chapter": int(chapter),
                "verse": int(verse),
                "text": text.strip(),
            })
            vid += 1

    books = [
        {
            "id": i + 1,
            "testament": t,
            "name": n,
            "abbrev": a,
            "book_order": i + 1,
            "chapter_count": c,
        }
        for i, (n, a, t, c) in enumerate(BOOKS)
    ]
    json.dump({"books": books, "verses": verses}, sys.stdout,
              ensure_ascii=False, indent=1)
    print(f"\n# {len(verses)} verses", file=sys.stderr)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
