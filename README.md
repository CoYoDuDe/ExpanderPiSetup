# ExpanderPiSetup

ExpanderPiSetup ist ein SetupHelper-Paket fuer Venus OS. Es fuegt eine GUI-Seite fuer den ExpanderPi-DBus-ADC hinzu und fuehrt die benoetigten Setup-Schritte fuer `dbus-adc`, Overlays und Systemanpassungen aus.

## Voraussetzungen

- `SetupHelper` aktuell installiert
- Venus OS auf unterstuetztem Raspberry Pi
- ExpanderPi-Hardware vorhanden

## Installation

Repository im SetupHelper als Custom-Paket eintragen und ueber den PackageManager installieren.

Das Paket nutzt den offiziellen SetupHelper-Ablauf:

- `IncludeHelpers`
- `endScript INSTALL_FILES`
- FileSets fuer GUI-Datei und Patch
- `gitHubInfo` im offiziellen Format fuer den PackageManager
- `raspberryPiOnly` fuer die Plattformbegrenzung auf Venus-Raspberry-Pi-Systeme

## GUI

Die QML-Seite ist im Stil der offiziellen SetupHelper-Seiten aufgebaut und nutzt nur Venus-GUI-v1-Elemente:

- `MbPage`
- `VisibleItemModel`
- `MbEditBox`
- `MbItemOptions`
- `MbSubMenu`
- `VBusItem`

Die Seite schreibt direkt nach `com.victronenergy.settings/Settings/ExpanderPi/DbusAdc`; das eigentliche Anwenden uebernimmt weiterhin das `setup`-Skript beim Paket-Installationslauf.

## Konfiguration

Konfigurierbar sind:

- `Vref`
- `Scale`
- Kanal 1 bis 8
- pro Kanal `Type`
- pro Kanal `Label`

Unterstuetzte Sensortypen:

- `none`
- `tank`
- `temp`

## Hinweise

- Das Setup passt die fuer ExpanderPi benoetigten Overlays und Systemdateien an.
- Die GUI speichert nur die Werte; das eigentliche Anwenden uebernimmt das `setup`-Skript.
- Die generierte `dbus-adc.conf` bleibt auf die von Victron unterstuetzten `tank`-/`temp`-Direktiven beschraenkt.
