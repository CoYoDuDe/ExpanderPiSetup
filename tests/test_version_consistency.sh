#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version_file="${repo_root}/version"
changes_file="${repo_root}/changes"

if [ ! -f "$version_file" ]; then
    echo "Versionsdatei ${version_file} fehlt." >&2
    exit 1
fi

if [ ! -f "$changes_file" ]; then
    echo "Change-Log-Datei ${changes_file} fehlt." >&2
    exit 1
fi

version_line="$(head -n1 "$version_file" | tr -d '[:space:]')"
if [ -z "$version_line" ]; then
    echo "Versionsdatei ${version_file} enthält keine Versionsnummer in Zeile 1." >&2
    exit 1
fi

changes_line="$(head -n1 "$changes_file" | tr -d '[:space:]')"
if [ -z "$changes_line" ]; then
    echo "Change-Log-Datei ${changes_file} enthält keine Versionsnummer in Zeile 1." >&2
    exit 1
fi

changes_line="${changes_line%:}"

if [ "$version_line" != "$changes_line" ]; then
    echo "Versionskonflikt: version enthält ${version_line}, changes beginnt mit ${changes_line}." >&2
    exit 1
fi

echo "Versionseinträge stimmen überein: ${version_line}"
