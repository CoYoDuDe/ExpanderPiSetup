#!/usr/bin/env python3
"""Edit only ExpanderPi's owned boot block; retain other addons verbatim."""
import os
from pathlib import Path
import sys

BEGIN = '# ExpanderPiSetup begin\n'
END = '# ExpanderPiSetup end\n'
OVERLAYS = ('dtoverlay=i2c-rtc,ds1307', 'dtoverlay=mcp3208,spi0-0-present')


def update(text, install):
    lines = text.splitlines(keepends=True)
    starts = [i for i, line in enumerate(lines) if line == BEGIN]
    ends = [i for i, line in enumerate(lines) if line == END]
    if starts or ends:
        if len(starts) != 1 or len(ends) != 1 or starts[0] >= ends[0]:
            raise ValueError('Malformed ExpanderPi boot block; no changes made')
        if install:
            return text
        return ''.join(lines[:starts[0]] + lines[ends[0] + 1:])
    if not install:
        return text  # Never infer ownership from another addon's settings.
    active = {line.strip() for line in lines if not line.lstrip().startswith('#')}
    missing = [line for line in OVERLAYS if line not in active]
    if not missing:
        return text
    section = '[all]'
    for line in lines:
        if line.strip().startswith('[') and line.strip().endswith(']'):
            section = line.strip()
    block = BEGIN + '[all]\n' + '\n'.join(missing) + '\n' + section + '\n' + END
    return text + ('' if not text or text.endswith('\n') else '\n') + block


def main():
    path = Path(sys.argv[2])
    before = path.read_text()
    after = update(before, sys.argv[1] == 'install')
    if before != after:
        # Never truncate the live boot file: a power cut between truncate and write
        # would leave an empty config.txt and an unbootable Pi (vehicle power is not
        # guaranteed). Write the complete result next to it, sync, keep a one-time
        # backup of the original, then swap it in with a single rename (vfat supports
        # rename; the window shrinks from the whole write to one directory update).
        backup = path.with_name(path.name + '.expanderpi-backup')
        tmp = path.with_name(path.name + '.expanderpi-new')
        if not backup.exists():
            with backup.open('w') as stream:
                stream.write(before)
                stream.flush()
                os.fsync(stream.fileno())
        with tmp.open('w') as stream:
            stream.write(after)
            stream.flush()
            os.fsync(stream.fileno())
        if tmp.read_text() != after:
            tmp.unlink()
            raise SystemExit('ExpanderPi boot block verification failed; config.txt unchanged')
        os.replace(tmp, path)
        directory = os.open(str(path.parent), os.O_RDONLY)
        try:
            os.fsync(directory)
        except OSError:
            pass  # some vfat mounts reject directory fsync; the rename itself is done
        finally:
            os.close(directory)
        print('changed')


if __name__ == '__main__':
    main()
