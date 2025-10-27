#!/bin/bash
set -euo pipefail

tmp_script="$(mktemp)"
helper_stub=""
temp_root=""
machine_dir=""

cleanup() {
    rm -f "$tmp_script"
    if [ -n "${helper_stub:-}" ] && [ -f "$helper_stub" ]; then
        rm -f "$helper_stub"
    fi
    if [ -n "${machine_dir:-}" ] && [ -d "$machine_dir" ]; then
        rm -rf "$machine_dir"
    fi
    if [ -n "${temp_root:-}" ] && [ -d "$temp_root" ]; then
        rm -rf "$temp_root"
    fi
}
trap cleanup EXIT

main() {
    temp_root="$(mktemp -d)"

    awk '/^case "\$scriptAction" in/ { exit } { print }' "$(dirname "$0")/../setup" > "$tmp_script"

    helper_stub="${temp_root}/helper_resources/forSetupScript"
    mkdir -p "$(dirname "$helper_stub")"
    printf ':\n' > "$helper_stub"
    sed -i "s|helper_resource=\"/data/SetupHelper/HelperResources/forSetupScript\"|helper_resource=\"${helper_stub}\"|" "$tmp_script"

    machine_dir="${temp_root}/machine"
    mkdir -p "$machine_dir"
    printf 'raspberrypi4\n' > "${machine_dir}/machine"
    export EXPANDERPI_MACHINE_FILE="${machine_dir}/machine"

    EXIT_INCOMPATIBLE_PLATFORM=${EXIT_INCOMPATIBLE_PLATFORM:-2}
    EXIT_ERROR=${EXIT_ERROR:-1}
    EXIT_FILE_SET_ERROR=${EXIT_FILE_SET_ERROR:-3}

    logMessage() { :; }
    setInstallFailed() { :; }
    endScript() { :; }

    # shellcheck source=/dev/null
    source "$tmp_script"

    load_gui_configuration() { return 1; }

    nonInteractiveMode=true
    filesUpdated=false
    rebootNeeded=false
    configRestorePerformed=false
    configTxtRestorePerformed=false

    ROOT_PATH="${temp_root}/root"
    SOURCE_FILE_DIR="${temp_root}/filesets"
    CONFIG_FILE="${temp_root}/etc/dbus-adc.conf"
    BACKUP_CONFIG_FILE="${CONFIG_FILE}.orig"
    CONFIG_TXT="${temp_root}/boot/config.txt"
    CONFIG_TXT_BACKUP="${CONFIG_TXT}.orig"
    RC_LOCAL_FILE="${temp_root}/rc.local"
    RC_LOCAL_BACKUP="${RC_LOCAL_FILE}.orig"
    OVERLAY_DIR="${temp_root}/overlays"
    OVERLAY_STATE_DIR="${temp_root}/overlay_state"
    MODULE_STATE_DIR="${temp_root}/module_state"
    MODULE_TRACK_FILE="${MODULE_STATE_DIR}/installed_kernel_modules.list"
    RC_LOCAL_STATE_FILE="${MODULE_STATE_DIR}/rc_local_entries.list"
    USER_CONFIG_FILE="${ROOT_PATH}/dbus-adc.user.conf"

    mkdir -p "$ROOT_PATH" "${SOURCE_FILE_DIR}/configs" "$(dirname "$CONFIG_FILE")" \
        "$(dirname "$CONFIG_TXT")" "$(dirname "$RC_LOCAL_FILE")" "$OVERLAY_DIR" "$MODULE_STATE_DIR"

    cat > "${SOURCE_FILE_DIR}/configs/dbus-adc.conf" <<'TEMPLATE'
device iio:device0
vref 1.3
scale 4095

tank 0
tank 1
tank 2
tank 3
temp 4
temp 5
temp 6
temp 7
TEMPLATE

    cat > "$CONFIG_TXT" <<'CFG'
# dtoverlay=i2c-rtc,ds1307
#dtoverlay=mcp3208,spi0-0-present
CFG

    scriptAction="INSTALL"

    if ! install_config; then
        echo "install_config schlug fehl." >&2
        return 1
    fi

    if ! grep -Eq '^[[:space:]]*dtoverlay=i2c-rtc,ds1307([[:space:],]|$)' "$CONFIG_TXT"; then
        echo "Aktive dtoverlay=i2c-rtc,ds1307 Zeile wurde nicht hinzugefügt." >&2
        return 1
    fi

    if ! grep -Eq '^[[:space:]]*dtoverlay=mcp3208,spi0-0-present([[:space:],]|$)' "$CONFIG_TXT"; then
        echo "Aktive dtoverlay=mcp3208,spi0-0-present Zeile wurde nicht hinzugefügt." >&2
        return 1
    fi

    local rtc_count
    rtc_count=$(grep -Ec '^[[:space:]]*dtoverlay=i2c-rtc,ds1307([[:space:],]|$)' "$CONFIG_TXT")
    if [ "$rtc_count" -ne 1 ]; then
        echo "dtoverlay=i2c-rtc,ds1307 sollte genau einmal aktiv vorhanden sein (gefunden: ${rtc_count})." >&2
        return 1
    fi

    local mcp_count
    mcp_count=$(grep -Ec '^[[:space:]]*dtoverlay=mcp3208,spi0-0-present([[:space:],]|$)' "$CONFIG_TXT")
    if [ "$mcp_count" -ne 1 ]; then
        echo "dtoverlay=mcp3208,spi0-0-present sollte genau einmal aktiv vorhanden sein (gefunden: ${mcp_count})." >&2
        return 1
    fi

    if grep -Eq '^#[[:space:]]*dtoverlay=i2c-rtc,ds1307' "$CONFIG_TXT" && \
       grep -Eq '^#[[:space:]]*dtoverlay=mcp3208,spi0-0-present' "$CONFIG_TXT"; then
        echo "Test erfolgreich." >&2
    fi
}

main "$@"
