# ExpanderPiSetup

ExpanderPiSetup ist ein SetupHelper-Paket fuer Venus OS. Es fuegt eine GUI-Seite `ExpanderPi` hinzu und fuehrt die benoetigten Setup-Schritte fuer `dbus-adc`, Overlays und Systemanpassungen aus.

## Voraussetzungen

- [SetupHelper](https://github.com/kwindrem/SetupHelper) von [kwindrem](https://github.com/kwindrem) aktuell installiert
- Venus OS auf unterstuetztem Raspberry Pi
- ExpanderPi-Hardware vorhanden

Dieses Paket baut auf [SetupHelper](https://github.com/kwindrem/SetupHelper) von [kwindrem](https://github.com/kwindrem) auf.

## Hardware

Dieses Paket ist fuer den [Expander Pi von AB Electronics](https://www.abelectronics.co.uk/p/50/Expander-Pi) gedacht. Das Board stellt unter anderem 8 analoge Eingaenge ueber einen MCP3208-ADC, 16 digitale I/O-Kanaele, 2 analoge Ausgaenge und eine RTC bereit.

Eine schnelle Uebersicht zur GPIO-/Pin-Belegung gibt es bei [pinout.xyz](https://pinout.xyz/pinout/expander_pi).

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

## Sensoren und Hardware

### Temperaturfühler

Verwendet werden **10k NTC B3950**.

- Innen: Standard NTC
- Außen: wasserdichte Ausführung (vergossen / Edelstahlsonde)

### Beschaltung (NTC)

3.3V  
|  
[10k Widerstand]  
|  
+-----> ADC Eingang  
|  
[NTC 10k]  
|  
GND  

Optional:
- 100 nF Kondensator zwischen ADC und GND zur Signalberuhigung

### Tanksensoren

Tanksensoren werden als Widerstandsgeber über den ADC eingelesen.  
Die Beschaltung erfolgt je nach Sensor über einen passenden Spannungsteiler.

## Hinweise

- Das Setup passt die fuer ExpanderPi benoetigten Overlays und Systemdateien an.
- Die GUI speichert nur die Werte; das eigentliche Anwenden uebernimmt das `setup`-Skript.
- Die generierte `dbus-adc.conf` bleibt auf die von Victron unterstuetzten `tank`-/`temp`-Direktiven beschraenkt.
