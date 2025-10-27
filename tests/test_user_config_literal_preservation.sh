#!/bin/bash
set -euo pipefail

tmp_script="$(mktemp)"
helper_dir="$(mktemp -d)"
work_root=""
install_failed_flag=false
log_messages=()

cleanup() {
    rm -f "$tmp_script"
    if [ -d "$helper_dir" ]; then
        rm -rf "$helper_dir"
    fi
    if [ -n "${work_root:-}" ] && [ -d "$work_root" ]; then
        rm -rf "$work_root"
    fi
}
trap cleanup EXIT

logMessage() {
    log_messages+=("$*")
}

setInstallFailed() {
    install_failed_flag=true
    log_messages+=("install_failed: $*")
}

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
path, helper = sys.argv[1:3]
with open(path, 'r', encoding='utf-8') as handle:
    data = handle.read()
needle = 'helper_resource="/data/SetupHelper/HelperResources/forSetupScript"'
if needle not in data:
    raise SystemExit('helper_resource assignment not found')
data = data.replace(needle, f'helper_resource="{helper}"', 1)
with open(path, 'w', encoding='utf-8') as handle:
    handle.write(data)
PY

EXIT_INCOMPATIBLE_PLATFORM=${EXIT_INCOMPATIBLE_PLATFORM:-2}
EXIT_ERROR=${EXIT_ERROR:-1}
EXIT_FILE_SET_ERROR=${EXIT_FILE_SET_ERROR:-3}

machine_file="${helper_dir}/machine"
echo "raspberrypi4" >"$machine_file"
export EXPANDERPI_MACHINE_FILE="$machine_file"

# shellcheck source=/dev/null
source "$tmp_script"

load_gui_configuration() { return 1; }

nonInteractiveMode=true
filesUpdated=false
rebootNeeded=false
configRestorePerformed=false
configTxtRestorePerformed=false

scriptAction="INSTALL"

work_root="$(mktemp -d)"

literal_root="${work_root}/literal_case"
ROOT_PATH="${literal_root}/root"
CONFIG_FILE="${literal_root}/venus/dbus-adc.conf"
BACKUP_CONFIG_FILE="${CONFIG_FILE}.orig"
USER_CONFIG_FILE="${literal_root}/dbus-adc.user.conf"
CONFIG_TXT="${literal_root}/u-boot/config.txt"
CONFIG_TXT_BACKUP="${CONFIG_TXT}.orig"
OVERLAY_DIR="${literal_root}/overlays"
OVERLAY_STATE_DIR="${literal_root}/overlay_state"
MODULE_STATE_DIR="${literal_root}/modules"
MODULE_TRACK_FILE="${MODULE_STATE_DIR}/installed_kernel_modules.list"
RC_LOCAL_FILE="${literal_root}/rc.local"
RC_LOCAL_BACKUP="${RC_LOCAL_FILE}.orig"
RC_LOCAL_STATE_FILE="${literal_root}/rc_local_state"
SOURCE_FILE_DIR="${literal_root}/filesets"

mkdir -p "$ROOT_PATH" "$(dirname "$CONFIG_FILE")" "$(dirname "$CONFIG_TXT")" \
    "$OVERLAY_DIR" "$OVERLAY_STATE_DIR" "$MODULE_STATE_DIR" "$(dirname "$RC_LOCAL_FILE")" \
    "$(dirname "$USER_CONFIG_FILE")" "${SOURCE_FILE_DIR}/configs"

>"$CONFIG_TXT"

cat > "${SOURCE_FILE_DIR}/configs/dbus-adc.conf" <<'TEMPLATE'
device iio:device0
vref 1.3
scale 4095

tank 0
temp 1
TEMPLATE

channel_injection_file="${literal_root}/command_injection_triggered"

python3 - "$USER_CONFIG_FILE" "$channel_injection_file" <<'PY'
import sys
user_config, injection = sys.argv[1:3]
label_value = f"literal$VALUE`backtick`$(touch {injection})"
with open(user_config, 'w', encoding='utf-8') as handle:
    handle.write("USER_VREF='1.3'\n")
    handle.write("USER_SCALE='4095'\n")
    handle.write("USER_DEVICE='iio:device0'\n")
    handle.write(f"USER_CHANNEL_0='{label_value}'\n")
    handle.write("USER_CHANNEL_0_TYPE='tank'\n")
    for channel in range(1, 8):
        handle.write(f"USER_CHANNEL_{channel}=''\n")
        handle.write(f"USER_CHANNEL_{channel}_TYPE='none'\n")
PY

if [ -e "$channel_injection_file" ]; then
    echo "Befüllung der Benutzerkonfiguration hat den Injektionsbefehl ausgeführt." >&2
    exit 1
fi

export EXPANDERPI_USE_SAVED="true"

if ! install_config; then
    echo "install_config scheiterte im Literal-Test." >&2
    exit 1
fi

if [ "$install_failed_flag" = true ]; then
    echo "install_config meldete setInstallFailed im Literal-Test." >&2
    exit 1
fi

if [ -e "$channel_injection_file" ]; then
    echo "Injektionsbefehl wurde beim Auslesen der Benutzerkonfiguration ausgeführt." >&2
    exit 1
fi

expected_label="literal\$VALUE\`backtick\`\$(touch ${channel_injection_file})"

python3 - "$CONFIG_FILE" "$expected_label" <<'PY'
import sys
config_path, expected = sys.argv[1:3]
with open(config_path, 'r', encoding='utf-8') as handle:
    contents = handle.read()
if expected not in contents:
    print('Label wurde in dbus-adc.conf nicht unverändert übernommen.', file=sys.stderr)
    sys.exit(1)
PY

unset USER_CHANNEL_0 USER_CHANNEL_0_TYPE

# shellcheck source=/dev/null
source "$USER_CONFIG_FILE"

if [ "${USER_CHANNEL_0}" != "$expected_label" ]; then
    printf 'USER_CHANNEL_0 wurde unerwartet verändert: %s\n' "${USER_CHANNEL_0}" >&2
    exit 1
fi

if [ "${USER_CHANNEL_0_TYPE}" != "tank" ]; then
    printf 'USER_CHANNEL_0_TYPE wurde nicht beibehalten: %s\n' "${USER_CHANNEL_0_TYPE}" >&2
    exit 1
fi

if [ -e "$channel_injection_file" ]; then
    echo "Injektionsbefehl wurde beim erneuten Sourcen der Benutzerkonfiguration ausgeführt." >&2
    exit 1
fi
