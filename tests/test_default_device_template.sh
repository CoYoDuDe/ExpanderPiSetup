#!/bin/bash
set -euo pipefail

tmp_script="$(mktemp)"
helper_dir="$(mktemp -d)"

cleanup() {
    rm -f "$tmp_script"
    if [ -d "$helper_dir" ]; then
        rm -rf "$helper_dir"
    fi
}
trap cleanup EXIT

log_messages=()
logMessage() {
    log_messages+=("$*")
}

setInstallFailed() { :; }
endScript() { :; }

helper_resource_stub="${helper_dir}/helper_resources.sh"
cat >"$helper_resource_stub" <<'STUB'
#!/bin/bash
if ! declare -F logMessage >/dev/null 2>&1; then
    logMessage() { :; }
fi
if ! declare -F setInstallFailed >/dev/null 2>&1; then
    setInstallFailed() { :; }
fi
if ! declare -F endScript >/dev/null 2>&1; then
    endScript() { :; }
fi
if ! declare -F setScriptVersion >/dev/null 2>&1; then
    setScriptVersion() { :; }
fi
if ! declare -F setPackageVersion >/dev/null 2>&1; then
    setPackageVersion() { :; }
fi
if ! declare -F yesNoPrompt >/dev/null 2>&1; then
    yesNoPrompt() { return 0; }
fi
if ! declare -F isInstallFailed >/dev/null 2>&1; then
    isInstallFailed() { return 1; }
fi
if ! declare -F setInstallAction >/dev/null 2>&1; then
    setInstallAction() { :; }
fi
if ! declare -F setUninstallAction >/dev/null 2>&1; then
    setUninstallAction() { :; }
fi
if ! declare -F setCheckAction >/dev/null 2>&1; then
    setCheckAction() { :; }
fi
if ! declare -F setDescription >/dev/null 2>&1; then
    setDescription() { :; }
fi
if ! declare -F setScriptMessage >/dev/null 2>&1; then
    setScriptMessage() { :; }
fi
if ! declare -F setProgressBarMessage >/dev/null 2>&1; then
    setProgressBarMessage() { :; }
fi
if ! declare -F setRebootRequired >/dev/null 2>&1; then
    setRebootRequired() { :; }
fi
scriptDir="$(pwd)"
STUB

awk '/^case "\$scriptAction" in/ { exit } { print }' "$(dirname "$0")/../setup" >"$tmp_script"
python3 - "$tmp_script" "$helper_resource_stub" <<'PY'
import sys
path = sys.argv[1]
helper = sys.argv[2]
with open(path, 'r', encoding='utf-8') as fh:
    data = fh.read()
needle = 'helper_resource="/data/SetupHelper/HelperResources/forSetupScript"'
if needle not in data:
    raise SystemExit('helper_resource assignment not found')
replacement = f'helper_resource="{helper}"'
data = data.replace(needle, replacement, 1)
with open(path, 'w', encoding='utf-8') as fh:
    fh.write(data)
PY

EXIT_INCOMPATIBLE_PLATFORM=${EXIT_INCOMPATIBLE_PLATFORM:-2}
EXIT_ERROR=${EXIT_ERROR:-1}
EXIT_FILE_SET_ERROR=${EXIT_FILE_SET_ERROR:-3}

machine_file="${helper_dir}/machine"
echo "raspberrypi4" >"$machine_file"
export EXPANDERPI_MACHINE_FILE="$machine_file"

# shellcheck source=/dev/null
source "$tmp_script"

work_root="$(mktemp -d)"
trap 'cleanup; rm -rf "$work_root"' EXIT

ROOT_PATH="${work_root}/root"
SOURCE_FILE_DIR="${work_root}/filesets"
mkdir -p "${SOURCE_FILE_DIR}/configs"
cat > "${SOURCE_FILE_DIR}/configs/dbus-adc.conf" <<'TEMPLATE'
device iio:device1
vref 2.5
scale 32767

tank 0 Tank A
tank 1 Tank B
tank 2 Tank C
tank 3 Tank D
temp 4 Sensor E
temp 5 Sensor F
temp 6 Sensor G
temp 7 Sensor H
TEMPLATE

mkdir -p "$ROOT_PATH"
local_default_vref=""
local_default_scale=""
local_default_device=""
declare -a local_default_types=()
declare -a local_default_labels=()

load_default_adc_defaults local_default_vref local_default_scale local_default_types local_default_labels local_default_device

if [ "$local_default_device" != "iio:device1" ]; then
    echo "Erwartetes Device iio:device1 wurde nicht übernommen (tatsächlich: ${local_default_device})." >&2
    exit 1
fi

for msg in "${log_messages[@]}"; do
    if [[ "$msg" == *"Device ("* ]]; then
        echo "Es wurden unerwartete Device-Fallback-Logs erzeugt: ${msg}" >&2
        exit 1
    fi
done

log_messages=()

cat > "${SOURCE_FILE_DIR}/configs/dbus-adc.conf" <<'TEMPLATE'
device iio:device2
vref 2.5
scale 32767

label Tank Alpha
tank 0
label Tank Beta
tank 1
label Tank Gamma
tank 2
label Tank Delta
tank 3
label Temp Epsilon
temp 4
label Temp Zeta
temp 5
label Temp Eta
temp 6
label Temp Theta
temp 7
TEMPLATE

local_default_vref=""
local_default_scale=""
local_default_device=""
local_default_types=()
local_default_labels=()

load_default_adc_defaults local_default_vref local_default_scale local_default_types local_default_labels local_default_device

expected_labels=(
    "Tank Alpha"
    "Tank Beta"
    "Tank Gamma"
    "Tank Delta"
    "Temp Epsilon"
    "Temp Zeta"
    "Temp Eta"
    "Temp Theta"
)

for i in "${!expected_labels[@]}"; do
    if [ "${local_default_labels[i]}" != "${expected_labels[i]}" ]; then
        echo "Label an Index ${i} entspricht nicht der Vorlage: '${local_default_labels[i]}' statt '${expected_labels[i]}'." >&2
        exit 1
    fi
done

for msg in "${log_messages[@]}"; do
    if [[ "$msg" == *"Kanäle ("* ]]; then
        echo "Es wurden unerwartete Kanal-Fallback-Logs erzeugt: ${msg}" >&2
        exit 1
    fi
done

printf 'OK\n'
