#!/bin/bash
set -euo pipefail

work_dir=""
helper_dir=""
script_dir=""
log_file=""

cleanup() {
    if [ -n "${script_dir:-}" ] && [ -f "$script_dir" ]; then
        rm -f "$script_dir"
    fi
    if [ -n "${work_dir:-}" ] && [ -d "$work_dir" ]; then
        rm -rf "$work_dir"
    fi
    if [ -n "${helper_dir:-}" ] && [ -d "$helper_dir" ]; then
        rm -rf "$helper_dir"
    fi
    if [ -n "${log_file:-}" ] && [ -f "$log_file" ]; then
        rm -f "$log_file"
    fi
}
trap cleanup EXIT

work_dir="$(mktemp -d)"
helper_dir="$(mktemp -d)"
log_file="${work_dir}/log.txt"
touch "$log_file"

export LOG_FILE="$log_file"
export WORK_ROOT="$work_dir"

helper_resource_stub="${helper_dir}/helper_resources.sh"
cat >"$helper_resource_stub" <<'STUB'
#!/bin/bash
logMessage() {
    printf 'LOG:%s\n' "$*" >>"$LOG_FILE"
}
setInstallFailed() {
    local code="$1"
    shift || true
    local reason="${1:-}"
    printf 'SETINSTALLFAILED:%s:%s\n' "$code" "$reason" >>"$LOG_FILE"
}
endScript() {
    printf 'ENDSCRIPT\n' >>"$LOG_FILE"
}
setScriptVersion() { :; }
setPackageVersion() { :; }
yesNoPrompt() { return 0; }
isInstallFailed() { return 1; }
setInstallAction() { :; }
setUninstallAction() { :; }
setCheckAction() { :; }
setDescription() { :; }
setScriptMessage() { :; }
setProgressBarMessage() { :; }
setRebootRequired() { :; }
scriptDir="$WORK_ROOT"
STUB
chmod +x "$helper_resource_stub"

script_dir="${work_dir}/setup_snippet.sh"
awk '/^case "\$scriptAction" in/ { exit } { print }' "$(dirname "$0")/../setup" >"$script_dir"

python3 - "$script_dir" "$helper_resource_stub" <<'PY'
import sys
setup_path = sys.argv[1]
helper_path = sys.argv[2]
with open(setup_path, 'r', encoding='utf-8') as fh:
    data = fh.read()
needle = 'helper_resource="/data/SetupHelper/HelperResources/forSetupScript"'
if needle not in data:
    raise SystemExit('helper_resource assignment not found')
replacement = f'helper_resource="{helper_path}"'
with open(setup_path, 'w', encoding='utf-8') as fh:
    fh.write(data.replace(needle, replacement, 1))
PY

machine_file="${work_dir}/machine"
echo "beaglebone" >"$machine_file"
export EXPANDERPI_MACHINE_FILE="$machine_file"

export EXIT_INCOMPATIBLE_PLATFORM=${EXIT_INCOMPATIBLE_PLATFORM:-2}

set +e
bash "$script_dir" >/dev/null 2>&1
status=$?
set -e

if [ "$status" -ne "$EXIT_INCOMPATIBLE_PLATFORM" ]; then
    echo "Skript beendete sich nicht mit EXIT_INCOMPATIBLE_PLATFORM (Status: $status)." >&2
    exit 1
fi

if ! grep -q 'LOG:Abbruch wegen inkompatibler Plattform.' "$log_file"; then
    echo "Es wurde kein Abbruch-Logeintrag gefunden." >&2
    cat "$log_file" >&2
    exit 1
fi

if grep -q 'LOG:Starte Vorprüfungen' "$log_file"; then
    echo "run_prechecks wurde trotz inkompatibler Plattform aufgerufen." >&2
    cat "$log_file" >&2
    exit 1
fi

if ! grep -q 'SETINSTALLFAILED' "$log_file"; then
    echo "setInstallFailed wurde nicht ausgelöst." >&2
    cat "$log_file" >&2
    exit 1
fi

if [ -d "${work_dir}/overlay_state" ]; then
    echo "overlay_state-Verzeichnis wurde unerwartet angelegt." >&2
    exit 1
fi

if [ -d "${work_dir}/state" ]; then
    echo "state-Verzeichnis wurde unerwartet angelegt." >&2
    exit 1
fi

: >"$log_file"
echo "raspberrypi3" >"$machine_file"

set +e
bash "$script_dir" >/dev/null 2>&1
status=$?
set -e

if [ "$status" -ne 0 ]; then
    echo "Skript bricht für raspberrypi3 weiterhin ab (Status: $status)." >&2
    cat "$log_file" >&2
    exit 1
fi

if grep -q 'LOG:Abbruch wegen inkompatibler Plattform.' "$log_file"; then
    echo "raspberrypi3 löst weiterhin den Inkompatibilitätsabbruch aus." >&2
    cat "$log_file" >&2
    exit 1
fi

if grep -q 'SETINSTALLFAILED' "$log_file"; then
    echo "setInstallFailed wird für raspberrypi3 weiterhin gesetzt." >&2
    cat "$log_file" >&2
    exit 1
fi

if find "$work_dir" -name '*.orig' -print -quit | grep -q .; then
    echo "Es wurden unerwartet .orig-Dateien erzeugt." >&2
    find "$work_dir" -name '*.orig' -print >&2
    exit 1
fi

printf 'OK\n'
