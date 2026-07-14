#!/usr/bin/env python3
"""Oracle note-dump via Verovio (RISM Digital) — a stronger independent parser
than music21 for differential testing.

    python3 tool/verovio_dump.py <score-file>

Verovio is the *reference* MEI engine, embeds **humlib** (authoritative Humdrum
`**kern`), and parses ABC (broken rhythm, key signatures) and MusicXML — it is
stronger than music21 on every format we test. It emits the same
`{"notes": [[midi, quarterLength], ...]}` shape as `oracle_dump.py`, so
`oracle_diff.dart --oracle verovio` can compare partitura against it.

Durations come from the **timemap** (`qstamp`, exact musical quarter-note time),
not MIDI — so there is no articulation gap. Pitch comes from
`getMIDIValuesForElement` (MIDI number: drops enharmonic spelling but keeps
height, exactly what the oracle compares). Grace notes (zero duration) drop.
"""
import json
import sys

import verovio


def dump(path):
    tk = verovio.toolkit()
    if not tk.loadFile(path):
        raise RuntimeError("verovio could not load the file")
    timemap = tk.renderToTimemap({"includeMeasures": False})
    if isinstance(timemap, str):
        timemap = json.loads(timemap)

    onset = {}  # note id -> qstamp it starts
    spans = []  # (id, on_qstamp, off_qstamp)
    for entry in timemap:
        q = entry.get("qstamp", 0)
        for nid in entry.get("on", []):
            onset[nid] = q
        for nid in entry.get("off", []):
            if nid in onset:
                spans.append((nid, onset.pop(nid), q))

    notes = []
    for nid, on, off in spans:
        ql = round(off - on, 6)
        if ql <= 0:
            continue  # grace / zero-length
        midi = tk.getMIDIValuesForElement(nid).get("pitch")
        if midi:
            notes.append([int(midi), ql])
    notes.sort()
    return notes


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.stderr.write("usage: verovio_dump.py <score-file>\n")
        sys.exit(64)
    print(json.dumps({"notes": dump(sys.argv[1])}))
