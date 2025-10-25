#!/bin/bash
set -euo pipefail

tmp_script="$(mktemp)"
temp_machine_dir=""
work_dir=""
install_failed=0
last_failure=""
helper_resource_file=""
helper_resource_created=false

cleanup() {
    rm -f "$tmp_script"
    if [ -n "${temp_machine_dir:-}" ] && [ -d "$temp_machine_dir" ]; then
        rm -rf "$temp_machine_dir"
    fi
    if [ -n "${work_dir:-}" ] && [ -d "$work_dir" ]; then
        rm -rf "$work_dir"
    fi
    if [ "$helper_resource_created" = true ] && [ -n "${helper_resource_file:-}" ]; then
        rm -f "$helper_resource_file"
        rmdir --ignore-fail-on-non-empty "$(dirname "$helper_resource_file")" 2>/dev/null || true
        rmdir --ignore-fail-on-non-empty "$(dirname "$(dirname "$helper_resource_file")")" 2>/dev/null || true
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
            echo "opkg $command darf im CHECK-Modus nicht aufgerufen werden" >&2
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

    helper_resource_file="/data/SetupHelper/HelperResources/forSetupScript"
    if [ ! -e "$helper_resource_file" ]; then
        helper_resource_created=true
        mkdir -p "$(dirname "$helper_resource_file")"
        : > "$helper_resource_file"
    fi

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

    mkdir -p "${SOURCE_FILE_DIR}/configs"
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

    mkdir -p "$(dirname "$CONFIG_FILE")"
    printf 'ORIGINAL\n' > "$CONFIG_FILE"

    mkdir -p "$(dirname "$CONFIG_TXT")"
    printf '# Ausgangskonfiguration\n' > "$CONFIG_TXT"

    mkdir -p "$(dirname "$RC_LOCAL_FILE")"
    printf '#!/bin/sh\n\n' > "$RC_LOCAL_FILE"

    mkdir -p "$OVERLAY_DIR"
    printf 'overlay-rtc' > "${OVERLAY_DIR}/i2c-rtc.dtbo"
    printf 'overlay-adc' > "${OVERLAY_DIR}/mcp3208.dtbo"

    mkdir -p "$ROOT_PATH"

    local config_before config_txt_before rc_local_before overlay_rtc_before overlay_adc_before
    config_before="$(sha256sum "$CONFIG_FILE" | awk '{print $1}')"
    config_txt_before="$(sha256sum "$CONFIG_TXT" | awk '{print $1}')"
    rc_local_before="$(sha256sum "$RC_LOCAL_FILE" | awk '{print $1}')"
    overlay_rtc_before="$(sha256sum "${OVERLAY_DIR}/i2c-rtc.dtbo" | awk '{print $1}')"
    overlay_adc_before="$(sha256sum "${OVERLAY_DIR}/mcp3208.dtbo" | awk '{print $1}')"

    scriptAction="CHECK"

    if ! run_prechecks; then
        echo "run_prechecks schlug fehl: ${last_failure}" >&2
        exit 1
    fi

    if [ "$install_failed" -ne 0 ]; then
        echo "setInstallFailed wurde ausgelöst: ${last_failure}" >&2
        exit 1
    fi

    if [ -f "$USER_CONFIG_FILE" ]; then
        echo "CHECK-Modus darf keine Benutzerkonfiguration erzeugen." >&2
        exit 1
    fi

    local unexpected_backup
    for unexpected_backup in "$BACKUP_CONFIG_FILE" "$CONFIG_TXT_BACKUP" "$RC_LOCAL_BACKUP"; do
        if [ -e "$unexpected_backup" ]; then
            echo "CHECK-Modus hat unerwartet Sicherungen erzeugt: ${unexpected_backup}" >&2
            exit 1
        fi
    done

    if [ -d "$OVERLAY_STATE_DIR" ]; then
        echo "CHECK-Modus hat ${OVERLAY_STATE_DIR} angelegt oder verändert." >&2
        exit 1
    fi

    if [ -d "$MODULE_STATE_DIR" ]; then
        echo "CHECK-Modus hat ${MODULE_STATE_DIR} angelegt oder verändert." >&2
        exit 1
    fi

    if find "$work_dir" -name '*.orig' -print -quit | grep -q .; then
        echo "CHECK-Modus darf keine *.orig-Dateien erzeugen." >&2
        exit 1
    fi

    if [ "$(sha256sum "$CONFIG_FILE" | awk '{print $1}')" != "$config_before" ]; then
        echo "CONFIG_FILE wurde im CHECK-Modus verändert." >&2
        exit 1
    fi

    if [ "$(sha256sum "$CONFIG_TXT" | awk '{print $1}')" != "$config_txt_before" ]; then
        echo "CONFIG_TXT wurde im CHECK-Modus verändert." >&2
        exit 1
    fi

    if [ "$(sha256sum "$RC_LOCAL_FILE" | awk '{print $1}')" != "$rc_local_before" ]; then
        echo "RC_LOCAL_FILE wurde im CHECK-Modus verändert." >&2
        exit 1
    fi

    if [ "$(sha256sum "${OVERLAY_DIR}/i2c-rtc.dtbo" | awk '{print $1}')" != "$overlay_rtc_before" ]; then
        echo "Overlay i2c-rtc.dtbo wurde im CHECK-Modus verändert." >&2
        exit 1
    fi

    if [ "$(sha256sum "${OVERLAY_DIR}/mcp3208.dtbo" | awk '{print $1}')" != "$overlay_adc_before" ]; then
        echo "Overlay mcp3208.dtbo wurde im CHECK-Modus verändert." >&2
        exit 1
    fi

    echo "Prüfe Regression: CHECK-Fehlschlag darf keine Bereinigung auslösen."

    run_uninstall_sequence_called=0
    run_uninstall_sequence() {
        run_uninstall_sequence_called=$((run_uninstall_sequence_called + 1))
    }

    has_install_failed_flag() {
        return 0
    }

    cleanup_executed=false
    scriptAction="CHECK"

    final_block="$(awk '
        /^if \[ "\$cleanup_executed" != true \]; then$/ { capture=1 }
        capture { print }
        /^endScript$/ { if (capture) exit }
    ' "$(dirname "$0")/../setup")"

    if [ -z "$final_block" ]; then
        echo "Abschlussblock konnte nicht extrahiert werden." >&2
        exit 1
    fi

    eval "$final_block"

    if [ "$run_uninstall_sequence_called" -ne 0 ]; then
        echo "run_uninstall_sequence wurde im CHECK-Fehlerfall unerwartet aufgerufen." >&2
        exit 1
    fi

    if [ ! -f "${OVERLAY_DIR}/i2c-rtc.dtbo" ] || [ ! -f "${OVERLAY_DIR}/mcp3208.dtbo" ]; then
        echo "Overlays wurden nach CHECK-Fehler unerwartet entfernt." >&2
        exit 1
    fi

    if [ -d "$OVERLAY_STATE_DIR" ] || [ -d "$MODULE_STATE_DIR" ]; then
        echo "CHECK-Fehler darf keine Zustandsverzeichnisse anlegen." >&2
        exit 1
    fi

    if [ "$(sha256sum "${OVERLAY_DIR}/i2c-rtc.dtbo" | awk '{print $1}')" != "$overlay_rtc_before" ]; then
        echo "Overlay i2c-rtc.dtbo wurde im CHECK-Fehlerfall verändert." >&2
        exit 1
    fi

    if [ "$(sha256sum "${OVERLAY_DIR}/mcp3208.dtbo" | awk '{print $1}')" != "$overlay_adc_before" ]; then
        echo "Overlay mcp3208.dtbo wurde im CHECK-Fehlerfall verändert." >&2
        exit 1
    fi

    echo "CHECK-Modus Smoke Test erfolgreich."
}

main "$@"
