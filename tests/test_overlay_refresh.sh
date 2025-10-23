#!/bin/bash
set -euo pipefail

tmp_script="$(mktemp)"
temp_machine_dir=""
work_dir=""
install_failed=0
last_failure=""

cleanup() {
    rm -f "$tmp_script"
    if [ -n "${temp_machine_dir:-}" ] && [ -d "$temp_machine_dir" ]; then
        rm -rf "$temp_machine_dir"
    fi
    if [ -n "${work_dir:-}" ] && [ -d "$work_dir" ]; then
        rm -rf "$work_dir"
    fi
}
trap cleanup EXIT

logMessage() {
    :
}

setInstallFailed() {
    install_failed=1
    if [ $# -ge 2 ]; then
        last_failure="$2"
    else
        last_failure=""
    fi
}

endScript() {
    :
}

backupFile() {
    local source="$1"
    local destination="$2"
    if [ -f "$source" ]; then
        mkdir -p "$(dirname "$destination")"
        cp "$source" "$destination"
    else
        rm -f "$destination"
    fi
}

opkg() {
    local command="$1"
    shift || true
    case "$command" in
        list-installed)
            printf 'kernel-module-rtc-ds1307 - 1\nkernel-module-mcp320x - 1\n'
            ;;
        update|install|remove)
            echo "opkg $command ist im Test nicht implementiert" >&2
            return 1
            ;;
        *)
            echo "opkg Befehl $command wird vom Test nicht unterstützt" >&2
            return 1
            ;;
    esac
}

main() {
    temp_machine_dir="$(mktemp -d)"
    echo "raspberrypi4" > "${temp_machine_dir}/machine"
    export EXPANDERPI_MACHINE_FILE="${temp_machine_dir}/machine"

    awk '/^case "\$scriptAction" in/ { exit } { print }' "$(dirname "$0")/../setup" > "$tmp_script"

    EXIT_INCOMPATIBLE_PLATFORM=${EXIT_INCOMPATIBLE_PLATFORM:-2}
    EXIT_ERROR=${EXIT_ERROR:-1}
    EXIT_FILE_SET_ERROR=${EXIT_FILE_SET_ERROR:-3}

    # shellcheck source=/dev/null
    source "$tmp_script"

    work_dir="$(mktemp -d)"

    ROOT_PATH="${work_dir}/root"
    SOURCE_FILE_DIR="${work_dir}/filesets"
    CONFIG_FILE="${work_dir}/etc/dbus-adc.conf"
    BACKUP_CONFIG_FILE="${CONFIG_FILE}.orig"
    CONFIG_TXT="${work_dir}/u-boot/config.txt"
    CONFIG_TXT_BACKUP="${CONFIG_TXT}.orig"
    RC_LOCAL_FILE="${work_dir}/data/rc.local"
    RC_LOCAL_BACKUP="${RC_LOCAL_FILE}.orig"
    OVERLAY_DIR="${work_dir}/overlays"
    OVERLAY_STATE_DIR="${work_dir}/overlay_state"
    MODULE_STATE_DIR="${work_dir}/state"
    MODULE_TRACK_FILE="${MODULE_STATE_DIR}/installed_kernel_modules.list"
    RC_LOCAL_STATE_FILE="${MODULE_STATE_DIR}/rc_local_entries.list"
    USER_CONFIG_FILE="${ROOT_PATH}/dbus-adc.user.conf"

    mkdir -p "${SOURCE_FILE_DIR}/configs" "${SOURCE_FILE_DIR}/overlays" \
        "$(dirname "$CONFIG_FILE")" "$(dirname "$CONFIG_TXT")" \
        "$(dirname "$RC_LOCAL_FILE")" "$OVERLAY_DIR"

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

    printf 'ORIGINAL\n' > "$CONFIG_FILE"
    printf '# Ausgangskonfiguration\n' > "$CONFIG_TXT"
    printf '#!/bin/sh\n' > "$RC_LOCAL_FILE"

    printf 'overlay-version-1\n' > "${SOURCE_FILE_DIR}/overlays/i2c-rtc.dtbo"
    printf 'mcp-overlay\n' > "${SOURCE_FILE_DIR}/overlays/mcp3208.dtbo"

    install_failed=0
    scriptAction="INSTALL"

    if ! run_prechecks; then
        echo "run_prechecks schlug im Initiallauf fehl: ${last_failure}" >&2
        exit 1
    fi

    if [ "$install_failed" -ne 0 ]; then
        echo "Initialer run_prechecks-Lauf setzte setInstallFailed: ${last_failure}" >&2
        exit 1
    fi

    check_and_restore_overlays

    local overlay_path="${OVERLAY_DIR}/i2c-rtc.dtbo"
    if ! cmp -s "${SOURCE_FILE_DIR}/overlays/i2c-rtc.dtbo" "$overlay_path"; then
        echo "Initiales Overlay unterscheidet sich von der ausgelieferten Variante." >&2
        exit 1
    fi

    local first_checksum
    first_checksum="$(sha256sum "$overlay_path" | awk '{print $1}')"

    printf 'overlay-version-2\n' > "${SOURCE_FILE_DIR}/overlays/i2c-rtc.dtbo"

    install_failed=0
    if ! run_prechecks; then
        echo "run_prechecks schlug im Reinstall fehl: ${last_failure}" >&2
        exit 1
    fi

    if [ "$install_failed" -ne 0 ]; then
        echo "Reinstall-run_prechecks meldete setInstallFailed: ${last_failure}" >&2
        exit 1
    fi

    check_and_restore_overlays

    local expected_checksum
    expected_checksum="$(sha256sum "${SOURCE_FILE_DIR}/overlays/i2c-rtc.dtbo" | awk '{print $1}')"
    local updated_checksum
    updated_checksum="$(sha256sum "$overlay_path" | awk '{print $1}')"

    if [ "$updated_checksum" = "$first_checksum" ]; then
        echo "Overlay wurde beim Reinstall nicht ersetzt." >&2
        exit 1
    fi

    if [ "$updated_checksum" != "$expected_checksum" ]; then
        echo "Overlay-Checksumme nach Reinstall stimmt nicht mit der neuen Quelle überein." >&2
        exit 1
    fi

    if ! cmp -s "${SOURCE_FILE_DIR}/overlays/i2c-rtc.dtbo" "$overlay_path"; then
        echo "Overlay-Datei unterscheidet sich nach Reinstall weiterhin von der Quelle." >&2
        exit 1
    fi

    local state_file="${OVERLAY_STATE_DIR}/i2c-rtc.dtbo.state"
    if [ ! -f "$state_file" ]; then
        echo "State-Datei für i2c-rtc.dtbo fehlt nach dem Reinstall." >&2
        exit 1
    fi

    local recorded_action
    recorded_action="$(get_overlay_state_value "$state_file" "last_action")"
    if [ "$recorded_action" != "overlay_refreshed" ]; then
        echo "Unerwartete last_action in der State-Datei: ${recorded_action}" >&2
        exit 1
    fi

    local recorded_checksum
    recorded_checksum="$(get_overlay_state_value "$state_file" "setup_checksum")"
    if [ "$recorded_checksum" != "$expected_checksum" ]; then
        echo "State-Datei enthält nicht die neue Setup-Checksumme." >&2
        exit 1
    fi

    echo "Overlay-Refresh-Test erfolgreich."
}

main "$@"
