#!/bin/bash
set -euo pipefail

# Lade Funktionsdefinitionen aus dem Setup-Skript ohne den ausführenden Hauptteil.
tmp_script="$(mktemp)"
temp_machine_dir=""
awk '/^case "\$scriptAction" in/ { exit } { print }' "$(dirname "$0")/../setup" > "$tmp_script"

cleanup() {
    rm -f "$tmp_script"
    if [ -n "${temp_machine_dir:-}" ] && [ -d "$temp_machine_dir" ]; then
        rm -rf "$temp_machine_dir"
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
    local -a default_channel_types=()
    local -a default_channel_labels=()

    if ! parse_default_adc_configuration "$template_file" default_vref default_scale default_channel_types default_channel_labels; then
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

    echo "Alle Kanal- und Typentests erfolgreich."
}

main "$@"
