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

log_messages=()

cat > "${SOURCE_FILE_DIR}/configs/dbus-adc.conf" <<'TEMPLATE'
device iio:device2
vref 2.5
scale 32767

tank 0 Temp "#1"
tank 1 Reservoir "#2" # Kommentar nach dem Label
TEMPLATE

local_default_vref=""
local_default_scale=""
local_default_device=""
local_default_types=()
local_default_labels=()

load_default_adc_defaults local_default_vref local_default_scale local_default_types local_default_labels local_default_device

if [ "${local_default_labels[0]}" != 'Temp "#1"' ]; then
    echo "Label mit Anführungszeichen und # wurde nicht korrekt übernommen: '${local_default_labels[0]}'" >&2
    exit 1
fi

if [ "${local_default_labels[1]}" != 'Reservoir "#2"' ]; then
    echo "Label mit # innerhalb von Anführungszeichen wurde abgeschnitten: '${local_default_labels[1]}'" >&2
    exit 1
fi

log_messages=()

cat > "${SOURCE_FILE_DIR}/configs/dbus-adc.conf" <<'TEMPLATE'
device iio:device3
vref 2.5
scale 32767

label Tank *
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

if [ "${local_default_labels[0]}" != "Tank *" ]; then
    echo "Label mit Literal-Stern wurde verändert: '${local_default_labels[0]}'" >&2
    exit 1
fi

for msg in "${log_messages[@]}"; do
    if [[ "$msg" == *"Kanäle ("* ]]; then
        echo "Es wurden unerwartete Kanal-Fallback-Logs erzeugt: ${msg}" >&2
        exit 1
    fi
done

log_messages=()

local_default_vref=""
local_default_scale=""
local_default_device=""
local_default_types=()
local_default_labels=()

pushd "$work_root" >/dev/null
touch 'iio:device-literal-match'

cat > "${SOURCE_FILE_DIR}/configs/dbus-adc.conf" <<'TEMPLATE'
device iio:device*
vref 2.5
scale 32767

tank 0 Tank Stern
tank 1 Tank Nova
TEMPLATE

load_default_adc_defaults local_default_vref local_default_scale local_default_types local_default_labels local_default_device

if [ "$local_default_device" != "iio:device*" ]; then
    echo "Device-Literal mit Wildcard wurde nicht unverändert übernommen: '${local_default_device}'." >&2
    popd >/dev/null
    exit 1
fi

for msg in "${log_messages[@]}"; do
    if [[ "$msg" == *"Device ("* ]]; then
        echo "Es wurden unerwartete Device-Fallback-Logs erzeugt: ${msg}" >&2
        popd >/dev/null
        exit 1
    fi
done

rm -f -- 'iio:device-literal-match'
popd >/dev/null

log_messages=()

load_gui_configuration() { return 1; }

nonInteractiveMode=true
filesUpdated=false
rebootNeeded=false
configRestorePerformed=false
configTxtRestorePerformed=false

scriptAction="INSTALL"

quote_root="${work_root}/quote_case"
ROOT_PATH="${quote_root}/root"
CONFIG_FILE="${quote_root}/venus/dbus-adc.conf"
BACKUP_CONFIG_FILE="${CONFIG_FILE}.orig"
USER_CONFIG_FILE="${quote_root}/user.conf"
CONFIG_TXT="${quote_root}/u-boot/config.txt"
CONFIG_TXT_BACKUP="${CONFIG_TXT}.orig"
OVERLAY_DIR="${quote_root}/overlays"
MODULE_STATE_DIR="${quote_root}/modules"
RC_LOCAL_FILE="${quote_root}/rc.local"
RC_LOCAL_BACKUP="${RC_LOCAL_FILE}.orig"
RC_LOCAL_STATE_FILE="${quote_root}/rc_local_state"

mkdir -p "$(dirname "$CONFIG_FILE")" "$(dirname "$CONFIG_TXT")" "$OVERLAY_DIR" "$MODULE_STATE_DIR" "$(dirname "$RC_LOCAL_FILE")" "$(dirname "$USER_CONFIG_FILE")"

mkdir -p "$ROOT_PATH"

SOURCE_FILE_DIR="${quote_root}/filesets"
mkdir -p "${SOURCE_FILE_DIR}/configs"

cat > "${SOURCE_FILE_DIR}/configs/dbus-adc.conf" <<'TEMPLATE'
device iio:device0
vref 1.3
scale 4095

tank 0
TEMPLATE

> "$CONFIG_TXT"

for channel in $(seq 0 $((TOTAL_ADC_CHANNELS - 1))); do
    if [ "$channel" -eq 0 ]; then
        eval "export EXPANDERPI_CHANNEL_${channel}_TYPE='tank'"
        eval "export EXPANDERPI_CHANNEL_${channel}_LABEL='"Tank Alpha"'"
    else
        eval "export EXPANDERPI_CHANNEL_${channel}_TYPE='none'"
        eval "export EXPANDERPI_CHANNEL_${channel}_LABEL=''"
    fi
done

unset EXPANDERPI_VREF
unset EXPANDERPI_SCALE
unset EXPANDERPI_DEVICE

result="$(prompt_sensor_label 0 "" true)"
if [ "$result" != "Tank Alpha" ]; then
    echo "prompt_sensor_label entfernte das umschließende Anführungszeichen nicht korrekt: '${result}'." >&2
    exit 1
fi

for msg in "${log_messages[@]}"; do
    if [[ "$msg" == *"Bitte Sensorbezeichnung"* ]] || [[ "$msg" == *"Ungültige Eingabe"* ]]; then
        echo "prompt_sensor_label geriet trotz gültigem Label in eine Fehlerschleife: ${msg}" >&2
        exit 1
    fi
done

log_messages=()

if ! install_config; then
    echo "install_config schlug für das Label mit Leerzeichen fehl" >&2
    exit 1
fi

if ! grep -q '^label "Tank Alpha"$' "$CONFIG_FILE"; then
    echo "dbus-adc.conf enthält keine korrekt gequotete Label-Zeile für 'Tank Alpha'." >&2
    exit 1
fi

if ! grep -Fq 'USER_CHANNEL_0_LABEL="Tank Alpha"' "$USER_CONFIG_FILE"; then
    echo "USER_CONFIG_FILE übernahm das bereinigte Label nicht im Rohformat." >&2
    exit 1
fi

log_messages=()

escape_root="${work_root}/escape_case"
ROOT_PATH="${escape_root}/root"
CONFIG_FILE="${escape_root}/venus/dbus-adc.conf"
BACKUP_CONFIG_FILE="${CONFIG_FILE}.orig"
USER_CONFIG_FILE="${escape_root}/dbus-adc.user.conf"
CONFIG_TXT="${escape_root}/u-boot/config.txt"
CONFIG_TXT_BACKUP="${CONFIG_TXT}.orig"
OVERLAY_DIR="${escape_root}/overlays"
MODULE_STATE_DIR="${escape_root}/modules"
RC_LOCAL_FILE="${escape_root}/rc.local"
RC_LOCAL_BACKUP="${RC_LOCAL_FILE}.orig"
RC_LOCAL_STATE_FILE="${escape_root}/rc_local_state"

mkdir -p "$(dirname "$CONFIG_FILE")" "$(dirname "$CONFIG_TXT")" "$OVERLAY_DIR" "$MODULE_STATE_DIR" "$(dirname "$RC_LOCAL_FILE")" \
    "$(dirname "$USER_CONFIG_FILE")"

mkdir -p "$ROOT_PATH"

SOURCE_FILE_DIR="${escape_root}/filesets"
mkdir -p "${SOURCE_FILE_DIR}/configs"

cat > "${SOURCE_FILE_DIR}/configs/dbus-adc.conf" <<'TEMPLATE'
device iio:device3
vref 2.5
scale 32767

tank 0 Tank "Default"
TEMPLATE

> "$CONFIG_TXT"

complex_label=$'Temp "Außen"\\Backslash'

for channel in $(seq 0 $((TOTAL_ADC_CHANNELS - 1))); do
    type_var="EXPANDERPI_CHANNEL_${channel}_TYPE"
    label_var="EXPANDERPI_CHANNEL_${channel}_LABEL"

    if [ "$channel" -eq 0 ]; then
        printf -v "$type_var" '%s' "temp"
        printf -v "$label_var" '%s' "$complex_label"
    else
        printf -v "$type_var" '%s' "none"
        printf -v "$label_var" '%s' ""
    fi

    export "$type_var"
    export "$label_var"
done

unset EXPANDERPI_VREF
unset EXPANDERPI_SCALE
unset EXPANDERPI_DEVICE

if ! install_config; then
    echo "install_config schlug für das Label mit Sonderzeichen fehl" >&2
    exit 1
fi

expected_serialized='USER_CHANNEL_0_LABEL="Temp \"Außen\"\\Backslash"'

if ! grep -Fq "$expected_serialized" "$USER_CONFIG_FILE"; then
    echo "USER_CONFIG_FILE enthält keine korrekt serialisierte Zeile für das Sonderzeichen-Label." >&2
    exit 1
fi

if ! env -i bash -n "$USER_CONFIG_FILE"; then
    echo "dbus-adc.user.conf enthält Syntaxfehler und ist nicht bash-kompatibel." >&2
    exit 1
fi

if ! python3 - "$USER_CONFIG_FILE" <<'PY'; then
import shlex
import sys

expected = 'Temp "Außen"\\Backslash'
values = {}
with open(sys.argv[1], 'r', encoding='utf-8') as fh:
    for raw_line in fh:
        line = raw_line.strip()
        if not line or line.startswith('#'):
            continue
        if '=' not in line:
            continue
        key, raw_value = line.split('=', 1)
        try:
            parsed = shlex.split(raw_value, posix=True)
        except ValueError as exc:  # pragma: no cover - defensiv
            raise SystemExit(f"Fehler beim Parsen von {key}: {exc}")
        if not parsed:
            continue
        values[key] = parsed[0]

if values.get('USER_CHANNEL_0_LABEL') != expected:
    raise SystemExit(
        f"Unerwarteter Wert für USER_CHANNEL_0_LABEL: {values.get('USER_CHANNEL_0_LABEL')!r}"
    )
if values.get('USER_CHANNEL_0') != expected:
    raise SystemExit(
        f"Unerwarteter Wert für USER_CHANNEL_0: {values.get('USER_CHANNEL_0')!r}"
    )
PY
    echo "USER_CONFIG_FILE liefert nach dem Parsen nicht den ursprünglichen Labelwert." >&2
    exit 1
fi

for msg in "${log_messages[@]}"; do
    if [[ "$msg" == *"Ungültige Eingabe"* ]]; then
        echo "install_config meldete eine ungültige Eingabe trotz gültigem Label: ${msg}" >&2
        exit 1
    fi
done

printf 'OK\n'
