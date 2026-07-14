#!/usr/bin/env python3
"""Oracle note-dump via music21 — an independent parser for differential testing.

    python3 tool/oracle_dump.py <score-file>

Emits, on stdout, a JSON object {"notes": [[midi, quarterLength], ...]} listing
every sounding note across *all* parts (chords expanded to one entry per pitch,
grace notes — quarterLength 0 — dropped), sorted. `tool/oracle_diff.dart` parses
the same file with crisp_notation and compares its note multiset against this one:
a mismatch is far more likely a crisp_notation import bug than a music21 one, and
points at exactly which (pitch, duration) it got wrong.

music21 is the trusted oracle here only because it is mature and widely used —
not infallible. A confirmed divergence gets investigated, not blindly assigned.
"""
import json
import sys

from music21 import converter


def dump(path):
    score = converter.parse(path)
    notes = []
    for n in score.recurse().notes:  # Note and Chord objects, all parts
        ql = float(n.quarterLength)
        if ql == 0:  # grace note — crisp_notation folds these into the main note
            continue
        for p in n.pitches:
            notes.append([int(p.midi), round(ql, 6)])
    notes.sort()
    return notes


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.stderr.write("usage: oracle_dump.py <score-file>\n")
        sys.exit(64)
    print(json.dumps({"notes": dump(sys.argv[1])}))
