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

    export SETUPHELPER_MODE="batch"
    export SETUPHELPER_FORCE_NONINTERACTIVE="foobar"

    # shellcheck source=/dev/null
    source "$tmp_script"

    if [ "${nonInteractiveMode}" != true ]; then
        echo "SETUPHELPER_MODE=batch sollte den nicht-interaktiven Modus aktivieren, wenn der Override ungültig ist." >&2
        return 1
    fi

    unset SETUPHELPER_MODE
    unset SETUPHELPER_FORCE_NONINTERACTIVE

    # Prüfe, dass numerische Umgebungswerte mit Leerzeichen getrimmt werden und nicht auf den Fallback zurückfallen.
    nonInteractiveMode=true

    local -a fallback_expectations=(
        "0 tank tank1"
        "1 temp temperatur2"
        "2 voltage spannung3"
        "3 current strom4"
        "4 pressure druck5"
        "5 humidity feuchte6"
    )

    for fallback_entry in "${fallback_expectations[@]}"; do
        IFS=' ' read -r fallback_channel fallback_type fallback_label <<<"${fallback_entry}"
        local computed_placeholder
        computed_placeholder="$(channel_label_fallback "$fallback_channel" "$fallback_type")"
        if [ "$computed_placeholder" != "$fallback_label" ]; then
            echo "channel_label_fallback lieferte unerwarteten Platzhalter '${computed_placeholder}' für ${fallback_type} Kanal ${fallback_channel}" >&2
            return 1
        fi

        local normalized_placeholder
        normalized_placeholder="$(normalize_channel_label "" "$computed_placeholder")"
        if [ "$normalized_placeholder" != "$computed_placeholder" ]; then
            echo "normalize_channel_label veränderte den Default '${computed_placeholder}' unerwartet zu '${normalized_placeholder}'." >&2
            return 1
        fi

        unset "EXPANDERPI_CHANNEL_${fallback_channel}"
        unset "EXPANDERPI_CHANNEL_${fallback_channel}_TYPE"
        unset "EXPANDERPI_CHANNEL_${fallback_channel}_LABEL"

        local non_interactive_result
        non_interactive_result="$(prompt_channel_assignment "$fallback_channel" "$fallback_type" "")"
        local trimmed_non_interactive_result
        trimmed_non_interactive_result="${non_interactive_result%$'\n'}"
        if [ "$trimmed_non_interactive_result" != "${fallback_type}|${fallback_label}" ]; then
            echo "Nicht-interaktive Zuweisung für ${fallback_type} Kanal ${fallback_channel} ergab '${trimmed_non_interactive_result}' statt '${fallback_type}|${fallback_label}'." >&2
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

    # Simuliere von der GUI geladene Kanaltypen und Labels.
    TOTAL_ADC_CHANNELS=8
    saved_channel_types=("tank" "temp" "voltage" "current" "pressure" "humidity" "custom" "none")
    saved_channel_labels=("" "" "" "" "" "" "" "")

    saved_channel_types[1]="Temperature Sensor"
    local canonicalized_saved_type
    canonicalized_saved_type="$(canonicalize_sensor_type "${saved_channel_types[1]}")"
    if [ "$canonicalized_saved_type" != "temp" ]; then
        echo "Kanonische Abbildung von 'Temperature Sensor' für gespeicherten Typ fehlgeschlagen: ${canonicalized_saved_type}" >&2
        return 1
    fi
    saved_channel_types[1]="$canonicalized_saved_type"

    local canonicalized_german_saved_type
    canonicalized_german_saved_type="$(canonicalize_sensor_type "Temperatur Sensor")"
    if [ "$canonicalized_german_saved_type" != "temp" ]; then
        echo "Kanonische Abbildung von 'Temperatur Sensor' fehlgeschlagen: ${canonicalized_german_saved_type}" >&2
        return 1
    fi

    local canonicalized_german_compound_type
    canonicalized_german_compound_type="$(canonicalize_sensor_type "temperatur-sensor")"
    if [ "$canonicalized_german_compound_type" != "temp" ]; then
        echo "Kanonische Abbildung von 'temperatur-sensor' fehlgeschlagen: ${canonicalized_german_compound_type}" >&2
        return 1
    fi

    local canonicalized_voltage_sensor
    canonicalized_voltage_sensor="$(canonicalize_sensor_type "Spannungssensor")"
    if [ "$canonicalized_voltage_sensor" != "voltage" ]; then
        echo "Kanonische Abbildung von 'Spannungssensor' fehlgeschlagen: ${canonicalized_voltage_sensor}" >&2
        return 1
    fi

    local canonicalized_voltage_spaced
    canonicalized_voltage_spaced="$(canonicalize_sensor_type "Spannung Sensor")"
    if [ "$canonicalized_voltage_spaced" != "voltage" ]; then
        echo "Kanonische Abbildung von 'Spannung Sensor' fehlgeschlagen: ${canonicalized_voltage_spaced}" >&2
        return 1
    fi

    local canonicalized_current_sensor
    canonicalized_current_sensor="$(canonicalize_sensor_type "Stromsensor")"
    if [ "$canonicalized_current_sensor" != "current" ]; then
        echo "Kanonische Abbildung von 'Stromsensor' fehlgeschlagen: ${canonicalized_current_sensor}" >&2
        return 1
    fi

    local canonicalized_current_spaced
    canonicalized_current_spaced="$(canonicalize_sensor_type "Strom Sensor")"
    if [ "$canonicalized_current_spaced" != "current" ]; then
        echo "Kanonische Abbildung von 'Strom Sensor' fehlgeschlagen: ${canonicalized_current_spaced}" >&2
        return 1
    fi

    local canonicalized_tank_fuel
    canonicalized_tank_fuel="$(canonicalize_sensor_type "fuel")"
    if [ "$canonicalized_tank_fuel" != "tank" ]; then
        echo "Kanonische Abbildung von 'fuel' fehlgeschlagen: ${canonicalized_tank_fuel}" >&2
        return 1
    fi

    local canonicalized_current_ampere
    canonicalized_current_ampere="$(canonicalize_sensor_type "ampere")"
    if [ "$canonicalized_current_ampere" != "current" ]; then
        echo "Kanonische Abbildung von 'ampere' fehlgeschlagen: ${canonicalized_current_ampere}" >&2
        return 1
    fi

    local canonicalized_voltage_v
    canonicalized_voltage_v="$(canonicalize_sensor_type "v")"
    if [ "$canonicalized_voltage_v" != "voltage" ]; then
        echo "Kanonische Abbildung von 'v' fehlgeschlagen: ${canonicalized_voltage_v}" >&2
        return 1
    fi

    local canonicalized_pressure_press
    canonicalized_pressure_press="$(canonicalize_sensor_type "press")"
    if [ "$canonicalized_pressure_press" != "pressure" ]; then
        echo "Kanonische Abbildung von 'press' fehlgeschlagen: ${canonicalized_pressure_press}" >&2
        return 1
    fi

    local canonicalized_humidity_humid
    canonicalized_humidity_humid="$(canonicalize_sensor_type "humid")"
    if [ "$canonicalized_humidity_humid" != "humidity" ]; then
        echo "Kanonische Abbildung von 'humid' fehlgeschlagen: ${canonicalized_humidity_humid}" >&2
        return 1
    fi

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
    if [ "${saved_channel_labels[2]}" != "spannung3" ]; then
        echo "Erwartete Fallback-Benennung für Spannung fehlgeschlagen: ${saved_channel_labels[2]}" >&2
        return 1
    fi
    if [ "${saved_channel_labels[3]}" != "strom4" ]; then
        echo "Erwartete Fallback-Benennung für Strom fehlgeschlagen: ${saved_channel_labels[3]}" >&2
        return 1
    fi
    if [ "${saved_channel_labels[4]}" != "druck5" ]; then
        echo "Erwartete Fallback-Benennung für Druck fehlgeschlagen: ${saved_channel_labels[4]}" >&2
        return 1
    fi
    if [ "${saved_channel_labels[5]}" != "feuchte6" ]; then
        echo "Erwartete Fallback-Benennung für Luftfeuchtigkeit fehlgeschlagen: ${saved_channel_labels[5]}" >&2
        return 1
    fi
    if [ "${saved_channel_labels[6]}" != "sensor_7" ]; then
        echo "Erwartete Fallback-Benennung für benutzerdefinierten Kanal fehlgeschlagen: ${saved_channel_labels[6]}" >&2
        return 1
    fi

    saved_channel_types[1]="Temperature Sensor"

    # Simuliere den use_saved-Zweig aus install_config.
    for ((channel=0; channel<TOTAL_ADC_CHANNELS; channel++)); do
        local saved_type="${saved_channel_types[channel]}"
        saved_type="$(canonicalize_sensor_type "$saved_type")"
        saved_channel_types[channel]="$saved_type"
        channel_types[channel]="$saved_type"
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

    if [ "${channel_types[1]}" != "temp" ]; then
        echo "use_saved-Zweig erkannte 'Temperature Sensor' nicht als Temperatur: ${channel_types[1]}" >&2
        return 1
    fi

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

    # Prüfe, dass Leerzeichen im Sensortyp für Spannung entfernt werden.
    unset EXPANDERPI_CHANNEL_0
    unset EXPANDERPI_CHANNEL_0_LABEL
    EXPANDERPI_CHANNEL_0_TYPE=" voltage  sensor "
    local voltage_compact_response compact_output
    voltage_compact_response="$(prompt_channel_assignment 0 "" "")"
    compact_output="${voltage_compact_response%$'\n'}"
    if [ "${compact_output%%|*}" != "voltage" ]; then
        echo "Nicht-interaktive Erkennung für 'voltage  sensor' schlug fehl: ${compact_output}" >&2
        return 1
    fi
    unset EXPANDERPI_CHANNEL_0
    unset EXPANDERPI_CHANNEL_0_TYPE
    unset EXPANDERPI_CHANNEL_0_LABEL

    # Prüfe, dass der Sensortyp "Spannungssensor" im nicht-interaktiven Modus als Spannung erkannt wird.
    unset EXPANDERPI_CHANNEL_5
    unset EXPANDERPI_CHANNEL_5_TYPE
    unset EXPANDERPI_CHANNEL_5_LABEL
    EXPANDERPI_CHANNEL_5_TYPE="Spannungssensor"
    local german_voltage_response german_voltage_output
    german_voltage_response="$(prompt_channel_assignment 5 "" "")"
    german_voltage_output="${german_voltage_response%$'\n'}"
    if [ "${german_voltage_output%%|*}" != "voltage" ]; then
        echo "Nicht-interaktive Erkennung für 'Spannungssensor' schlug fehl: ${german_voltage_output}" >&2
        return 1
    fi
    unset EXPANDERPI_CHANNEL_5
    unset EXPANDERPI_CHANNEL_5_TYPE
    unset EXPANDERPI_CHANNEL_5_LABEL

    # Prüfe, dass Varianten mit Leerzeichen oder Bindestrich im nicht-interaktiven Modus als Spannung erkannt werden.
    unset EXPANDERPI_CHANNEL_5
    unset EXPANDERPI_CHANNEL_5_TYPE
    unset EXPANDERPI_CHANNEL_5_LABEL
    EXPANDERPI_CHANNEL_5_TYPE="Spannung sensor"
    local german_voltage_variant_response german_voltage_variant_output
    german_voltage_variant_response="$(prompt_channel_assignment 5 "" "")"
    german_voltage_variant_output="${german_voltage_variant_response%$'\n'}"
    if [ "${german_voltage_variant_output%%|*}" != "voltage" ]; then
        echo "Nicht-interaktive Erkennung für 'Spannung sensor' schlug fehl: ${german_voltage_variant_output}" >&2
        return 1
    fi
    unset EXPANDERPI_CHANNEL_5
    unset EXPANDERPI_CHANNEL_5_TYPE
    unset EXPANDERPI_CHANNEL_5_LABEL

    # Prüfe, dass der Sensortyp "Stromsensor" im nicht-interaktiven Modus als Strom erkannt wird.
    unset EXPANDERPI_CHANNEL_6
    unset EXPANDERPI_CHANNEL_6_TYPE
    unset EXPANDERPI_CHANNEL_6_LABEL
    EXPANDERPI_CHANNEL_6_TYPE="Stromsensor"
    local german_current_response german_current_output
    german_current_response="$(prompt_channel_assignment 6 "" "")"
    german_current_output="${german_current_response%$'\n'}"
    if [ "${german_current_output%%|*}" != "current" ]; then
        echo "Nicht-interaktive Erkennung für 'Stromsensor' schlug fehl: ${german_current_output}" >&2
        return 1
    fi
    unset EXPANDERPI_CHANNEL_6
    unset EXPANDERPI_CHANNEL_6_TYPE
    unset EXPANDERPI_CHANNEL_6_LABEL

    # Prüfe, dass Varianten mit Leerzeichen oder Bindestrich im nicht-interaktiven Modus als Strom erkannt werden.
    unset EXPANDERPI_CHANNEL_6
    unset EXPANDERPI_CHANNEL_6_TYPE
    unset EXPANDERPI_CHANNEL_6_LABEL
    EXPANDERPI_CHANNEL_6_TYPE="Strom sensor"
    local german_current_variant_response german_current_variant_output
    german_current_variant_response="$(prompt_channel_assignment 6 "" "")"
    german_current_variant_output="${german_current_variant_response%$'\n'}"
    if [ "${german_current_variant_output%%|*}" != "current" ]; then
        echo "Nicht-interaktive Erkennung für 'Strom sensor' schlug fehl: ${german_current_variant_output}" >&2
        return 1
    fi
    unset EXPANDERPI_CHANNEL_6
    unset EXPANDERPI_CHANNEL_6_TYPE
    unset EXPANDERPI_CHANNEL_6_LABEL

    # Prüfe, dass der Sensortyp "Temperature Sensor" im nicht-interaktiven Modus als Temperatur erkannt wird.
    unset EXPANDERPI_CHANNEL_2
    unset EXPANDERPI_CHANNEL_2_TYPE
    unset EXPANDERPI_CHANNEL_2_LABEL
    EXPANDERPI_CHANNEL_2_TYPE="Temperature Sensor"
    local temperature_response temperature_output
    temperature_response="$(prompt_channel_assignment 2 "" "")"
    temperature_output="${temperature_response%$'\n'}"
    if [ "${temperature_output%%|*}" != "temp" ]; then
        echo "Nicht-interaktive Erkennung für 'Temperature Sensor' schlug fehl: ${temperature_output}" >&2
        return 1
    fi
    unset EXPANDERPI_CHANNEL_2
    unset EXPANDERPI_CHANNEL_2_TYPE
    unset EXPANDERPI_CHANNEL_2_LABEL

    # Prüfe, dass der Sensortyp "Temperatur Sensor" im nicht-interaktiven Modus als Temperatur erkannt wird.
    unset EXPANDERPI_CHANNEL_3
    unset EXPANDERPI_CHANNEL_3_TYPE
    unset EXPANDERPI_CHANNEL_3_LABEL
    EXPANDERPI_CHANNEL_3_TYPE="Temperatur Sensor"
    local german_temperature_response german_temperature_output
    german_temperature_response="$(prompt_channel_assignment 3 "" "")"
    german_temperature_output="${german_temperature_response%$'\n'}"
    if [ "${german_temperature_output%%|*}" != "temp" ]; then
        echo "Nicht-interaktive Erkennung für 'Temperatur Sensor' schlug fehl: ${german_temperature_output}" >&2
        return 1
    fi
    unset EXPANDERPI_CHANNEL_3
    unset EXPANDERPI_CHANNEL_3_TYPE
    unset EXPANDERPI_CHANNEL_3_LABEL

    # Prüfe, dass der Sensortyp "temperatur-sensor" im nicht-interaktiven Modus als Temperatur erkannt wird.
    unset EXPANDERPI_CHANNEL_4
    unset EXPANDERPI_CHANNEL_4_TYPE
    unset EXPANDERPI_CHANNEL_4_LABEL
    EXPANDERPI_CHANNEL_4_TYPE="temperatur-sensor"
    local german_compact_temperature_response german_compact_temperature_output
    german_compact_temperature_response="$(prompt_channel_assignment 4 "" "")"
    german_compact_temperature_output="${german_compact_temperature_response%$'\n'}"
    if [ "${german_compact_temperature_output%%|*}" != "temp" ]; then
        echo "Nicht-interaktive Erkennung für 'temperatur-sensor' schlug fehl: ${german_compact_temperature_output}" >&2
        return 1
    fi
    unset EXPANDERPI_CHANNEL_4
    unset EXPANDERPI_CHANNEL_4_TYPE
    unset EXPANDERPI_CHANNEL_4_LABEL

    # Prüfe, dass der Sensortyp "Drucksensor" im nicht-interaktiven Modus als Druck erkannt wird.
    unset EXPANDERPI_CHANNEL_6
    unset EXPANDERPI_CHANNEL_6_TYPE
    unset EXPANDERPI_CHANNEL_6_LABEL
    EXPANDERPI_CHANNEL_6_TYPE="Drucksensor"
    local german_pressure_response german_pressure_output
    german_pressure_response="$(prompt_channel_assignment 6 "" "")"
    german_pressure_output="${german_pressure_response%$'\n'}"
    if [ "${german_pressure_output%%|*}" != "pressure" ]; then
        echo "Nicht-interaktive Erkennung für 'Drucksensor' schlug fehl: ${german_pressure_output}" >&2
        return 1
    fi
    unset EXPANDERPI_CHANNEL_6
    unset EXPANDERPI_CHANNEL_6_TYPE
    unset EXPANDERPI_CHANNEL_6_LABEL

    # Prüfe, dass Varianten mit Leerzeichen oder Bindestrich im nicht-interaktiven Modus als Druck erkannt werden.
    unset EXPANDERPI_CHANNEL_6
    unset EXPANDERPI_CHANNEL_6_TYPE
    unset EXPANDERPI_CHANNEL_6_LABEL
    EXPANDERPI_CHANNEL_6_TYPE="druck sensor"
    local german_pressure_variant_response german_pressure_variant_output
    german_pressure_variant_response="$(prompt_channel_assignment 6 "" "")"
    german_pressure_variant_output="${german_pressure_variant_response%$'\n'}"
    if [ "${german_pressure_variant_output%%|*}" != "pressure" ]; then
        echo "Nicht-interaktive Erkennung für 'druck sensor' schlug fehl: ${german_pressure_variant_output}" >&2
        return 1
    fi
    unset EXPANDERPI_CHANNEL_6
    unset EXPANDERPI_CHANNEL_6_TYPE
    unset EXPANDERPI_CHANNEL_6_LABEL

    # Prüfe, dass der Sensortyp "Feuchte Sensor" im nicht-interaktiven Modus als Luftfeuchtigkeit erkannt wird.
    unset EXPANDERPI_CHANNEL_7
    unset EXPANDERPI_CHANNEL_7_TYPE
    unset EXPANDERPI_CHANNEL_7_LABEL
    EXPANDERPI_CHANNEL_7_TYPE="Feuchte Sensor"
    local german_humidity_response german_humidity_output
    german_humidity_response="$(prompt_channel_assignment 7 "" "")"
    german_humidity_output="${german_humidity_response%$'\n'}"
    if [ "${german_humidity_output%%|*}" != "humidity" ]; then
        echo "Nicht-interaktive Erkennung für 'Feuchte Sensor' schlug fehl: ${german_humidity_output}" >&2
        return 1
    fi
    unset EXPANDERPI_CHANNEL_7
    unset EXPANDERPI_CHANNEL_7_TYPE
    unset EXPANDERPI_CHANNEL_7_LABEL

    # Prüfe, dass im interaktiven Modus eine vorbelegte Default-Zeichenkette "Temperature Sensor" als Temperatur erkannt wird.
    local previous_mode_for_default="${nonInteractiveMode:-false}"
    nonInteractiveMode=false
    local raw_default_type="Temperature Sensor"
    local canonical_default_type
    canonical_default_type="$(canonicalize_sensor_type "$raw_default_type")"
    if [ "$canonical_default_type" != "temp" ]; then
        echo "Kanonische Abbildung für Default-Typ 'Temperature Sensor' schlug fehl: ${canonical_default_type}" >&2
        return 1
    fi
    local interactive_default_temp_response
    local interactive_default_temp_output
    interactive_default_temp_response="$(printf '\nTempDefault\n' | prompt_channel_assignment 6 "$canonical_default_type" "")"
    interactive_default_temp_output="${interactive_default_temp_response%$'\n'}"
    if [ "${interactive_default_temp_output%%|*}" != "temp" ]; then
        echo "Interaktive Default-Vorbelegung 'Temperature Sensor' wurde nicht als Temperatur erkannt: ${interactive_default_temp_output}" >&2
        return 1
    fi
    nonInteractiveMode="$previous_mode_for_default"
    unset previous_mode_for_default

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

    # Prüfe, dass im interaktiven Modus ein Standardtyp mit Leerzeichen korrekt erkannt wird.
    nonInteractiveMode=false
    EXPANDERPI_CHANNEL_0_TYPE=" voltage "
    local interactive_trimmed_response interactive_trimmed_output
    interactive_trimmed_response="$(printf '\n' | prompt_channel_assignment 0 "${EXPANDERPI_CHANNEL_0_TYPE}" "")"
    interactive_trimmed_output="${interactive_trimmed_response%$'\n'}"
    if [ "${interactive_trimmed_output%%|*}" != "voltage" ]; then
        echo "Interaktive Vorbelegung für ' voltage ' wurde nicht als Spannung erkannt: ${interactive_trimmed_output}" >&2
        return 1
    fi
    unset EXPANDERPI_CHANNEL_0_TYPE

    # Prüfe, dass im interaktiven Modus ein groß geschriebener Standardtyp korrekt erkannt wird.
    EXPANDERPI_CHANNEL_5_TYPE="VOLTAGE"
    local interactive_response interactive_output
    interactive_response="$(printf '\n' | prompt_channel_assignment 5 "${EXPANDERPI_CHANNEL_5_TYPE}" "")"
    interactive_output="${interactive_response%$'\n'}"
    if [ "${interactive_output%%|*}" != "voltage" ]; then
        echo "Interaktive Vorbelegung für 'VOLTAGE' wurde nicht als Spannung erkannt: ${interactive_output}" >&2
        return 1
    fi
    unset EXPANDERPI_CHANNEL_5_TYPE

    # Prüfe, dass im interaktiven Modus eine vorbelegte Zeichenkette "Spannungssensor" als Spannung erkannt wird.
    EXPANDERPI_CHANNEL_5_TYPE="Spannungssensor"
    local interactive_german_voltage_response interactive_german_voltage_output
    interactive_german_voltage_response="$(printf '\n' | prompt_channel_assignment 5 "${EXPANDERPI_CHANNEL_5_TYPE}" "")"
    interactive_german_voltage_output="${interactive_german_voltage_response%$'\n'}"
    if [ "${interactive_german_voltage_output%%|*}" != "voltage" ]; then
        echo "Interaktive Vorbelegung für 'Spannungssensor' wurde nicht als Spannung erkannt: ${interactive_german_voltage_output}" >&2
        return 1
    fi
    unset EXPANDERPI_CHANNEL_5_TYPE

    # Prüfe, dass interaktive Eingaben mit Leerzeichen für Spannung erkannt werden.
    local interactive_german_voltage_input_response interactive_german_voltage_input_output
    interactive_german_voltage_input_response="$(printf 'Spannung sensor\n' | prompt_channel_assignment 5 "" "")"
    interactive_german_voltage_input_output="${interactive_german_voltage_input_response%$'\n'}"
    if [ "${interactive_german_voltage_input_output%%|*}" != "voltage" ]; then
        echo "Interaktive Eingabe für 'Spannung sensor' wurde nicht als Spannung erkannt: ${interactive_german_voltage_input_output}" >&2
        return 1
    fi

    # Prüfe, dass im interaktiven Modus eine vorbelegte Zeichenkette "Temperature Sensor" als Temperatur erkannt wird.
    EXPANDERPI_CHANNEL_2_TYPE="Temperature Sensor"
    local interactive_temp_response interactive_temp_output
    interactive_temp_response="$(printf 'Temperature Sensor\ntempchannel\n' | prompt_channel_assignment 2 "${EXPANDERPI_CHANNEL_2_TYPE}" "")"
    interactive_temp_output="${interactive_temp_response%$'\n'}"
    if [ "${interactive_temp_output%%|*}" != "temp" ]; then
        echo "Interaktive Vorbelegung für 'Temperature Sensor' wurde nicht als Temperatur erkannt: ${interactive_temp_output}" >&2
        return 1
    fi
    unset EXPANDERPI_CHANNEL_2_TYPE

    # Prüfe, dass im interaktiven Modus eine vorbelegte Zeichenkette "feuchte-sensor" als Luftfeuchtigkeit erkannt wird.
    EXPANDERPI_CHANNEL_7_TYPE="feuchte-sensor"
    local interactive_humidity_response interactive_humidity_output
    interactive_humidity_response="$(printf '\n' | prompt_channel_assignment 7 "${EXPANDERPI_CHANNEL_7_TYPE}" "")"
    interactive_humidity_output="${interactive_humidity_response%$'\n'}"
    if [ "${interactive_humidity_output%%|*}" != "humidity" ]; then
        echo "Interaktive Vorbelegung für 'feuchte-sensor' wurde nicht als Luftfeuchtigkeit erkannt: ${interactive_humidity_output}" >&2
        return 1
    fi
    unset EXPANDERPI_CHANNEL_7_TYPE

    # Prüfe, dass im interaktiven Modus eine vorbelegte Zeichenkette "Stromsensor" als Strom erkannt wird.
    EXPANDERPI_CHANNEL_6_TYPE="Stromsensor"
    local interactive_german_current_response interactive_german_current_output
    interactive_german_current_response="$(printf '\n' | prompt_channel_assignment 6 "${EXPANDERPI_CHANNEL_6_TYPE}" "")"
    interactive_german_current_output="${interactive_german_current_response%$'\n'}"
    if [ "${interactive_german_current_output%%|*}" != "current" ]; then
        echo "Interaktive Vorbelegung für 'Stromsensor' wurde nicht als Strom erkannt: ${interactive_german_current_output}" >&2
        return 1
    fi
    unset EXPANDERPI_CHANNEL_6_TYPE

    # Prüfe, dass interaktive Eingaben mit Leerzeichen für Strom erkannt werden.
    local interactive_german_current_input_response interactive_german_current_input_output
    interactive_german_current_input_response="$(printf 'Strom sensor\n' | prompt_channel_assignment 6 "" "")"
    interactive_german_current_input_output="${interactive_german_current_input_response%$'\n'}"
    if [ "${interactive_german_current_input_output%%|*}" != "current" ]; then
        echo "Interaktive Eingabe für 'Strom sensor' wurde nicht als Strom erkannt: ${interactive_german_current_input_output}" >&2
        return 1
    fi

    # Prüfe, dass im interaktiven Modus eine vorbelegte Zeichenkette "Drucksensor" als Druck erkannt wird.
    EXPANDERPI_CHANNEL_6_TYPE="Drucksensor"
    local interactive_pressure_response interactive_pressure_output
    interactive_pressure_response="$(printf '\n' | prompt_channel_assignment 6 "${EXPANDERPI_CHANNEL_6_TYPE}" "")"
    interactive_pressure_output="${interactive_pressure_response%$'\n'}"
    if [ "${interactive_pressure_output%%|*}" != "pressure" ]; then
        echo "Interaktive Vorbelegung für 'Drucksensor' wurde nicht als Druck erkannt: ${interactive_pressure_output}" >&2
        return 1
    fi
    unset EXPANDERPI_CHANNEL_6_TYPE

    # Prüfe, dass Varianten mit Leerzeichen oder Bindestrich im interaktiven Modus als Druck erkannt werden.
    EXPANDERPI_CHANNEL_6_TYPE="druck-sensor"
    local interactive_pressure_variant_response interactive_pressure_variant_output
    interactive_pressure_variant_response="$(printf '\n' | prompt_channel_assignment 6 "${EXPANDERPI_CHANNEL_6_TYPE}" "")"
    interactive_pressure_variant_output="${interactive_pressure_variant_response%$'\n'}"
    if [ "${interactive_pressure_variant_output%%|*}" != "pressure" ]; then
        echo "Interaktive Vorbelegung für 'druck-sensor' wurde nicht als Druck erkannt: ${interactive_pressure_variant_output}" >&2
        return 1
    fi
    unset EXPANDERPI_CHANNEL_6_TYPE

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
