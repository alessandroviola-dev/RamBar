#!/usr/bin/env python3
"""Fail-closed binary privacy scan of a bundle or ZIP; never print private paths."""
import os
from pathlib import Path, PurePosixPath
import stat
import sys
import zipfile


class PrivacyError(Exception):
    pass


def scan_bytes(data):
    # Independent of HOME: detect other developers' paths too, including UTF-16.
    markers = [b'/Users/', b'/home/', b'/private/var/folders/', b'/var/folders/']
    home = os.environ.get('HOME', '')
    if home and home != '/':
        markers.append(os.fsencode(home))
    for marker in markers:
        for encoded in (marker, marker.decode(errors='surrogateescape').encode('utf-16-le', errors='surrogatepass'),
                        marker.decode(errors='surrogateescape').encode('utf-16-be', errors='surrogatepass')):
            if encoded in data:
                raise PrivacyError('personal path detected (redacted)')


def scan_bundle(path):
    if path.is_symlink() or not path.is_dir():
        raise PrivacyError('bundle is missing or unsafe')
    count = 0

    def walk(directory):
        nonlocal count
        # scandir raises on unreadable directories, unlike a silent glob failure.
        with os.scandir(directory) as entries:
            for entry in entries:
                scan_bytes(os.fsencode(entry.name))
                mode = entry.stat(follow_symlinks=False).st_mode
                if stat.S_ISDIR(mode):
                    walk(entry.path)
                elif stat.S_ISREG(mode):
                    with open(entry.path, 'rb') as stream:
                        scan_bytes(stream.read())
                    count += 1
                else:
                    raise PrivacyError('symlink or special file in bundle')

    walk(path)
    if not count:
        raise PrivacyError('empty bundle')


def scan_zip(path):
    with zipfile.ZipFile(path) as archive:
        files = 0
        for entry in archive.infolist():
            name = PurePosixPath(entry.filename)
            if (not entry.filename.startswith('RamBar.app/') or '..' in name.parts
                    or '\\' in entry.filename or name.is_absolute()):
                raise PrivacyError('unsafe ZIP entry')
            scan_bytes(entry.filename.encode())
            mode = entry.external_attr >> 16
            if stat.S_ISLNK(mode):
                raise PrivacyError('symlink in ZIP')
            if not entry.is_dir():
                # Full read validates CRC, and cannot suffer producer SIGPIPE.
                scan_bytes(archive.read(entry))
                files += 1
        if not files:
            raise PrivacyError('empty ZIP')


def main(argv):
    if len(argv) != 3 or argv[1] not in ('bundle', 'zip'):
        print('Usage: privacy-scan.py bundle|zip PATH', file=sys.stderr)
        return 2
    try:
        (scan_bundle if argv[1] == 'bundle' else scan_zip)(Path(argv[2]))
    except (PrivacyError, OSError, ValueError, RuntimeError, zipfile.BadZipFile) as error:
        # OSError/ZIP errors can include sensitive names: do not echo them.
        reason = str(error) if isinstance(error, PrivacyError) else type(error).__name__
        print('Privacy scan FAIL: ' + reason, file=sys.stderr)
        return 1
    print('Privacy scan PASS')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
