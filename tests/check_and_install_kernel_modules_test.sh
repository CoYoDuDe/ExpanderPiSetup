#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SETUP_FILE="${REPO_ROOT}/setup"

# Funktion aus dem Setup-Skript extrahieren
load_function() {
    local function_name="$1"
    python3 - "$SETUP_FILE" "$function_name" <<'PY'
import sys
from pathlib import Path

setup_file = Path(sys.argv[1])
function_name = sys.argv[2]
source = setup_file.read_text().splitlines()
start = None

for idx, line in enumerate(source):
    if line.startswith(f"{function_name}()"):  # Funktionsdefinition gefunden
        start = idx
        break

if start is None:
    raise SystemExit(f"Funktion {function_name} nicht gefunden")

output_lines = []
brace_depth = 0
for line in source[start:]:
    brace_depth += line.count('{') - line.count('}')
    output_lines.append(line)
    if brace_depth == 0 and line.strip().endswith('}'):
        break

print('\n'.join(output_lines))
PY
}

eval "$(load_function "check_and_install_kernel_modules")"

eval "$(grep '^REQUIRED_MODULES=' "$SETUP_FILE")"

log_entries=()
logMessage() {
    log_entries+=("$*")
}

install_failed_messages=()
setInstallFailed() {
    install_failed_messages+=("$2")
}

EXIT_ERROR=1
rebootNeeded=false

TEST_UPDATE_CALLS=0
TEST_UPDATE_RESULT=0
TEST_INSTALLED_MODULES=()
TEST_INSTALL_CALLS=()
declare -A TEST_INSTALL_SUCCESS=()

opkg() {
    case "$1" in
        list-installed)
            shift
            for module in "${TEST_INSTALLED_MODULES[@]}"; do
                printf '%s - 1.0\n' "$module"
            done
            ;;
        update)
            shift
            TEST_UPDATE_CALLS=$((TEST_UPDATE_CALLS + 1))
            return "$TEST_UPDATE_RESULT"
            ;;
        install)
            shift
            local module="$1"
            TEST_INSTALL_CALLS+=("$module")
            local rc=0
            if [[ -n "${TEST_INSTALL_SUCCESS[$module]+x}" ]]; then
                rc="${TEST_INSTALL_SUCCESS[$module]}"
            fi
            if [[ "$rc" -ne 0 ]]; then
                return "$rc"
            fi
            return 0
            ;;
        *)
            echo "Unbekannter opkg-Befehl: $1" >&2
            return 1
            ;;
    esac
}

reset_state() {
    log_entries=()
    install_failed_messages=()
    rebootNeeded=false
    TEST_UPDATE_CALLS=0
    TEST_UPDATE_RESULT=0
    TEST_INSTALL_CALLS=()
    TEST_INSTALLED_MODULES=()
    TEST_INSTALL_SUCCESS=()
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"
    if [[ "$expected" != "$actual" ]]; then
        echo "FEHLER: $message (erwartet: $expected, erhalten: $actual)" >&2
        exit 1
    fi
}

# Szenario: Alle Module vorhanden
reset_state
TEST_INSTALLED_MODULES=("${REQUIRED_MODULES[@]}")
check_and_install_kernel_modules
assert_equals 0 "$TEST_UPDATE_CALLS" "opkg update darf nicht aufgerufen werden, wenn alle Module vorhanden sind"
assert_equals 0 "${#TEST_INSTALL_CALLS[@]}" "Es dürfen keine Installationen durchgeführt werden"
assert_equals false "$rebootNeeded" "Es darf kein Neustart erforderlich sein"
assert_equals 0 "${#install_failed_messages[@]}" "Es dürfen keine Fehler gemeldet werden"

echo "Szenario 'alle Module vorhanden' erfolgreich"

# Szenario: Mindestens ein Modul fehlt
reset_state
TEST_INSTALLED_MODULES=("${REQUIRED_MODULES[0]}")
TEST_INSTALL_SUCCESS=( ["${REQUIRED_MODULES[1]}"]=0 )
check_and_install_kernel_modules
assert_equals 1 "$TEST_UPDATE_CALLS" "opkg update muss genau einmal aufgerufen werden"
assert_equals 1 "${#TEST_INSTALL_CALLS[@]}" "Genau ein Modul muss installiert werden"
assert_equals "${REQUIRED_MODULES[1]}" "${TEST_INSTALL_CALLS[0]}" "Das fehlende Modul muss installiert werden"
assert_equals true "$rebootNeeded" "Ein fehlendes Modul erfordert einen Neustart"
assert_equals 0 "${#install_failed_messages[@]}" "Es dürfen keine Fehler gemeldet werden"

echo "Szenario 'mindestens ein Modul fehlt' erfolgreich"
