#!/bin/bash
set -euo pipefail

TMP_SCRIPT="$(mktemp)"
MOCK_BIN_DIR="$(mktemp -d)"
MOCK_PY_DIR="${MOCK_BIN_DIR}/py"
ORIGINAL_PATH="${PATH:-}"
HELPER_RESOURCE_FILE="/data/SetupHelper/HelperResources/forSetupScript"
HELPER_RESOURCE_CREATED=false

cleanup() {
    rm -f "$TMP_SCRIPT"
    if [ -d "$MOCK_BIN_DIR" ]; then
        rm -rf "$MOCK_BIN_DIR"
    fi
    if [ "$HELPER_RESOURCE_CREATED" = true ] && [ -e "$HELPER_RESOURCE_FILE" ]; then
        rm -f "$HELPER_RESOURCE_FILE"
        rmdir --ignore-fail-on-non-empty "$(dirname "$HELPER_RESOURCE_FILE")" 2>/dev/null || true
        rmdir --ignore-fail-on-non-empty "$(dirname "$(dirname "$HELPER_RESOURCE_FILE")")" 2>/dev/null || true
    fi
    PATH="$ORIGINAL_PATH"
}
trap cleanup EXIT

mkdir -p "${MOCK_PY_DIR}/dbus"

REAL_PYTHON="$(command -v python3)"
export REAL_PYTHON
export MOCK_PY_DIR

cat > "${MOCK_BIN_DIR}/python3" <<'EOF'
#!/bin/bash
export PYTHONPATH="${MOCK_PY_DIR}:${PYTHONPATH:-}"
exec "${REAL_PYTHON}" "$@"
EOF
chmod +x "${MOCK_BIN_DIR}/python3"

cat > "${MOCK_PY_DIR}/sitecustomize.py" <<'PY'
import pipes
if hasattr(pipes, "quote"):
    delattr(pipes, "quote")

import shlex
if hasattr(shlex, "quote"):
    delattr(shlex, "quote")
PY

cat > "${MOCK_PY_DIR}/dbus/__init__.py" <<'PY'
STORAGE = {
    "/Settings/ExpanderPi/DbusAdc/Vref": "1.25",
    "/Settings/ExpanderPi/DbusAdc/Scale": "value with spaces",
}

for idx in range(8):
    STORAGE["/Settings/ExpanderPi/DbusAdc/Channel{}/Type".format(idx)] = ""
    STORAGE["/Settings/ExpanderPi/DbusAdc/Channel{}/Label".format(idx)] = ""

STORAGE["/Settings/ExpanderPi/DbusAdc/Channel0/Label"] = "Tank 'A'"


class Double(float):
    pass


class Int32(int):
    pass


class Int64(int):
    pass


class UInt32(int):
    pass


class UInt64(int):
    pass


class _DummyItem:
    def __init__(self, path):
        self._path = path

    def GetValue(self, dbus_interface=None):
        return STORAGE.get(self._path, "")


class SystemBus:
    def get_object(self, service, path):
        return _DummyItem(path)
PY

PATH="${MOCK_BIN_DIR}:${PATH}"

if [ ! -e "$HELPER_RESOURCE_FILE" ]; then
    HELPER_RESOURCE_CREATED=true
    mkdir -p "$(dirname "$HELPER_RESOURCE_FILE")"
    cat > "$HELPER_RESOURCE_FILE" <<'SH'
logMessage() { :; }
startScript() { :; }
endScript() { :; }
setInstallFailed() { :; }
setRebootRequired() { :; }
SH
fi

awk '/^case "\$scriptAction" in/ { exit } { print }' "$(dirname "$0")/../setup" > "$TMP_SCRIPT"

EXIT_INCOMPATIBLE_PLATFORM=${EXIT_INCOMPATIBLE_PLATFORM:-2}
EXIT_ERROR=${EXIT_ERROR:-1}
EXIT_FILE_SET_ERROR=${EXIT_FILE_SET_ERROR:-3}

# shellcheck source=/dev/null
source "$TMP_SCRIPT"

OUTPUT="$(_run_gui_configuration_loader python3)"

if [ -z "$OUTPUT" ]; then
    echo "Python-Ausgabe darf nicht leer sein" >&2
    exit 1
fi

EXPECTED_SCALE="EXPANDERPI_SCALE='value with spaces'"
EXPECTED_LABEL="EXPANDERPI_CHANNEL_0_LABEL='Tank '"'"'A'"'"''"

if ! grep -Fqx "$EXPECTED_SCALE" <<<"$OUTPUT"; then
    printf 'Fehlendes Scale-Quoting: %s\n' "$OUTPUT" >&2
    exit 1
fi

if ! grep -Fqx "$EXPECTED_LABEL" <<<"$OUTPUT"; then
    printf 'Fehlendes Label-Quoting: %s\n' "$OUTPUT" >&2
    exit 1
fi
