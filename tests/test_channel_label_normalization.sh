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
    # Minimale Umgebung für das Setup bereitstellen.
    temp_machine_dir="$(mktemp -d)"
    echo "raspberrypi4" > "${temp_machine_dir}/machine"
    export EXPANDERPI_MACHINE_FILE="${temp_machine_dir}/machine"

    # Minimale Stubs für die vom Setup erwarteten Helper-Funktionen.
    EXIT_INCOMPATIBLE_PLATFORM=${EXIT_INCOMPATIBLE_PLATFORM:-2}
    EXIT_ERROR=${EXIT_ERROR:-1}
    EXIT_FILE_SET_ERROR=${EXIT_FILE_SET_ERROR:-3}
    logMessage() { :; }
    setInstallFailed() { :; }
    endScript() { :; }

    # shellcheck source=/dev/null
    source "$tmp_script"

    # Simuliere von der GUI geladene Kanaltypen und Labels.
    TOTAL_ADC_CHANNELS=8
    saved_channel_types=("tank" "temp" "voltage" "current" "pressure" "humidity" "custom" "none")
    saved_channel_labels=("" "" "" "" "" "" "" "")

    declare -a gui_labels

    # DBus-Labels mit Leerzeichen wie gefordert
    gui_labels[0]="Tank 1"
    gui_labels[1]="Temperatur 5"

    declare -a channel_labels
    for ((channel=0; channel<TOTAL_ADC_CHANNELS; channel++)); do
        channel_labels[channel]=""
        if [ "${saved_channel_types[channel],,}" != "none" ]; then
            local fallback
            fallback="$(channel_label_fallback "$channel" "${saved_channel_types[channel]}")"
            saved_channel_labels[channel]="$(normalize_channel_label "${gui_labels[channel]:-}" "$fallback")"
        else
            saved_channel_labels[channel]=""
        fi
        channel_labels[channel]=""
    done

    # Prüfe, dass die GUI-Werte direkt normalisiert wurden.
    if [ "${saved_channel_labels[0]}" != "tank1" ]; then
        echo "Erwartete Normalisierung für Kanal 0 fehlgeschlagen: ${saved_channel_labels[0]}" >&2
        return 1
    fi
    if [ "${saved_channel_labels[1]}" != "temperatur5" ]; then
        echo "Erwartete Normalisierung für Kanal 1 fehlgeschlagen: ${saved_channel_labels[1]}" >&2
        return 1
    fi
    if [ "${saved_channel_labels[2]}" != "voltage" ]; then
        echo "Erwartete Fallback-Benennung für Spannung fehlgeschlagen: ${saved_channel_labels[2]}" >&2
        return 1
    fi
    if [ "${saved_channel_labels[3]}" != "current" ]; then
        echo "Erwartete Fallback-Benennung für Strom fehlgeschlagen: ${saved_channel_labels[3]}" >&2
        return 1
    fi
    if [ "${saved_channel_labels[4]}" != "pressure" ]; then
        echo "Erwartete Fallback-Benennung für Druck fehlgeschlagen: ${saved_channel_labels[4]}" >&2
        return 1
    fi
    if [ "${saved_channel_labels[5]}" != "humidity" ]; then
        echo "Erwartete Fallback-Benennung für Luftfeuchtigkeit fehlgeschlagen: ${saved_channel_labels[5]}" >&2
        return 1
    fi
    if [ "${saved_channel_labels[6]}" != "sensor_7" ]; then
        echo "Erwartete Fallback-Benennung für benutzerdefinierten Kanal fehlgeschlagen: ${saved_channel_labels[6]}" >&2
        return 1
    fi

    # Simuliere den use_saved-Zweig aus install_config.
    for ((channel=0; channel<TOTAL_ADC_CHANNELS; channel++)); do
        local saved_type="${saved_channel_types[channel]}"
        if [ "${saved_type,,}" != "none" ]; then
            local fallback normalized_label
            fallback="$(channel_label_fallback "$channel" "$saved_type")"
            normalized_label="$(normalize_channel_label "${saved_channel_labels[channel]}" "$fallback")"
            channel_labels[channel]="$normalized_label"
            saved_channel_labels[channel]="$normalized_label"
        else
            channel_labels[channel]=""
            saved_channel_labels[channel]=""
        fi
        # Alle Typen sollen übernommen bleiben
        if [ "${channel_labels[channel]}" != "" ] && [ "${saved_channel_types[channel]}" = "none" ]; then
            echo "Ein deaktivierter Kanal erhielt unerwartet ein Label." >&2
            return 1
        fi
    done

    # Prüfe, dass prompt_channel_assignment neue Sensortypen unverändert zurückliefert.
    local previous_non_interactive="${nonInteractiveMode:-false}"
    nonInteractiveMode=true
    unset EXPANDERPI_CHANNEL_5
    unset EXPANDERPI_CHANNEL_5_LABEL
    EXPANDERPI_CHANNEL_5_TYPE="voltage"
    local voltage_response
    voltage_response="$(prompt_channel_assignment 5 "" "")"
    if [ "${voltage_response%%|*}" != "voltage" ]; then
        echo "Erwartete Typweitergabe für 'voltage' schlug fehl: ${voltage_response}" >&2
        return 1
    fi
    unset EXPANDERPI_CHANNEL_5
    unset EXPANDERPI_CHANNEL_5_TYPE
    unset EXPANDERPI_CHANNEL_5_LABEL

    # Prüfe, dass ein zusammengesetzter Wert mit Leerzeichen im Label korrekt verarbeitet wird.
    unset EXPANDERPI_CHANNEL_0
    unset EXPANDERPI_CHANNEL_0_TYPE
    unset EXPANDERPI_CHANNEL_0_LABEL
    EXPANDERPI_CHANNEL_0="tank|Tank Level"
    local tank_response tank_output
    tank_response="$(prompt_channel_assignment 0 "" "")"
    tank_output="${tank_response%$'\n'}"
    if [ "$tank_output" != "tank|tanklevel" ]; then
        echo "Erwartete Ausgabe 'tank|tanklevel' schlug fehl: ${tank_output}" >&2
        return 1
    fi
    unset EXPANDERPI_CHANNEL_0
    unset EXPANDERPI_CHANNEL_0_TYPE
    unset EXPANDERPI_CHANNEL_0_LABEL

    nonInteractiveMode="$previous_non_interactive"
    unset previous_non_interactive

    # Erzeuge die Ausgabe ähnlich der dbus-adc.conf.
    local config_output=""
    for ((channel=0; channel<TOTAL_ADC_CHANNELS; channel++)); do
        if [ -n "${channel_labels[channel]}" ]; then
            config_output+="${channel_labels[channel]} ${channel}\n"
        fi
    done

    printf "%b" "$config_output"
}

main "$@"
