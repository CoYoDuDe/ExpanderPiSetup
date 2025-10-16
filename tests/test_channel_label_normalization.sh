#!/bin/bash
set -euo pipefail

# Lade Funktionsdefinitionen aus dem Setup-Skript ohne den ausführenden Hauptteil.
tmp_script="$(mktemp)"
awk '/^case "\$scriptAction" in/ { exit } { print }' "$(dirname "$0")/../setup" > "$tmp_script"

# Minimale Umgebung für das Setup bereitstellen.
mkdir -p /etc/venus
echo "raspberrypi4" > /etc/venus/machine

# Minimale Stubs für die vom Setup erwarteten Helper-Funktionen.
EXIT_INCOMPATIBLE_PLATFORM=${EXIT_INCOMPATIBLE_PLATFORM:-2}
EXIT_ERROR=${EXIT_ERROR:-1}
EXIT_FILE_SET_ERROR=${EXIT_FILE_SET_ERROR:-3}
logMessage() { :; }
setInstallFailed() { :; }
endScript() { :; }

# shellcheck source=/dev/null
source "$tmp_script"
rm -f "$tmp_script"

# Simuliere von der GUI geladene Kanaltypen und Labels.
TOTAL_ADC_CHANNELS=8
saved_channel_types=("tank" "temp" "none" "custom" "none" "none" "none" "none")
saved_channel_labels=("" "" "" "" "" "" "" "")

declare -a gui_labels

# DBus-Labels mit Leerzeichen wie gefordert
gui_labels[0]="Tank 1"
gui_labels[1]="Temperatur 5"

declare -a channel_labels
for ((channel=0; channel<TOTAL_ADC_CHANNELS; channel++)); do
    channel_labels[channel]=""
    if [ "${saved_channel_types[channel],,}" != "none" ]; then
        local_fallback="$(channel_label_fallback "$channel" "${saved_channel_types[channel]}")"
        saved_channel_labels[channel]="$(normalize_channel_label "${gui_labels[channel]:-}" "$local_fallback")"
    else
        saved_channel_labels[channel]=""
    fi
    channel_labels[channel]=""
done

# Prüfe, dass die GUI-Werte direkt normalisiert wurden.
if [ "${saved_channel_labels[0]}" != "tank1" ]; then
    echo "Erwartete Normalisierung für Kanal 0 fehlgeschlagen: ${saved_channel_labels[0]}" >&2
    exit 1
fi
if [ "${saved_channel_labels[1]}" != "temperatur5" ]; then
    echo "Erwartete Normalisierung für Kanal 1 fehlgeschlagen: ${saved_channel_labels[1]}" >&2
    exit 1
fi

# Simuliere den use_saved-Zweig aus install_config.
for ((channel=0; channel<TOTAL_ADC_CHANNELS; channel++)); do
    local_saved_type="${saved_channel_types[channel]}"
    if [ "${local_saved_type,,}" != "none" ]; then
        local_fallback="$(channel_label_fallback "$channel" "$local_saved_type")"
        normalized_label="$(normalize_channel_label "${saved_channel_labels[channel]}" "$local_fallback")"
        channel_labels[channel]="$normalized_label"
        saved_channel_labels[channel]="$normalized_label"
    else
        channel_labels[channel]=""
        saved_channel_labels[channel]=""
    fi
    # Alle Typen sollen übernommen bleiben
    if [ "${channel_labels[channel]}" != "" ] && [ "${saved_channel_types[channel]}" = "none" ]; then
        echo "Ein deaktivierter Kanal erhielt unerwartet ein Label." >&2
        exit 1
    fi
done

# Erzeuge die Ausgabe ähnlich der dbus-adc.conf.
config_output=""
for ((channel=0; channel<TOTAL_ADC_CHANNELS; channel++)); do
    if [ -n "${channel_labels[channel]}" ]; then
        config_output+="${channel_labels[channel]} ${channel}\n"
    fi
done

printf "%b" "$config_output"
