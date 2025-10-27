# ExpanderPiSetup – SetupHelper-Seite für den DBus-ADC

Diese Erweiterung ergänzt das ExpanderPi-Setup um eine SetupHelper-Seite im gewohnten Stil der Victron-Oberfläche. Die QML-Seite nutzt die Mb-Komponenten des Venus-UI-Frameworks, speichert Werte direkt im D-Bus (`com.victronenergy.settings/Settings/ExpanderPi/DbusAdc`) und stößt den Installationslauf jetzt über den Victron-PackageManager (`com.victronenergy.packageManager/GuiEditAction`) an. Damit lassen sich Vref, Scale sowie alle acht Kanäle des DBus-ADC ohne Shell-Zugriff pflegen.

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

> **Hinweis:** Das Setup-Skript erwartet die SetupHelper-Hilfsbibliothek exakt unter `/data/SetupHelper/HelperResources/forSetupScript`, wie sie vom offiziellen SetupHelper-Archiv ausgeliefert wird. Wird der SetupHelper an einen anderen Ort entpackt, muss dieser Pfad per Symlink bereitgestellt oder das Skript entsprechend angepasst werden. Andernfalls bricht der Installer frühzeitig mit der Meldung „SetupHelper-Ressourcen wurden nicht … gefunden.“ ab.

### Unterstützte Python-Interpreter

Der nicht-interaktive GUI-Loader des Setup-Skripts (`_run_gui_configuration_loader`) läuft jetzt sowohl mit Python 2.7 als auch mit allen Python-3-Varianten zuverlässig. Vor dem Einsatz von `shlex.quote` prüft der Loader die Verfügbarkeit der Funktion und weicht bei älteren Interpreter-Builds automatisch auf `pipes.quote` beziehungsweise eine POSIX-konforme Fallback-Routine mit identischem Escaping aus. Damit bleibt der Shell-Aufruf gegen den D-Bus auch auf Systemen ohne modernes `shlex` vor Shell-Injection geschützt.

### Unterstützte Raspberry-Pi-Modelle

Das Setup prüft den Venus-Gerätetyp (`/etc/venus/machine`) und lässt nur freigegebene Raspberry-Pi-Varianten zu. Aktuell werden folgende Boards unterstützt:

* **Raspberry Pi 2** – Venus-Gerätekennung `raspberrypi2`
* **Raspberry Pi 3** – Venus-Gerätekennung `raspberrypi3`
* **Raspberry Pi 4** – Venus-Gerätekennung `raspberrypi4`

Diese Auswahl deckt die Modelle ab, die laut [AB Electronics Expander Pi Produktseite](https://www.abelectronics.co.uk/p/65/expander-pi) ausdrücklich unterstützt werden. Damit bleibt die Hardware-Matrix mit den offiziellen Herstellerangaben abgeglichen und kann bei Bedarf unkompliziert erweitert werden.

### Koexistenz mit GuiMods

Die Kombination mit dem optionalen Oberflächenpaket **GuiMods** wurde zuletzt am 24.10.2025 mit der veröffentlichten Variante **GuiMods v2025.10** sowie dem ExpanderPiSetup **v0.0.4** erfolgreich über den SetupHelper-Paketmanager geprüft. Die Installation erfolgte nicht-interaktiv via `setup package-manager install` und setzte dabei die von GuiMods ausgelieferten UI-Erweiterungen unverändert ein. Dadurch ist dokumentiert, dass beide Add-ons parallel betrieben werden können, ohne dass der Paketmanager Konflikte meldet.

## QML-Seite

* **Datei:** `FileSets/VersionIndependent/opt/victronenergy/gui/qml/PageSettingsExpanderPiDbusAdc.qml`
* **Eigenschaften:**
  * Aufbau als `MbPage` mit `VisibleItemModel`, `MbEditBox`, `MbItemOptions` und `MbSubMenu` analog zu den offiziellen SetupHelper-Seiten.
  * Bindung der Eingabefelder an `com.victronenergy.settings/Settings/ExpanderPi/DbusAdc` (Vref, Scale, Kanaltyp und Label).
* Direkte Kopplung an den Victron-PackageManager über die D-Bus-Schnittstellen `com.victronenergy.packageManager/GuiEditAction` (Auftragsannahme) und `.../GuiEditStatus` (Statusmeldungen). Die Seite agiert ohne SetupHelper-Hilfsobjekte und übernimmt damit exakt das Verhalten der Referenzseite `PageSettingsPackageEdit.qml`.
* Auslösung des Installationsskripts per PackageManager: Die Seite schreibt `install:ExpanderPiSetup` nach `com.victronenergy.packageManager/GuiEditAction` und zeigt die Rückmeldungen aus `.../GuiEditStatus` direkt im Dialog an. Ist der PackageManager beschäftigt, bleibt der Status sichtbar, bis der laufende Auftrag abgeschlossen ist.

### PackageManager-Integration und Statusmeldungen

Der PackageManager veröffentlicht seine GUI-Schnittstelle über die D-Bus-Pfade `com.victronenergy.packageManager/GuiEditAction` (Auftragsannahme) und `com.victronenergy.packageManager/GuiEditStatus` (Statusmeldung). Die ExpanderPi-Seite übernimmt das Verhalten der offiziellen SetupHelper-Dialoge:

1. **Busy-Erkennung:** Solange `GuiEditAction` nicht leer ist, blendet die Seite eine Hinweiszeile „PackageManager beschäftigt (<aktion>)“ ein und wartet, ohne einen neuen Auftrag zu senden.
2. **Auftragsstart:** Sobald `GuiEditAction` leer ist, setzt die Schaltfläche **Speichern & Installieren** die Meldung „Setup wird gestartet …“, schreibt diese parallel nach `GuiEditStatus` und trägt `install:ExpanderPiSetup` in `GuiEditAction` ein.
3. **Statusverfolgung:** Jede Statusänderung, die der PackageManager über `GuiEditStatus` publiziert (z. B. `install ExpanderPiSetup`, `download ExpanderPiSetup` oder Fehlermeldungen), wird unmittelbar angezeigt. Leert der PackageManager sowohl `GuiEditAction` als auch `GuiEditStatus`, blendet der Dialog eine lokale Bestätigung „Installationslauf ausgelöst.“ ein.

Damit verhält sich die Seite kompatibel zur Referenzimplementierung `PageSettingsPackageEdit.qml` aus dem SetupHelper und fügt sich ohne Sonderlocken in den bestehenden Paket-Workflow ein.

## Unterstützte Sensortypen

Der offizielle `dbus-adc`-Parser akzeptiert derzeit ausschließlich die Direktiven `tank` und `temp` (siehe [software/src/task.c](https://github.com/victronenergy/dbus-adc/blob/master/software/src/task.c)).
Die QML-Seite und das Setup-Skript bieten deshalb nur die Optionen **Nicht belegt**, **Tank** und **Temperatur** an.
Sobald Victron weitere Sensortypen im Parser hinterlegt, wird die Erweiterung um diese Typen ergänzt.

## Registrierung im SetupHelper

Die Seite wird über einen Patch auf `PageSettings.qml` eingebunden (`FileSets/PatchSource/PageSettings.qml.patch`). Der Eintrag platziert den Menüpunkt **ExpanderPi DBus-ADC** im Bereich der Hardware-/I/O-Konfiguration. Nach dem Kopieren der `FileSets`-Struktur in das SetupHelper-Dateisystem (z. B. `/data/SetupHelper/custom`) stellen `fileListPatched` und `fileListVersionIndependent` sicher, dass der Patch angewendet und die neue Seite nach `/opt/victronenergy/gui/qml` installiert wird.

## Paketabhängigkeiten und Kernel-Anpassungen

Die Datei `packageDependencies` nutzt das aktuelle, zeilenbasierte SetupHelper-Format und verlangt ausschließlich ein installiertes Basispaket `SetupHelper`. Weitere Abhängigkeiten werden durch das Setup-Skript abgeprüft, damit keine falschen Interpretationen durch den Paketmanager entstehen.

Kernelmodule wie `kernel-module-rtc-ds1307` und `kernel-module-mcp320x` werden weiterhin ausschließlich über das Skript `setup` aktiviert. Der SetupHelper verwaltet über `packageDependencies` lediglich seine eigenen Add-on-Pakete, daher erfolgen Einträge für Kernelmodule, Overlays oder Systemdienste direkt innerhalb des Installationsskripts. Dieser Ansatz stellt sicher, dass der Paketmanager keine unbekannten Abhängigkeiten meldet, während das Setup weiterhin `/u-boot/config.txt`, `/data/rc.local` und die zugehörigen State-Dateien passend anpasst.

Das Paket liefert ausschließlich die Overlays `i2c-rtc.dtbo` und `mcp3208.dtbo` aus. Für DS1307-basierte Echtzeituhrmodule wird nun konsequent das generische `i2c-rtc`-Overlay mit dem Parameter `ds1307` verwendet, wie es die Raspberry-Pi-Dokumentation empfiehlt. Separate, veraltete Varianten wie `ds1307-rtc.dtbo` entfallen damit vollständig.

Das Overlay übernimmt zugleich die Anlage des RTC-Geräts im Kernel. Ein manuelles Anlegen über `/sys/class/i2c-adapter/i2c-1/new_device` ist nicht mehr erforderlich und wird durch das Setup-Skript automatisch bereinigt, falls ältere Installationen den Eintrag noch in `rc.local` hinterlassen haben.

### Device-Tree-Overlay-Validierung

Das Setup-Skript trägt die Overlays `dtoverlay=i2c-rtc,ds1307` und `dtoverlay=mcp3208,spi0-0-present` in `/u-boot/config.txt` ein. Die Komma-Schreibweise aktiviert laut Raspberry-Pi-Dokumentation die boolesche Option `spi0-0-present` direkt beim Laden des Overlays. Nach der Installation empfiehlt sich eine kurze Kontrolle auf dem Zielsystem, z. B. mit `dtoverlay -l`, `dmesg | grep mcp3208` oder über `/sys/bus/iio/devices/`, um sicherzustellen, dass das MCP3208-Overlay tatsächlich geladen wurde. Durch das Setzen des Parameters `ds1307` am generischen `i2c-rtc`-Overlay entfällt das separate `ds1307-rtc.dtbo` vollständig – Konfiguration und Kernel-Modul bleiben dennoch unverändert erhalten.

### Automatische Aktualisierung verwalteter Overlays

Das Setup gleicht bei jedem erneuten `setup install` die ausgelieferten Overlays mit den vorhandenen Dateien auf dem Zielsystem ab. Overlays, die vom Setup verwaltet werden (`original=absent` oder `installed_by_setup=true`) oder deren Checksumme von der bereitgestellten Variante abweicht, werden automatisch ersetzt. Die zugehörigen State-Dateien protokollieren dabei die letzte Aktion und speichern die aktuelle Setup-Checksumme samt Zeitstempel, sodass Administratoren jederzeit nachvollziehen können, welche Overlay-Version aktiv ist.

## Zusammenspiel mit dem Setup-Skript

Das Shell-Skript `setup` liest neben der bestehenden `dbus-adc.user.conf` nun auch die D-Bus-Werte aus `com.victronenergy.settings/Settings/ExpanderPi/DbusAdc`. Sind dort gültige Werte hinterlegt, werden sie automatisch als nicht-interaktive Eingabe verwendet. Die GUI übergibt zusätzlich sämtliche Werte als `EXPANDERPI_*`-Variablen an den Installationslauf.

## Konfigurations-Defaults

Die Standardkanäle orientieren sich an der Victron-Vorbelegung: vier Tank- und vier Temperatursensoren mit den Platzhaltern `tank1` bis `tank4` sowie `temperatur5` bis `temperatur8`. Für bestehende Installationen bleibt die numerische Suffixschreibweise vollständig kompatibel – Labels, die mit `tank` oder `temp` beginnen und daran anschließend Ziffern oder Trennzeichen enthalten, werden weiterhin automatisch den passenden Sensortypen zugeordnet.

## Zulässige Wertebereiche für den dbus-adc

Die dbus-adc-Treiber auf dem Venus OS akzeptieren nur Werte innerhalb definierter Grenzen:

* **Vref:** 1,0 V bis 10,0 V – die Referenzspannung muss innerhalb des vom Treiber akzeptierten Bereichs liegen.
* **Scale:** 1 023 bis 65 535 – der Skalierungsfaktor darf weder unter die 10-Bit-Untergrenze noch über den maximalen 16-Bit-Wert hinausgehen.

Das Setup-Skript prüft alle interaktiven Eingaben, GUI-Vorbelegungen und Umgebungsvariablen auf diese Bereiche. Abweichende Angaben werden verworfen und automatisch auf die bewährten Standardwerte **Vref = 1,3 V** und **Scale = 4 095** gesetzt. Der Eingriff wird dabei per `logMessage` dokumentiert, bevor die `dbus-adc.conf` erzeugt wird, sodass weder ungültige Konfigurationsdateien noch widersprüchliche GUI-Anzeigen entstehen.

> **Wichtig:** Dezimalzahlen müssen mit genau einem Punkt (`.`) geschrieben werden. Werte wie `1,3` mit Komma oder Varianten ohne Nachkommastellen gelten als ungültig und führen automatisch zum Fallback auf den Standardwert.

Auch der `device`-Eintrag unterliegt jetzt einer festen Validierung: Es sind ausschließlich Namen im Format `iio:device<nummer>` zulässig. Jeder andere Wert – beispielsweise `device foo` aus einer Umgebungsvariablen – wird verworfen, automatisch auf **iio:device0** gesetzt und mit einer klaren Meldung wie `logMessage "Umgebungsvariable EXPANDERPI_DEVICE: ungültiger Device-Wert \"foo\" – verwende iio:device0."` protokolliert. So gelangen keine fehlerhaften IIO-Gerätenummern mehr in die Zielkonfiguration.

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

Das Setup-Skript übernimmt die `device`-Zeile dynamisch aus der Vorlage `FileSets/configs/dbus-adc.conf`. Damit lassen sich angepasste IIO-Gerätenummern (z. B. `iio:device1`) direkt über das Template vorgeben. Alle Gerätewerte – unabhängig davon, ob sie aus der Vorlage, dem gespeicherten Nutzerzustand, der GUI oder Umgebungsvariablen stammen – werden vor dem Schreiben strikt nach `^iio:device[0-9]+$` geprüft. Ungültige Eingaben landen nicht mehr in der `dbus-adc.conf`; stattdessen erfolgt ein dokumentierter Rückfall auf `iio:device0`, sodass die erzeugte Datei immer den von Victron erwarteten Syntaxregeln entspricht.

## Setup-Modi und Vorprüfungen

Der Aufruf `setup install` führt weiterhin alle Installationsschritte inklusive Datei- und Systemänderungen aus. Der neue Pfad `setup check` verbleibt hingegen vollständig im Validierungsmodus: Es werden lediglich Sicherungen der Ausgangsdateien angelegt, die Konfigurationsvorlage geparst und die Kernelmodul-Abhängigkeiten geprüft. Der Lauf beendet sich anschließend ohne `dbus-adc.conf`, `config.txt`, Overlays oder `rc.local` anzupassen – exakt das Verhalten, das der SetupHelper für seine nicht-destruktiven Vorprüfungen erwartet.

Fehler im CHECK-Modus brechen seit Version v0.0.4 ohne jegliche Bereinigung ab: Weder Overlays noch State-Dateien werden entfernt oder verändert. Damit lassen sich Validierungsläufe gefahrlos wiederholen, selbst wenn einzelne Prüfungen scheitern.

## Bedienung

1. SetupHelper öffnen und **Hardware → ExpanderPi DBus-ADC** wählen.
2. Vref und Scale setzen, anschließend jeden Kanal über die Unterseiten konfigurieren (Sensortyp & Label).
3. **Speichern & Installieren** drücken: Die Seite prüft zunächst, ob `com.victronenergy.packageManager/GuiEditAction` leer ist. Falls der PackageManager bereits einen Auftrag abarbeitet, erscheint der Hinweis „PackageManager beschäftigt (<aktion>)“.
4. Sobald `GuiEditAction` frei ist, schreibt die Seite `install:ExpanderPiSetup` hinein, setzt parallel den Status „Setup wird gestartet …“ nach `GuiEditStatus` und markiert den Lauf als aktiv. Die nachfolgenden Statusmeldungen des PackageManagers bleiben im Dialog sichtbar, bis der Auftrag abgeschlossen oder eine Fehlermeldung gemeldet wurde.
5. Optional mit **Zurücksetzen** die Standardwerte aus der GUI initialisieren lassen.

### Testnachweis

* **Simulationstest (Node.js):** Das Skript [`tests/packageManagerTrigger.test.js`](tests/packageManagerTrigger.test.js) emuliert `GuiEditAction` und `GuiEditStatus`. Es prüft den Happy Path (Auftrag wird gesendet und Status aktualisiert), den Busy-Pfad (laufender Auftrag blockiert eine neue Anforderung) sowie den Fehlerpfad (PackageManager antwortet mit `ERROR`).
* **Manueller Integrationstest (Venus OS 3.40~10, GuiMods v2025.10, 24.10.2025):** Nach dem Installieren von GuiMods über den SetupHelper wurde der Auftrag `/data/SetupHelper/custom/ExpanderPiSetup/setup package-manager install` ausgeführt. Die QML-Seite meldete zunächst „Setup wird gestartet …“, anschließend liefen die Statusmeldungen `install ExpanderPiSetup` und `complete` über `GuiEditStatus`. Währenddessen blieb `GuiEditAction` blockiert, bis der Auftrag abgeschlossen war und der Dialog automatisch die Bestätigung „Installationslauf ausgelöst.“ anzeigte.

Damit steht die komplette Konfiguration des ExpanderPi-DBus-ADC ohne Kommandozeile zur Verfügung.
