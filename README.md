# ExpanderPiSetup – SetupHelper-Seite für den DBus-ADC

Diese Erweiterung ergänzt das ExpanderPi-Setup um eine SetupHelper-Seite im gewohnten Stil der Victron-Oberfläche. Die QML-Seite nutzt die Mb-Komponenten des Venus-UI-Frameworks, speichert Werte direkt im D-Bus (`com.victronenergy.settings/Settings/ExpanderPi/DbusAdc`) und startet anschließend das Installationsskript im `setup`-Modus. Damit lassen sich Vref, Scale sowie alle acht Kanäle des DBus-ADC ohne Shell-Zugriff pflegen.

## Installation und Voraussetzungen

Die Erweiterung setzt einen funktionsfähigen SetupHelper voraus. Installiere oder aktualisiere ihn zunächst, indem du das aktuelle Release ins Gerät lädst und das Setup ausrollst:

```
wget https://updates.victronenergy.com/feeds/venus/release/SetupHelper.tar.gz
tar -xzf SetupHelper.tar.gz -C /data
/data/SetupHelper/setup
```

Nach Abschluss der SetupHelper-Installation steht die Blind-Install-Routine zur Verfügung. Kopiere anschließend dieses Repository – beispielsweise per `scp` – in den benutzerdefinierten Bereich und stoße die Paketinstallation an:

```
/data/SetupHelper/custom/ExpanderPiSetup/setup blind-install
/data/SetupHelper/custom/ExpanderPiSetup/setup package-manager install
```

Beachte, dass sämtliche Befehle innerhalb des SetupHelper-Kontextes laufen müssen. Ohne den SetupHelper lassen sich weder die Blind-Install-Automatik noch der Paketmanager nutzen.

## QML-Seite

* **Datei:** `FileSets/VersionIndependent/opt/victronenergy/gui/qml/PageSettingsExpanderPiDbusAdc.qml`
* **Eigenschaften:**
  * Aufbau als `MbPage` mit `VisibleItemModel`, `MbEditBox`, `MbItemOptions` und `MbSubMenu` analog zu den offiziellen SetupHelper-Seiten.
  * Bindung der Eingabefelder an `com.victronenergy.settings/Settings/ExpanderPi/DbusAdc` (Vref, Scale, Kanaltyp und Label).
  * Persistierung des Dialogzustands über die SetupHelper-API (`savePageState`) als Fallback.
  * Aufruf des Installationsskripts mit den gesetzten Werten als Environment (`EXPANDERPI_*`), damit das Shell-Skript deterministisch im nicht-interaktiven Modus läuft.

## Unterstützte Sensortypen

Der offizielle `dbus-adc`-Parser akzeptiert derzeit ausschließlich die Direktiven `tank` und `temp` (siehe [software/src/task.c](https://github.com/victronenergy/dbus-adc/blob/master/software/src/task.c)).
Die QML-Seite und das Setup-Skript bieten deshalb nur die Optionen **Nicht belegt**, **Tank** und **Temperatur** an.
Sobald Victron weitere Sensortypen im Parser hinterlegt, wird die Erweiterung um diese Typen ergänzt.

## Registrierung im SetupHelper

Die Seite wird über einen Patch auf `PageSettings.qml` eingebunden (`FileSets/PatchSource/PageSettings.qml.patch`). Der Eintrag platziert den Menüpunkt **ExpanderPi DBus-ADC** im Bereich der Hardware-/I/O-Konfiguration. Nach dem Kopieren der `FileSets`-Struktur in das SetupHelper-Dateisystem (z. B. `/data/SetupHelper/custom`) stellen `fileListPatched` und `fileListVersionIndependent` sicher, dass der Patch angewendet und die neue Seite nach `/opt/victronenergy/gui/qml` installiert wird.

## Paketabhängigkeiten und Kernel-Anpassungen

Die Datei `packageDependencies` beschreibt nun explizit, welche Pakete der SetupHelper für das ExpanderPi-Setup voraussetzt und welche Konflikte vermieden werden müssen. Neben dem SetupHelper selbst werden die Kernelmodule `kernel-module-rtc-ds1307` und `kernel-module-mcp320x` als Pflichtabhängigkeiten geführt, damit die Installationsroutine weiterhin `/u-boot/config.txt` und `/data/rc.local` für die RTC- und MCP3208-Unterstützung patcht.

## Zusammenspiel mit dem Setup-Skript

Das Shell-Skript `setup` liest neben der bestehenden `dbus-adc.user.conf` nun auch die D-Bus-Werte aus `com.victronenergy.settings/Settings/ExpanderPi/DbusAdc`. Sind dort gültige Werte hinterlegt, werden sie automatisch als nicht-interaktive Eingabe verwendet. Die GUI übergibt zusätzlich sämtliche Werte als `EXPANDERPI_*`-Variablen an den Installationslauf.

## Generierte `dbus-adc.conf`

Der Installer schreibt die Konfiguration strikt im von Victron dokumentierten Format (`device`, `vref`, `scale`, gefolgt von optionalen `label`-Zeilen sowie den Sensorzuweisungen `tank` bzw. `temp`). Für jeden aktivierten Kanal wird – falls ein Label gesetzt ist – zuerst `label <wert>` ausgegeben und anschließend die zum Sensortyp passende Direktive (`tank <eingang>` oder `temp <eingang>`). Nicht unterstützte oder deaktivierte Kanäle (z. B. Spannung, Strom, Druck) werden dabei ausgelassen, damit die generierte Datei 1:1 mit der Parser-Logik von `dbus-adc` kompatibel bleibt.

Beispielausgabe:

```
device iio:device0
vref 1.300
scale 4095

label tank1
tank 0
label tank2
tank 1
label tank3
tank 2
label tank4
tank 3
label temperatur5
temp 4
label temperatur6
temp 5
label temperatur7
temp 6
label temperatur8
temp 7
```

Damit entspricht die erzeugte Datei exakt den Vorgaben aus dem [dbus-adc-README](https://github.com/victronenergy/dbus-adc/blob/master/README.md) und kann ohne weitere Nacharbeit vom Venus OS übernommen werden.

## Bedienung

1. SetupHelper öffnen und **Hardware → ExpanderPi DBus-ADC** wählen.
2. Vref und Scale setzen, anschließend jeden Kanal über die Unterseiten konfigurieren (Sensortyp & Label).
3. Mit **Speichern & Installieren** die Werte sichern; der SetupHelper ruft den Installationsmodus `setup` mit den gesetzten Parametern auf.
4. Optional mit **Zurücksetzen** die Standardwerte bzw. den letzten gespeicherten Zustand erneut laden.

Damit steht die komplette Konfiguration des ExpanderPi-DBus-ADC ohne Kommandozeile zur Verfügung.
