# ExpanderPiSetup – SetupHelper-Seite für den DBus-ADC

Diese Erweiterung ergänzt das ExpanderPi-Setup um eine SetupHelper-Seite im gewohnten Stil der Victron-Oberfläche. Die QML-Seite nutzt die Mb-Komponenten des Venus-UI-Frameworks, speichert Werte direkt im D-Bus (`com.victronenergy.settings/Settings/ExpanderPi/DbusAdc`) und startet anschließend das Installationsskript im `setup`-Modus. Damit lassen sich Vref, Scale sowie alle acht Kanäle des DBus-ADC ohne Shell-Zugriff pflegen.

## QML-Seite

* **Datei:** `FileSets/VersionIndependent/opt/victronenergy/gui/qml/PageSettingsExpanderPiDbusAdc.qml`
* **Eigenschaften:**
  * Aufbau als `MbPage` mit `VisibleItemModel`, `MbEditBox`, `MbItemOptions` und `MbSubMenu` analog zu den offiziellen SetupHelper-Seiten.
  * Bindung der Eingabefelder an `com.victronenergy.settings/Settings/ExpanderPi/DbusAdc` (Vref, Scale, Kanaltyp und Label).
  * Persistierung des Dialogzustands über die SetupHelper-API (`savePageState`) als Fallback.
  * Aufruf des Installationsskripts mit den gesetzten Werten als Environment (`EXPANDERPI_*`), damit das Shell-Skript deterministisch im nicht-interaktiven Modus läuft.

## Registrierung im SetupHelper

Die Seite wird über einen Patch auf `PageSettings.qml` eingebunden (`FileSets/PatchSource/PageSettings.qml.patch`). Der Eintrag platziert den Menüpunkt **ExpanderPi DBus-ADC** im Bereich der Hardware-/I/O-Konfiguration. Nach dem Kopieren der `FileSets`-Struktur in das SetupHelper-Dateisystem (z. B. `/data/SetupHelper/custom`) stellen `fileListPatched` und `fileListVersionIndependent` sicher, dass der Patch angewendet und die neue Seite nach `/opt/victronenergy/gui/qml` installiert wird.

## Paketabhängigkeiten und Kernel-Anpassungen

Die Datei `packageDependencies` beschreibt nun explizit, welche Pakete der SetupHelper für das ExpanderPi-Setup voraussetzt und welche Konflikte vermieden werden müssen. Neben dem SetupHelper selbst werden die Kernelmodule `kernel-module-rtc-ds1307` und `kernel-module-mcp320x` als Pflichtabhängigkeiten geführt, damit die Installationsroutine weiterhin `/u-boot/config.txt` und `/data/rc.local` für die RTC- und MCP3208-Unterstützung patcht.

## Zusammenspiel mit dem Setup-Skript

Das Shell-Skript `setup` liest neben der bestehenden `dbus-adc.user.conf` nun auch die D-Bus-Werte aus `com.victronenergy.settings/Settings/ExpanderPi/DbusAdc`. Sind dort gültige Werte hinterlegt, werden sie automatisch als nicht-interaktive Eingabe verwendet. Die GUI übergibt zusätzlich sämtliche Werte als `EXPANDERPI_*`-Variablen an den Installationslauf.

## Bedienung

1. SetupHelper öffnen und **Hardware → ExpanderPi DBus-ADC** wählen.
2. Vref und Scale setzen, anschließend jeden Kanal über die Unterseiten konfigurieren (Sensortyp & Label).
3. Mit **Speichern & Installieren** die Werte sichern; der SetupHelper ruft den Installationsmodus `setup` mit den gesetzten Parametern auf.
4. Optional mit **Zurücksetzen** die Standardwerte bzw. den letzten gespeicherten Zustand erneut laden.

Damit steht die komplette Konfiguration des ExpanderPi-DBus-ADC ohne Kommandozeile zur Verfügung.
