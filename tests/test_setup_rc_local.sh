#!/bin/bash
set -euo pipefail

# Lade Funktionsdefinitionen aus dem Setup-Skript ohne den ausführenden Hauptteil.
tmp_script="$(mktemp)"
temp_machine_dir=""
work_dir=""
awk '/^case "\$scriptAction" in/ { exit } { print }' "$(dirname "$0")/../setup" > "$tmp_script"

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

    # shellcheck source=/dev/null
    source "$tmp_script"

    work_dir="$(mktemp -d)"
    MODULE_STATE_DIR="${work_dir}/state"
    RC_LOCAL_STATE_FILE="${MODULE_STATE_DIR}/rc_local_entries.list"
    RC_LOCAL_FILE="${work_dir}/rc.local"
    RC_LOCAL_BACKUP="${work_dir}/rc.local.orig"

    mkdir -p "$(dirname "$RC_LOCAL_STATE_FILE")"
    printf '#!/bin/sh\n\n%s\n' "$LEGACY_RC_LOCAL_ENTRY" > "$RC_LOCAL_FILE"
    printf '%s\n' "$LEGACY_RC_LOCAL_ENTRY" > "$RC_LOCAL_STATE_FILE"

    setup_rc_local

    if grep -qF -- "$LEGACY_RC_LOCAL_ENTRY" "$RC_LOCAL_FILE"; then
        echo "Legacy-Eintrag darf nach setup_rc_local nicht mehr vorhanden sein." >&2
        return 1
    fi

    if ! grep -Fx -- "$RC_LOCAL_HW_CLOCK_ENTRY" "$RC_LOCAL_FILE" >/dev/null; then
        echo "hwclock -s Eintrag fehlt in rc.local." >&2
        return 1
    fi

    local hwclock_count
    hwclock_count=$(awk -v needle="$RC_LOCAL_HW_CLOCK_ENTRY" '$0==needle{c++} END{print c+0}' "$RC_LOCAL_FILE")
    if [ "$hwclock_count" -ne 1 ]; then
        echo "hwclock -s Eintrag sollte genau einmal vorhanden sein." >&2
        return 1
    fi

    if [ ! -f "$RC_LOCAL_STATE_FILE" ]; then
        echo "rc_local_state_file fehlt nach setup_rc_local." >&2
        return 1
    fi

    if [ "$(wc -l < "$RC_LOCAL_STATE_FILE")" -ne 1 ]; then
        echo "rc_local_state_file sollte genau einen Eintrag enthalten." >&2
        return 1
    fi

    if [ "$(cat "$RC_LOCAL_STATE_FILE")" != "$RC_LOCAL_HW_CLOCK_ENTRY" ]; then
        echo "rc_local_state_file enthält unerwartete Daten." >&2
        return 1
    fi

    setup_rc_local

    hwclock_count=$(awk -v needle="$RC_LOCAL_HW_CLOCK_ENTRY" '$0==needle{c++} END{print c+0}' "$RC_LOCAL_FILE")
    if [ "$hwclock_count" -ne 1 ]; then
        echo "setup_rc_local muss idempotent sein und darf keine Duplikate erzeugen." >&2
        return 1
    fi

    echo "setup_rc_local Test erfolgreich."
}

main "$@"
