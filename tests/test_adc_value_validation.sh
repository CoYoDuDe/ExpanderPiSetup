#!/bin/bash
set -euo pipefail

tmp_script="$(mktemp)"
log_file=""
temp_root=""

cleanup() {
    rm -f "$tmp_script"
    if [ -n "${log_file:-}" ] && [ -f "$log_file" ]; then
        rm -f "$log_file"
    fi
    if [ -n "${temp_root:-}" ] && [ -d "$temp_root" ]; then
        rm -rf "$temp_root"
    fi
}
trap cleanup EXIT

main() {
    temp_root="$(mktemp -d)"
    log_file="${temp_root}/log.txt"

    awk '/^case "\$scriptAction" in/ { exit } { print }' "$(dirname "$0")/../setup" > "$tmp_script"

    local machine_file="${temp_root}/machine"
    echo "raspberrypi4" > "$machine_file"
    export EXPANDERPI_MACHINE_FILE="$machine_file"

    EXIT_INCOMPATIBLE_PLATFORM=${EXIT_INCOMPATIBLE_PLATFORM:-2}
    EXIT_ERROR=${EXIT_ERROR:-1}
    EXIT_FILE_SET_ERROR=${EXIT_FILE_SET_ERROR:-3}

    logMessage() {
        printf '%s\n' "$*" >> "$log_file"
    }
    setInstallFailed() {
        printf 'setInstallFailed:%s\n' "$*" >> "$log_file"
    }
    endScript() { :; }

    # shellcheck source=/dev/null
    source "$tmp_script"

    load_gui_configuration() { return 1; }

    nonInteractiveMode=true
    filesUpdated=false
    rebootNeeded=false
    configRestorePerformed=false
    configTxtRestorePerformed=false

    scriptAction="INSTALL"

    ROOT_PATH="${temp_root}/root"
    CONFIG_FILE="${temp_root}/venus/dbus-adc.conf"
    BACKUP_CONFIG_FILE="${CONFIG_FILE}.orig"
    mkdir -p "$(dirname "$CONFIG_FILE")"
    USER_CONFIG_FILE="${temp_root}/user.conf"

    SOURCE_FILE_DIR="${temp_root}/filesets"
    mkdir -p "${SOURCE_FILE_DIR}/configs"
    cat > "${SOURCE_FILE_DIR}/configs/dbus-adc.conf" <<'TEMPLATE'
device iio:device1
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

    CONFIG_TXT="${temp_root}/u-boot/config.txt"
    CONFIG_TXT_BACKUP="${CONFIG_TXT}.orig"
    mkdir -p "$(dirname "$CONFIG_TXT")"
    : > "$CONFIG_TXT"

    OVERLAY_DIR="${temp_root}/overlays"
    MODULE_STATE_DIR="${temp_root}/modules"
    RC_LOCAL_FILE="${temp_root}/rc.local"
    RC_LOCAL_BACKUP="${RC_LOCAL_FILE}.orig"
    RC_LOCAL_STATE_FILE="${temp_root}/rc_local_state"

    mkdir -p "$ROOT_PATH"

    EXPANDERPI_USE_SAVED="false"
    EXPANDERPI_VREF="0.5"
    EXPANDERPI_SCALE="70000"
    EXPANDERPI_DEVICE="device foo"

    for channel in $(seq 0 $((TOTAL_ADC_CHANNELS - 1))); do
        eval "export EXPANDERPI_CHANNEL_${channel}_TYPE='none'"
        eval "export EXPANDERPI_CHANNEL_${channel}_LABEL=''"
    done

    if ! install_config; then
        echo "install_config scheiterte" >&2
        return 1
    fi

    if ! grep -q "^vref ${DEFAULT_VREF_FALLBACK}$" "$CONFIG_FILE"; then
        echo "vref wurde nicht auf ${DEFAULT_VREF_FALLBACK} gesetzt" >&2
        return 1
    fi

    if ! grep -q "^scale ${DEFAULT_SCALE_FALLBACK}$" "$CONFIG_FILE"; then
        echo "scale wurde nicht auf ${DEFAULT_SCALE_FALLBACK} gesetzt" >&2
        return 1
    fi

    if grep -Fq "0.5" "$CONFIG_FILE"; then
        echo "Ungültiger Vref-Wert 0.5 fand sich in der Konfiguration" >&2
        return 1
    fi

    if grep -Fq "70000" "$CONFIG_FILE"; then
        echo "Ungültiger Scale-Wert 70000 fand sich in der Konfiguration" >&2
        return 1
    fi

    if ! grep -q "^device iio:device0$" "$CONFIG_FILE"; then
        echo "Device-Fallback iio:device0 wurde nicht in die Konfiguration geschrieben" >&2
        return 1
    fi

    if ! grep -Fq 'USER_VREF="1.3"' "$USER_CONFIG_FILE"; then
        echo "USER_CONFIG_FILE übernahm den Vref-Fallback nicht" >&2
        return 1
    fi

    if ! grep -Fq 'USER_SCALE="4095"' "$USER_CONFIG_FILE"; then
        echo "USER_CONFIG_FILE übernahm den Scale-Fallback nicht" >&2
        return 1
    fi

    if ! grep -Fq 'USER_DEVICE="iio:device0"' "$USER_CONFIG_FILE"; then
        echo "USER_CONFIG_FILE übernahm den Device-Fallback nicht" >&2
        return 1
    fi

    if ! grep -Fq "Vref 0.5 liegt außerhalb" "$log_file"; then
        echo "Log meldete die Vref-Korrektur nicht" >&2
        return 1
    fi

    if ! grep -Fq "Scale 70000 liegt außerhalb" "$log_file"; then
        echo "Log meldete die Scale-Korrektur nicht" >&2
        return 1
    fi

    if ! grep -Fq 'Umgebungsvariable EXPANDERPI_DEVICE: ungültiger Device-Wert "foo"' "$log_file"; then
        echo "Log meldete den Device-Fallback nicht" >&2
        return 1
    fi

    printf 'OK\n'
}

main "$@"
