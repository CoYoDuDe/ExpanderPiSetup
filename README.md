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

### Temperaturfuehler

`temp` verwendet die LM335-Umrechnung des offiziellen Victron-dbus-adc-Treibers samt dessen Spannungsteiler. Ein 10k-NTC B3950 ist damit nicht kompatibel; dafuer ist eine eigene Umrechnung erforderlich. NTC nicht als `temp` aktivieren.

Neue Installationen stellen die bisherige Kanalvorlage bereit (ADC 1–4 Tank, ADC 5–8 Temperatur), mit in Venus zunaechst deaktivierten Eingaengen und 4.096 V Referenzspannung fuer den unveraenderten AB-Electronics-Expander-Pi. Bei externer Referenz muss Vref der tatsaechlichen Hardware entsprechen. Vorhandene Benutzereinstellungen bleiben erhalten. Die reine Platinen-Erkennung bestaetigt keine Sensorkalibrierung.

Quellen: [AB Electronics](https://www.abelectronics.co.uk/p/50/expander-pi), [Victron Sensorumrechnung](https://github.com/victronenergy/dbus-adc/blob/master/software/src/sensors.c).

### Tanksensoren

Tanksensoren werden als Widerstandsgeber über den ADC eingelesen.  
Die Beschaltung erfolgt je nach Sensor über einen passenden Spannungsteiler.

## Hinweise

- Das Setup passt die fuer ExpanderPi benoetigten Overlays und Systemdateien an.
- Die GUI speichert nur die Werte; das eigentliche Anwenden uebernimmt das `setup`-Skript.
- Die generierte `dbus-adc.conf` bleibt auf die von Victron unterstuetzten `tank`-/`temp`-Direktiven beschraenkt.

## Unterstützung

Dieses Projekt wird unabhängig und privat entwickelt und kostenlos bereitgestellt. Freiwillige Unterstützung hilft bei Infrastruktur, Servern, Domains, Tests, Wartung und Weiterentwicklung.

- [PayPal](https://paypal.me/CoYoDuDe)
- [Buy Me a Coffee](https://www.buymeacoffee.com/CoYoDuDe)
- [Weitere Projekte und Informationen](https://dnsmith.net/)

Unterstützung ist freiwillig. Es gibt keinen Abo-Zwang und daraus entsteht kein Anspruch auf bestimmte Funktionen oder persönlichen Support.

## Updates und Deinstallation

Eigene Backups, Overlay-Zustand und Benutzerkonfiguration liegen dauerhaft unter `/data/setupOptions/ExpanderPiSetup`, ausserhalb des ausgetauschten Paketordners. Boot-Eintraege werden in einem markierten Block verwaltet. Bei Deinstallation bleiben andere Boot- und Start-Eintraege erhalten; unmarkierte Alt-Eintraege werden nicht ohne Herkunftsnachweis entfernt.

In Venus OS 3.81 erscheinen konfigurierte Kanaele unter **Einstellungen → I/O → Analoge Eingaenge**. Dort erfolgt die native Aktivierung. Die Vorlage ist keine Erkennung der angeschlossenen Sensoren. `none` entfernt einen Kanal aus dieser Liste. GUI-Aenderungen im ExpanderPi-Menue werden beim erneuten Installieren des Pakets angewendet.
