#!/bin/bash
set -euo pipefail

# Lade Funktionsdefinitionen aus dem Setup-Skript ohne den ausführenden Hauptteil.
tmp_script="$(mktemp)"
temp_machine_dir=""
helper_stub=""
user_config_work_dir=""
awk '/^case "\$scriptAction" in/ { exit } { print }' "$(dirname "$0")/../setup" > "$tmp_script"

helper_stub="$(mktemp)"
cat >"$helper_stub" <<'STUB'
#!/bin/bash
scriptDir="$(pwd)"
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
STUB

python3 - "$tmp_script" "$helper_stub" <<'PY'
import sys
path, stub = sys.argv[1:3]
needle = 'helper_resource="/data/SetupHelper/HelperResources/forSetupScript"'
with open(path, 'r', encoding='utf-8') as handle:
    data = handle.read()
if needle not in data:
    raise SystemExit('helper_resource assignment not found')
replacement = f'helper_resource="{stub}"'
data = data.replace(needle, replacement, 1)
with open(path, 'w', encoding='utf-8') as handle:
    handle.write(data)
PY

cleanup() {
    rm -f "$tmp_script"
    if [ -n "${helper_stub:-}" ] && [ -f "$helper_stub" ]; then
        rm -f "$helper_stub"
    fi
    if [ -n "${temp_machine_dir:-}" ] && [ -d "$temp_machine_dir" ]; then
        rm -rf "$temp_machine_dir"
    fi
    if [ -n "${user_config_work_dir:-}" ] && [ -d "$user_config_work_dir" ]; then
        rm -rf "$user_config_work_dir"
    fi
}
trap cleanup EXIT

main() {
    temp_machine_dir="$(mktemp -d)"
    echo "raspberrypi4" > "${temp_machine_dir}/machine"
    export EXPANDERPI_MACHINE_FILE="${temp_machine_dir}/machine"

    EXIT_INCOMPATIBLE_PLATFORM=${EXIT_INCOMPATIBLE_PLATFORM:-2}
    EXIT_ERROR=${EXIT_ERROR:-1}
    EXIT_FILE_SET_ERROR=${EXIT_FILE_SET_ERROR:-3}
    logMessage() { :; }
    setInstallFailed() { :; }
    endScript() { :; }

    export SETUPHELPER_MODE="batch"
    export SETUPHELPER_FORCE_NONINTERACTIVE="foobar"

    # shellcheck source=/dev/null
    source "$tmp_script"

    if [ "${nonInteractiveMode}" != true ]; then
        echo "Nicht-interaktiver Modus sollte bei SETUPHELPER_MODE=batch aktiv sein." >&2
        return 1
    fi

    unset SETUPHELPER_MODE
    unset SETUPHELPER_FORCE_NONINTERACTIVE

    nonInteractiveMode=true

    local -a fallback_expectations=(
        "0 tank tank1"
        "1 temp temperatur2"
    )

    for fallback_entry in "${fallback_expectations[@]}"; do
        IFS=' ' read -r channel type expected_label <<<"${fallback_entry}"
        local placeholder
        placeholder="$(channel_label_fallback "$channel" "$type")"
        if [ "$placeholder" != "$expected_label" ]; then
            echo "Unerwarteter Platzhalter '${placeholder}' für ${type} Kanal ${channel}" >&2
            return 1
        fi

        unset "EXPANDERPI_CHANNEL_${channel}"
        unset "EXPANDERPI_CHANNEL_${channel}_TYPE"
        unset "EXPANDERPI_CHANNEL_${channel}_LABEL"

        local non_interactive_result
        non_interactive_result="$(prompt_channel_assignment "$channel" "$type" "")"
        non_interactive_result="${non_interactive_result%$'\n'}"
        if [ "$non_interactive_result" != "${type}|${expected_label}" ]; then
            echo "Nicht-interaktive Zuweisung für ${type} Kanal ${channel} ergab '${non_interactive_result}'" >&2
            return 1
        fi
    done

    local template_file
    template_file="$(dirname "$0")/../FileSets/configs/dbus-adc.conf"
    local default_vref=""
    local default_scale=""
    local default_device=""
    local -a default_channel_types=()
    local -a default_channel_labels=()

    if ! parse_default_adc_configuration "$template_file" default_vref default_scale default_channel_types default_channel_labels default_device; then
        echo "Vorlage konnte nicht geparst werden: ${template_file}" >&2
        return 1
    fi

    local -a expected_types=("tank" "tank" "tank" "tank" "temp" "temp" "temp" "temp")
    local -a expected_labels=("tank1" "tank2" "tank3" "tank4" "temperatur5" "temperatur6" "temperatur7" "temperatur8")

    for (( channel=0; channel<TOTAL_ADC_CHANNELS; channel++ )); do
        if [ "${default_channel_types[channel]}" != "${expected_types[channel]}" ]; then
            echo "Unerwarteter Standardtyp für Kanal $channel: ${default_channel_types[channel]}" >&2
            return 1
        fi

        if [ -n "${default_channel_labels[channel]}" ]; then
            echo "Kanal $channel sollte kein Default-Label besitzen, gefunden: ${default_channel_labels[channel]}" >&2
            return 1
        fi

        local generated_label
        generated_label="$(channel_label_fallback "$channel" "${default_channel_types[channel]}")"
        if [ "$generated_label" != "${expected_labels[channel]}" ]; then
            echo "Fallback-Label für Kanal $channel stimmt nicht: ${generated_label}" >&2
            return 1
        fi
    done

    EXPANDERPI_VREF=" 1.300 "
    local trimmed_vref
    trimmed_vref="$(prompt_numeric_value "Test" " 1.200 " '^[0-9]+([.][0-9]+)?$' "Fehler" "EXPANDERPI_VREF")"
    if [ "$trimmed_vref" != "1.300" ]; then
        echo "Erwartete Übernahme des getrimmten Vref-Werts schlug fehl: ${trimmed_vref}" >&2
        return 1
    fi
    unset EXPANDERPI_VREF

    TOTAL_ADC_CHANNELS=4
    local -a channel_types=("tank" "temp" "voltage" "none")
    local -a invalid_list=()

    if validate_channel_types channel_types invalid_list; then
        echo "validate_channel_types hätte den ungültigen Wert 'voltage' ablehnen müssen." >&2
        return 1
    fi

    if [ "${#invalid_list[@]}" -eq 0 ]; then
        echo "validate_channel_types meldete keinen ungültigen Kanal." >&2
        return 1
    fi

    local previous_total_channels="$TOTAL_ADC_CHANNELS"
    TOTAL_ADC_CHANNELS=2
    USER_CHANNEL_0="tank1"
    USER_CHANNEL_1="temperatur5"
    local -a derived_types=()
    derived_types[0]="$(infer_channel_type_from_label "${USER_CHANNEL_0}")"
    derived_types[1]="$(infer_channel_type_from_label "${USER_CHANNEL_1}")"
    local -a derived_invalid=()

    if ! validate_channel_types derived_types derived_invalid; then
        echo "validate_channel_types sollte numerische Label-Suffixe aus der Benutzerkonfiguration akzeptieren." >&2
        return 1
    fi

    if [ "${#derived_invalid[@]}" -ne 0 ]; then
        echo "Numerische Label-Suffixe wurden unerwartet als ungültig markiert: ${derived_invalid[*]}" >&2
        return 1
    fi

    if [ "${derived_types[0]}" != "tank" ] || [ "${derived_types[1]}" != "temp" ]; then
        echo "Abgeleitete Typen aus Labeln stimmen nicht: ${derived_types[*]}" >&2
        return 1
    fi

    TOTAL_ADC_CHANNELS="$previous_total_channels"
    unset USER_CHANNEL_0
    unset USER_CHANNEL_1

    local canonical_temp
    canonical_temp="$(canonicalize_sensor_type "Temperatur Sensor")"
    if [ "$canonical_temp" != "temp" ]; then
        echo "Temperatur-Synonym wurde nicht erkannt: ${canonical_temp}" >&2
        return 1
    fi

    local canonical_tank
    canonical_tank="$(canonicalize_sensor_type "fuel")"
    if [ "$canonical_tank" != "tank" ]; then
        echo "Tank-Synonym wurde nicht erkannt: ${canonical_tank}" >&2
        return 1
    fi

    local canonical_disabled
    canonical_disabled="$(canonicalize_sensor_type "nicht belegt")"
    if [ "$canonical_disabled" != "none" ]; then
        echo "Deaktivierter Kanal wurde nicht erkannt: ${canonical_disabled}" >&2
        return 1
    fi

    local canonical_invalid
    canonical_invalid="$(canonicalize_sensor_type "voltage")"
    if [ "$canonical_invalid" != "invalid" ]; then
        echo "Ungültiger Typ sollte als 'invalid' zurückgegeben werden: ${canonical_invalid}" >&2
        return 1
    fi

    unset EXPANDERPI_CHANNEL_0
    unset EXPANDERPI_CHANNEL_0_TYPE
    unset EXPANDERPI_CHANNEL_0_LABEL
    EXPANDERPI_CHANNEL_0_TYPE="voltage"
    local invalid_response
    invalid_response="$(prompt_channel_assignment 0 "tank" "")"
    invalid_response="${invalid_response%$'\n'}"
    if [ "${invalid_response%%|*}" != "invalid" ]; then
        echo "Nicht-interaktive Erkennung für ungültigen Typ schlug fehl: ${invalid_response}" >&2
        return 1
    fi

    nonInteractiveMode=false
    local interactive_output
    interactive_output="$(printf '\n' | prompt_channel_assignment 1 "temp" "Temperatur1")"
    interactive_output="${interactive_output%$'\n'}"
    if [ "${interactive_output%%|*}" != "temp" ]; then
        echo "Interaktive Standardübernahme für Temperatur schlug fehl: ${interactive_output}" >&2
        return 1
    fi

    nonInteractiveMode=true

    local prev_root_path="${ROOT_PATH:-}"
    local prev_source_file_dir="${SOURCE_FILE_DIR:-}"
    local prev_user_config_file="${USER_CONFIG_FILE:-}"
    local prev_config_file="${CONFIG_FILE:-}"
    local prev_backup_config_file="${BACKUP_CONFIG_FILE:-}"
    local prev_overlay_dir="${OVERLAY_DIR:-}"
    local prev_overlay_state_dir="${OVERLAY_STATE_DIR:-}"
    local prev_config_txt="${CONFIG_TXT:-}"
    local prev_config_txt_backup="${CONFIG_TXT_BACKUP:-}"
    local prev_module_state_dir="${MODULE_STATE_DIR:-}"
    local prev_module_track_file="${MODULE_TRACK_FILE:-}"
    local prev_rc_local_state_file="${RC_LOCAL_STATE_FILE:-}"
    local prev_rc_local_file="${RC_LOCAL_FILE:-}"
    local prev_rc_local_backup="${RC_LOCAL_BACKUP:-}"
    local prev_files_updated="${filesUpdated:-false}"
    local prev_config_restore="${configRestorePerformed:-false}"
    local prev_config_txt_restore="${configTxtRestorePerformed:-false}"
    local prev_rc_local_restore="${rcLocalRestorePerformed:-false}"

    user_config_work_dir="$(mktemp -d)"
    local test_root="${user_config_work_dir}/root"
    ROOT_PATH="$test_root"
    SOURCE_FILE_DIR="${test_root}/FileSets"
    USER_CONFIG_FILE="${test_root}/dbus-adc.user.conf"
    CONFIG_FILE="${test_root}/dbus-adc.conf"
    BACKUP_CONFIG_FILE="${CONFIG_FILE}.orig"
    OVERLAY_DIR="${test_root}/overlays"
    OVERLAY_STATE_DIR="${test_root}/overlay_state"
    CONFIG_TXT="${test_root}/config.txt"
    CONFIG_TXT_BACKUP="${CONFIG_TXT}.orig"
    MODULE_STATE_DIR="${test_root}/module_state"
    MODULE_TRACK_FILE="${MODULE_STATE_DIR}/installed_kernel_modules.list"
    RC_LOCAL_STATE_FILE="${MODULE_STATE_DIR}/rc_local_entries.list"
    RC_LOCAL_FILE="${test_root}/rc.local"
    RC_LOCAL_BACKUP="${RC_LOCAL_FILE}.orig"

    mkdir -p "$ROOT_PATH" "${SOURCE_FILE_DIR}/configs" "$OVERLAY_STATE_DIR" "$MODULE_STATE_DIR"
    : > "$CONFIG_TXT"
    cp "$(dirname "$0")/../FileSets/configs/dbus-adc.conf" "${SOURCE_FILE_DIR}/configs/dbus-adc.conf"

    filesUpdated=false
    configRestorePerformed=false
    configTxtRestorePerformed=false
    rcLocalRestorePerformed=false

    local special_label
    special_label=$'Tank $LEVEL $(cat /tmp/value) `ticks`'
    export EXPANDERPI_CHANNEL_0_TYPE="tank"
    export EXPANDERPI_CHANNEL_0_LABEL="$special_label"
    export EXPANDERPI_VREF="2.7"
    export EXPANDERPI_SCALE="4095"
    export EXPANDERPI_USE_SAVED="true"

    if ! install_config; then
        echo "install_config schlug für das Label mit Sonderzeichen fehl" >&2
        return 1
    fi

    unset USER_VREF USER_SCALE USER_DEVICE USER_CHANNEL_0 USER_CHANNEL_0_LABEL USER_CHANNEL_0_TYPE
    # shellcheck source=/dev/null
    source "$USER_CONFIG_FILE"

    if [ "${USER_CHANNEL_0_LABEL}" != "$special_label" ]; then
        echo "USER_CHANNEL_0_LABEL wurde unerwartet verändert: '${USER_CHANNEL_0_LABEL}'" >&2
        return 1
    fi

    if [ "${USER_CHANNEL_0}" != "$special_label" ]; then
        echo "USER_CHANNEL_0 wurde unerwartet verändert: '${USER_CHANNEL_0}'" >&2
        return 1
    fi

    if [ "${USER_CHANNEL_0_TYPE}" != "tank" ]; then
        echo "USER_CHANNEL_0_TYPE wurde unerwartet angepasst: '${USER_CHANNEL_0_TYPE}'" >&2
        return 1
    fi

    if [ "${USER_VREF}" != "2.7" ]; then
        echo "USER_VREF wurde unerwartet verändert: '${USER_VREF}'" >&2
        return 1
    fi

    if [ "${USER_SCALE}" != "4095" ]; then
        echo "USER_SCALE wurde unerwartet verändert: '${USER_SCALE}'" >&2
        return 1
    fi

    unset EXPANDERPI_CHANNEL_0_TYPE EXPANDERPI_CHANNEL_0_LABEL EXPANDERPI_VREF EXPANDERPI_SCALE EXPANDERPI_USE_SAVED
    unset USER_VREF USER_SCALE USER_DEVICE USER_CHANNEL_0 USER_CHANNEL_0_LABEL USER_CHANNEL_0_TYPE

    ROOT_PATH="$prev_root_path"
    SOURCE_FILE_DIR="$prev_source_file_dir"
    USER_CONFIG_FILE="$prev_user_config_file"
    CONFIG_FILE="$prev_config_file"
    BACKUP_CONFIG_FILE="$prev_backup_config_file"
    OVERLAY_DIR="$prev_overlay_dir"
    OVERLAY_STATE_DIR="$prev_overlay_state_dir"
    CONFIG_TXT="$prev_config_txt"
    CONFIG_TXT_BACKUP="$prev_config_txt_backup"
    MODULE_STATE_DIR="$prev_module_state_dir"
    MODULE_TRACK_FILE="$prev_module_track_file"
    RC_LOCAL_STATE_FILE="$prev_rc_local_state_file"
    RC_LOCAL_FILE="$prev_rc_local_file"
    RC_LOCAL_BACKUP="$prev_rc_local_backup"
    filesUpdated="$prev_files_updated"
    configRestorePerformed="$prev_config_restore"
    configTxtRestorePerformed="$prev_config_txt_restore"
    rcLocalRestorePerformed="$prev_rc_local_restore"

    echo "Alle Kanal- und Typentests erfolgreich."
}

main "$@"
