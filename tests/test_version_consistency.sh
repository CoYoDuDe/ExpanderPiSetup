#!/bin/bash
set -euo pipefail

check_version_consistency() {
    local root="$1"
    local context="$2"
    local version_file="${root}/version"
    local changes_file="${root}/changes"

    if [ ! -f "$version_file" ]; then
        echo "Versionsdatei ${version_file} fehlt." >&2
        exit 1
    fi

    if [ ! -f "$changes_file" ]; then
        echo "Change-Log-Datei ${changes_file} fehlt." >&2
        exit 1
    fi

    local version_line
    version_line="$(head -n1 "$version_file" | tr -d '[:space:]')"
    if [ -z "$version_line" ]; then
        echo "Versionsdatei ${version_file} enthält keine Versionsnummer in Zeile 1." >&2
        exit 1
    fi

    local changes_line
    changes_line="$(head -n1 "$changes_file" | tr -d '[:space:]')"
    if [ -z "$changes_line" ]; then
        echo "Change-Log-Datei ${changes_file} enthält keine Versionsnummer in Zeile 1." >&2
        exit 1
    fi

    # Die erste Überschrift im Change-Log darf wahlweise "Unveröffentlicht" (mit oder ohne Doppelpunkt)
    # oder die konkret veröffentlichte Version enthalten. Zusätzlich muss die erste konkrete
    # Versionsüberschrift (also der erste nicht "Unveröffentlicht"-Abschnitt) exakt mit dem Eintrag in
    # der Versionsdatei übereinstimmen, damit veröffentlichte Stände weiterhin validiert werden.
    local changes_headline
    changes_headline="${changes_line%:}"

    if [ "$changes_headline" != "Unveröffentlicht" ] && [ "$changes_headline" != "$version_line" ]; then
        echo "Versionskonflikt: version enthält ${version_line}, changes beginnt mit ${changes_headline}." >&2
        exit 1
    fi

    local first_concrete_version
    first_concrete_version="$(awk '
        function rtrim(str) {
            sub(/[[:space:]]+$/, "", str);
            return str;
        }

        /^[[:space:]]*$/ {next}
        /^[[:space:]]*-/ {next}

        {
            line = rtrim($0);
            if (line == "Unveröffentlicht" || line == "Unveröffentlicht:") {
                next;
            }

            sub(/:$/, "", line);
            print line;
            exit;
        }
    ' "$changes_file")"

    if [ -n "$first_concrete_version" ] && [ "$first_concrete_version" != "$version_line" ]; then
        echo "Versionskonflikt: version enthält ${version_line}, erster Versionsabschnitt in changes ist ${first_concrete_version}." >&2
        exit 1
    fi

    echo "Versionseinträge stimmen überein (${context}): ${version_line}"
}

run_unreleased_positive_test() {
    local temp_dir
    temp_dir="$(mktemp -d)"
    trap 'rm -rf "${temp_dir}"' EXIT

    cat >"${temp_dir}/version" <<'POSITIVE_VERSION'
v1.2.3
POSITIVE_VERSION

    cat >"${temp_dir}/changes" <<'POSITIVE_CHANGES'
Unveröffentlicht:
- Noch unveröffentlichte Änderungen.

v1.2.3:
- Release-Notizen für den veröffentlichten Stand.
POSITIVE_CHANGES

    check_version_consistency "$temp_dir" "Positivtest Unveröffentlicht"

    rm -rf "${temp_dir}"
    trap - EXIT
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

check_version_consistency "$repo_root" "Repository"
run_unreleased_positive_test
