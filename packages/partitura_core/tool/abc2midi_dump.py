#!/usr/bin/env python3
"""Oracle note-dump via abc2midi — the *reference* ABC implementation (James
Allwright / Seymour Shlien), authoritative for ABC where music21 and Verovio
share non-spec conventions (e.g. it carries an accidental to the end of the bar,
per the ABC 2.1 spec).

    python3 tool/abc2midi_dump.py <tune.abc>

Runs `abc2midi` (must be on PATH: `brew install abcmidi`), decodes the MIDI with
`mido`, and emits `{"notes": [[midi, quarterLength], ...]}` like the other
dumpers. Durations are rounded to a 1/24-quarter grid to absorb abc2midi's small
articulation gap; pitch (the accidental question) is exact.
"""
import json
import os
import subprocess
import sys
import tempfile

import mido


def dump(path):
    fd, midpath = tempfile.mkstemp(suffix=".mid")
    os.close(fd)
    try:
        subprocess.run(
            ["abc2midi", path, "-o", midpath],
            capture_output=True,
            check=False,
        )
        mid = mido.MidiFile(midpath)
    finally:
        if os.path.exists(midpath):
            os.unlink(midpath)

    tpq = mid.ticks_per_beat
    notes = []
    for track in mid.tracks:
        t = 0
        active = {}
        for msg in track:
            t += msg.time
            if msg.type == "note_on" and msg.velocity > 0:
                active[(msg.channel, msg.note)] = t
            elif msg.type == "note_off" or (
                msg.type == "note_on" and msg.velocity == 0
            ):
                key = (msg.channel, msg.note)
                if key in active:
                    dur = t - active.pop(key)
                    ql = round(dur / tpq * 24) / 24  # snap to 1/24-quarter grid
                    if ql > 0:
                        notes.append([msg.note, round(ql, 6)])
    notes.sort()
    return notes


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.stderr.write("usage: abc2midi_dump.py <tune.abc>\n")
        sys.exit(64)
    print(json.dumps({"notes": dump(sys.argv[1])}))
